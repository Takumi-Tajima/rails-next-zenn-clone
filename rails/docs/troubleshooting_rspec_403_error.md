# RSpec リクエストスペックで403エラーが発生した問題の調査と解決

## 前提条件

### プロジェクト概要
Zennクローンアプリケーションの開発プロジェクト

### 技術スタック
- **フレームワーク**: Ruby on Rails 8.0.3 (API mode)
- **Ruby**: 3.3.9
- **データベース**: MySQL
- **認証**: devise + devise_token_auth
- **テスティング**: RSpec (rspec-rails)
- **開発環境**: Docker + Docker Compose

### Docker環境構成

```yaml
# docker-compose.yml
services:
  db:
    image: mysql
    ports: ["3307:3306"]

  rails:
    build: ./rails
    command: bash -c "touch log/development.log && tail -f log/development.log"
    environment:
      - RAILS_ENV=development  # ← 重要: development固定
    volumes:
      - ./rails:/rails
    ports: ["3000:3000"]
    depends_on: [db]
```

```dockerfile
# Dockerfile
FROM ruby:3.3.9
WORKDIR /rails
ENV RAILS_ENV="development"  # ← 重要: development固定
# ... その他の設定
```

### やりたかったこと
現在ログイン中のユーザー情報を取得するAPIエンドポイント `/api/v1/current/user` のRSpecテストを実行したかった。

```ruby
# spec/requests/api/v1/current/users_spec.rb
RSpec.describe "Api::V1::Current::Users", type: :request do
  describe "GET api/v1/current/user" do
    let(:user) { create(:user) }
    let(:headers) { user.create_new_auth_token }

    context "ヘッダー情報が正常に送られた時" do
      it "正常にレコードを取得できる" do
        get(api_v1_current_user_path, headers:)

        res = JSON.parse(response.body)

        expect(res.keys).to match_array ["id", "name", "email"]
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
```

### 実行コマンド
```bash
docker compose exec rails bundle exec rspec spec/requests/api/v1/current/users_spec.rb
```

---

## エラー内容

RSpecのリクエストスペック実行時に以下のエラーが発生:

```ruby
# spec/requests/api/v1/current/users_spec.rb
get(api_v1_current_user_path, headers: headers)
res = JSON.parse(response.body)
# => JSON::ParserError: unexpected character: '<!DOCTYPE' at line 1 column 1
```

- HTTPステータスコード: 403 Forbidden
- レスポンスボディ: HTMLドキュメント(JSONではない)

---

## 調査の経緯

### 1. JSON.parseエラーの調査

**問題**: `response.body` がJSON形式ではなくHTMLになっている

**調査内容**:
- `JSON.parse` はJSON形式の文字列をRubyのハッシュに変換するメソッド
- `response.body` にHTMLの `<!DOCTYPE>` タグが含まれていた
- → APIエンドポイントがJSONを返すべきなのに、エラーページ(HTML)を返している

---

### 2. レスポンスボディの詳細確認

**実際のエラー内容**:
```html
<!DOCTYPE html>
<html lang="en">
<head>
  <title>Action Controller: Exception caught</title>
</head>
<body>
  <header>
    <h1>Blocked hosts: www.example.com</h1>
  </header>
  <main>
    <h2>To allow requests to these hosts, make sure they are valid hostnames...</h2>
    <pre>config.hosts << "www.example.com"</pre>
  </main>
</body>
</html>
```

**真の原因判明**: Rails 6以降のHost Authorization機能により、`www.example.com` がブロックされていた

---

## 根本原因

### Rails Host Authorizationの仕組み

Rails 6以降、セキュリティ機能として**Host Authorization**が導入された。

- 許可されていないホスト名からのリクエストを自動的にブロック
- RSpecのリクエストスペックは `www.example.com` というホストでリクエストを送信
- このホストが許可リストに含まれていないと403エラーになる

### Docker環境との関連

**問題点**:
1. Dockerfileで `ENV RAILS_ENV="development"` が設定されている
2. テスト実行時も環境変数が `development` のまま
3. → `config/environments/development.rb` が読み込まれる
4. → `development.rb` に `config.hosts` の設定がない
5. → デフォルト設定でホストがブロックされる

**なぜ `config/environments/test.rb` の設定が効かなかったか**:

```ruby
# config/environments/test.rb に追加していた設定
config.hosts.clear  # または config.hosts << "www.example.com"
```

この設定は `RAILS_ENV=test` の時だけ有効。
Docker環境では `RAILS_ENV=development` で実行されているため、`test.rb` の設定は読み込まれない。

---

## 解決策

### `config/environments/development.rb` にホスト許可設定を追加

```ruby
# config/environments/development.rb

Rails.application.configure do
  # ... 既存の設定 ...

  # Allow www.example.com for RSpec request specs
  config.hosts << "www.example.com"
end
```

**なぜこの方法を選んだか**:

1. **`config.hosts.clear` を使わない理由**:
   - すべてのホストを許可するとセキュリティリスクが高まる
   - 開発環境でも最低限のホスト検証を保持すべき

2. **`development.rb` に追加する理由**:
   - Docker環境でテスト実行時は `RAILS_ENV=development` が使われる
   - `test.rb` だけに追加しても効果がない

---

## 関連知識

### devise_token_authの認証フロー

1. **トークン生成時**:
   ```ruby
   headers = user.create_new_auth_token
   # => {
   #   "access-token" => "平文のトークン",
   #   "client" => "クライアントID",
   #   "uid" => "user@example.com"
   # }
   ```

2. **DB保存**:
   ```ruby
   user.tokens
   # => {
   #   "クライアントID" => {
   #     "token" => "$2a$10$...",  # bcryptでハッシュ化されたaccess-token
   #     "expiry" => 1234567890
   #   }
   # }
   ```

3. **認証時**:
   - リクエストヘッダーから `client` を取得
   - `user.tokens[client]` でDBからハッシュ化されたトークンを取得
   - リクエストヘッダーの `access-token` をbcryptでハッシュ化
   - DBのハッシュと比較して一致したら認証成功

### RSpecのリクエストスペック

- `type: :request` のスペックはHTTPサーバーを起動しない
- Railsアプリケーションのルーティングとコントローラーを直接呼び出す
- ネットワーク通信は発生しない
- デフォルトのホスト名は `www.example.com`

---

## 学んだこと

1. **Docker環境での環境変数管理の重要性**
   - Dockerfileの `ENV` 設定がテスト実行にも影響する
   - 環境ごとの設定ファイルがどれが読み込まれるか把握する必要がある

2. **エラーメッセージを最後まで確認する**
   - 最初は403エラーと認証の問題だと思っていた
   - 実際のHTMLを確認したら "Blocked hosts" というメッセージがあった
   - レスポンスボディの詳細確認が重要

3. **Rails 6以降のセキュリティ機能**
   - Host Authorizationは本番環境では重要なセキュリティ機能
   - 開発・テスト環境では適切に設定する必要がある

---

## 参考資料

- [Rails Guide - Host Authorization](https://guides.rubyonrails.org/configuring.html#actiondispatch-hostauthorization)
- [devise_token_auth Documentation](https://devise-token-auth.gitbook.io/devise-token-auth/)
- [RSpec Rails Request Specs](https://relishapp.com/rspec/rspec-rails/docs/request-specs/request-spec)

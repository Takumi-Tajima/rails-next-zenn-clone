require "rails_helper"

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

    context "ヘッダー情報が空のままリクエストが送信された時" do
      let(:headers) { nil }

      it "unauthorized エラーが返る" do
        get(api_v1_current_user_path, headers:)

        res = JSON.parse(response.body)

        expect(res["errors"]).to eq ["続けるには、ログインまたは登録（サインアップ）が必要です。"]
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end

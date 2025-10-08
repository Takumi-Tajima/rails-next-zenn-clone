FROM ruby:3.3.9

# 開発に必要なパッケージをインストール
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential \
    default-libmysqlclient-dev \
    git \
    curl \
    libjemalloc2 \
    libvips \
    nodejs \
    libyaml-dev \
    pkg-config \
    vim

# キャッシュは残しておく(開発環境なのでサイズより利便性優先)

WORKDIR /rails

# 開発環境の設定
ENV RAILS_ENV="development" \
    BUNDLE_PATH="/usr/local/bundle"

# Gemfileをコピーしてインストール
COPY Gemfile Gemfile.lock ./
RUN bundle install

# アプリケーションコードをコピー
COPY . .

# Entrypointに実行権限を付与して上書き
COPY --chmod=755 entrypoint.sh /rails/entrypoint.sh

ENTRYPOINT ["/rails/entrypoint.sh"]

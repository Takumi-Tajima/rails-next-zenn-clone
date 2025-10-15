class Api::V1::ArticlesController < Api::V1::BaseController
  def index
    articles = Article.published.includes(:user).default_order
    render json: articles
  end

  def show
    article = Article.published.find(params.expect(:id))
    render json: article
  end
end

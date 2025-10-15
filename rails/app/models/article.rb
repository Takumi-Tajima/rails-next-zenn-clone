class Article < ApplicationRecord
  belongs_to :user

  enum :status, { unsaved: 1, draft: 2, published: 3 }

  scope :default_order, -> { order(created_at: :desc) }

  validates :title, :content, presence: true, if: :published?
  validate :verify_only_one_unsaved_status_is_allowed

  private

  def verify_only_one_unsaved_status_is_allowed
    if unsaved? && user.articles.unsaved.present?
      raise StandardError, "未保存の記事は複数保有できません"
    end
  end
end

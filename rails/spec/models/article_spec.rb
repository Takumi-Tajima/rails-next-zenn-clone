require 'rails_helper'

RSpec.describe '記事のCRUD', type: :model do

  context '入力する値が正常値の場合' do
    it '記事を作成できること' do
      expect do
        create(:article)
      end.to change(Article, :count).by(1)
    end
  end

  context "入力する値が異常値の場合" do
    it '記事を作成できないこと' do
      expect do
        create(:article, title: nil, content: nil)
      end.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end

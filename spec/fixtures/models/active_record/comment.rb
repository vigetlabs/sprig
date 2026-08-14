class Comment < ActiveRecord::Base
  belongs_to :post

  validates :post, presence: true
end

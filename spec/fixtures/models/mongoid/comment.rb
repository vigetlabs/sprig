class Comment
  include Mongoid::Document

  field :body, :type => String

  belongs_to :post

  validates :post, :presence => true
end

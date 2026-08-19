class Post
  include Mongoid::Document

  field :user_id, type: BSON::ObjectId
  field :title, type: String
  field :content, type: String
  field :published, type: Boolean
  field :readonly_field, type: String

  has_and_belongs_to_many :tags

  attr_readonly :readonly_field
  
  validates :title, presence: true

  def photo=(file)
    write_attribute(:photo, File.basename(file.path))
  end
end

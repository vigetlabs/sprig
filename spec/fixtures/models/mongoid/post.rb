class Post
  include Mongoid::Document

  field :user_id,   :type => BSON::ObjectId
  field :title,     :type => String
  field :content,   :type => String
  field :published, :type => Boolean

  has_and_belongs_to_many :tags

  def photo=(file)
    write_attribute(:photo, File.basename(file.path))
  end
end

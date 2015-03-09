class Post
  include Mongoid::Document

  if Mongoid::VERSION.split('.').first == "3"
    field :user_id,   :type => Moped::BSON::ObjectId
  else
    field :user_id,   :type => BSON::ObjectId
  end
  field :title,     :type => String
  field :content,   :type => String
  field :published, :type => Boolean

  has_and_belongs_to_many :tags

  def photo=(file)
    write_attribute(:photo, File.basename(file.path))
  end
end

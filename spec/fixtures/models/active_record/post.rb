class Post < ActiveRecord::Base

  has_and_belongs_to_many :tags

  validates :title, presence: true

  def photo=(file)
    write_attribute(:photo, File.basename(file.path))
  end

end

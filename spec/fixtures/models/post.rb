class Post < ActiveRecord::Base

  has_and_belongs_to_many :tags

  def photo=(file)
    write_attribute(:photo, File.basename(file.path))
  end

end

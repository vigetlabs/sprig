class Post < ActiveRecord::Base

  def photo=(file)
    write_attribute(:photo, File.basename(file.path))
  end

end

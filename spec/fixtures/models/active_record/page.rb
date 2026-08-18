class Page < ActiveRecord::Base
  validates :title, presence: true
end

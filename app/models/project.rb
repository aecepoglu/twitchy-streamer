class Project < ApplicationRecord
  has_secure_password

  has_many :assets

  validates :title,
    presence: true,
    uniqueness: true
end

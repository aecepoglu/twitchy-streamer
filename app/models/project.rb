class Project < ApplicationRecord
  has_secure_password

  validates :title,
    presence: true,
    uniqueness: true
end

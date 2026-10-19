class User < ApplicationRecord
  has_secure_password

  # Mandatory validations
  validates :name, presence: true
  validates :email, presence: true, uniqueness: { case_sensitive: false }
  
  # Requirement: Password can be any non-empty string (even 1 character)
  validates :password, presence: true, length: { minimum: 1 }, allow_nil: true

  # Helper method to check if user is active
  def active?
    status == "active"
  end

  def blocked?
    status == "blocked"
  end
end
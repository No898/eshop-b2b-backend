# frozen_string_literal: true

class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :jwt_authenticatable, jwt_revocation_strategy: Devise::JWT::RevocationStrategies::Null

  # SECURITY: Role enum
  enum :role, {
    customer: 0,
    admin: 1
  }, default: :customer

  # Associations
  has_many :orders, dependent: :destroy

  # File attachments
  has_one_attached :avatar
  has_one_attached :company_logo

  # SECURITY: Validations
  validates :email, presence: true, uniqueness: { case_insensitive: true }
  validates :email, format: { with: Devise.email_regexp }
  validates :role, presence: true
  validates :company_name, length: { maximum: 255 }
  validates :vat_id, length: { maximum: 50 }

  # SECURITY: Normalize email before save
  before_save :normalize_email

  # SECURITY: Helper methods
  def admin?
    role == 'admin'
  end

  def customer?
    role == 'customer'
  end

  def can_access_order?(order)
    return true if admin?

    order.user_id == id
  end

  def can_access_user_data?(target_user)
    return true if admin?

    target_user.id == id
  end

  private

  def normalize_email
    self.email = email.downcase.strip if email.present?
  end
end

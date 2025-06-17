# frozen_string_literal: true

class Address < ApplicationRecord
  include CzechAddressValidation
  include AddressFormatting

  # ASSOCIATIONS
  belongs_to :user

  # ENUMS
  enum :address_type, { billing: 0, shipping: 1 }

  # VALIDATIONS - Required fields
  validates :first_name, presence: true, length: { minimum: 2, maximum: 50 }
  validates :last_name, presence: true, length: { minimum: 2, maximum: 50 }
  validates :street, presence: true, length: { minimum: 5, maximum: 100 }
  validates :city, presence: true, length: { minimum: 2, maximum: 50 }
  validates :country, presence: true, length: { minimum: 2, maximum: 50 }
  # Postal code validation is handled by CzechAddressValidation concern

  # VALIDATIONS - Optional company fields
  validates :company_name, length: { maximum: 100 }, allow_blank: true
  validates :company_registration_id, length: { is: 8 }, allow_blank: true
  validates :company_vat_id, length: { minimum: 10, maximum: 12 }, allow_blank: true
  validates :phone, length: { maximum: 20 }, allow_blank: true
  validates :notes, length: { maximum: 1000 }, allow_blank: true

  # CUSTOM VALIDATIONS
  validate :billing_address_company_requirements
  validate :unique_default_per_type

  # SCOPES
  scope :billing_addresses, -> { where(address_type: :billing) }
  scope :shipping_addresses, -> { where(address_type: :shipping) }
  scope :default_addresses, -> { where(is_default: true) }
  scope :b2b_addresses, -> { where.not(company_name: [nil, '']) }
  scope :for_user, ->(user) { where(user: user) }
  scope :for_country, ->(country) { where(country: country) }

  # CALLBACKS
  before_save :normalize_postal_code
  before_save :normalize_vat_ids
  before_save :set_default_country
  before_save :ensure_single_default_per_type

  # BUSINESS METHODS
  def billing?
    address_type == 'billing'
  end

  def shipping?
    address_type == 'shipping'
  end

  def company_address?
    company_name.present?
  end

  # Czech/Slovak address methods are in CzechAddressValidation concern
  # formatted_address and formatted_postal_code are in AddressFormatting concern

  def country_name
    case country
    when 'CZ' then 'Česká republika'
    when 'SK' then 'Slovenská republika'
    else country
    end
  end

  def complete_billing_info?
    billing? && company_name.present? && company_vat_id.present?
  end

  def self.find_default_for_user_and_type(user, address_type)
    where(user: user, address_type: address_type, is_default: true).first
  end

  private

  def billing_address_company_requirements
    return unless billing?

    errors.add(:company_name, 'je vyžadován pro fakturační adresu') if company_name.blank?

    # Pro české firmy vyžadujeme IČO
    return unless czech_address? && company_name.present? && company_registration_id.blank?

    errors.add(:company_registration_id, 'IČO je vyžadováno pro české firmy')
  end

  def unique_default_per_type
    return unless is_default? && is_default_changed?

    existing = user.addresses
                   .where(address_type: address_type, is_default: true)
                   .where.not(id: id)

    return unless existing.exists?

    errors.add(:is_default, "může být pouze jedna výchozí #{address_type_i18n} adresa")
  end

  def normalize_postal_code
    return if postal_code.blank?

    # Remove spaces and add proper formatting
    clean_code = postal_code.gsub(/\s/, '')
    self.postal_code = clean_code.insert(3, ' ') if clean_code.length == 5
  end

  def normalize_vat_ids
    self.company_registration_id = company_registration_id.gsub(/\s/, '') if company_registration_id.present?

    return if company_vat_id.blank?

    self.company_vat_id = company_vat_id.upcase.gsub(/\s/, '')
  end

  def set_default_country
    self.country = 'CZ' if country.blank?
  end

  def ensure_single_default_per_type
    return unless is_default? && is_default_changed?

    # Use individual updates to maintain validations
    user.addresses.where(address_type: address_type, is_default: true)
        .where.not(id: id)
        .find_each { |addr| addr.update!(is_default: false) }
  end

  def address_type_i18n
    case address_type
    when 'billing' then 'fakturační'
    when 'shipping' then 'doručovací'
    else address_type
    end
  end
end

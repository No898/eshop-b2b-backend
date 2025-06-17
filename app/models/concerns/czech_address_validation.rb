# frozen_string_literal: true

module CzechAddressValidation
  extend ActiveSupport::Concern

  POSTAL_CODE_REGEX = /\A\d{3}\s?\d{2}\z/
  COMPANY_REGISTRATION_ID_REGEX = /\A\d{8}\z/
  COMPANY_VAT_ID_REGEX = /\A(CZ|SK)\d{8,10}\z/

  included do
    validates :postal_code, presence: true, format: { with: POSTAL_CODE_REGEX, message: :invalid_postal_code }
    validates :company_registration_id, format: { with: COMPANY_REGISTRATION_ID_REGEX, message: :invalid_ico },
                                        allow_blank: true
    validates :company_vat_id, format: { with: COMPANY_VAT_ID_REGEX, message: :invalid_dic }, allow_blank: true
  end

  def formatted_postal_code
    return postal_code if postal_code.blank?

    postal_code.gsub(/\A(\d{3})(\d{2})\z/, '\1 \2')
  end

  def czech_address?
    ['CZ', 'ČESKÁ REPUBLIKA'].include?(country&.upcase)
  end

  def slovak_address?
    %w[SK SLOVENSKO].include?(country&.upcase)
  end

  def b2b_address?
    company_name.present? || company_registration_id.present?
  end

  def complete_b2b_info?
    b2b_address? && company_name.present? && company_registration_id.present?
  end

  def vat_payer?
    company_vat_id.present?
  end

  private

  def set_default_country
    self.country = 'CZ' if country.blank?
  end
end

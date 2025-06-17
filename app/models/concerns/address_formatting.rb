# frozen_string_literal: true

module AddressFormatting
  extend ActiveSupport::Concern

  # DISPLAY METHODS
  def full_name
    "#{first_name} #{last_name}".strip
  end

  def formatted_address
    parts = [street, city, formatted_postal_code, country].compact
    parts.join(', ')
  end

  def single_line_address
    "#{full_name}, #{formatted_address}"
  end

  def company_info
    return nil unless b2b_address?

    parts = [company_name]
    parts << "IČO: #{company_registration_id}" if company_registration_id.present?
    parts << "DIČ: #{company_vat_id}" if company_vat_id.present?
    parts.join(', ')
  end

  def complete_address
    lines = build_address_lines
    lines.compact.join("\n")
  end

  private

  def build_address_lines
    lines = [full_name]
    lines << company_name if company_name.present?
    lines << street
    lines << "#{formatted_postal_code} #{city}"
    lines << country unless czech_address?
    lines
  end
end

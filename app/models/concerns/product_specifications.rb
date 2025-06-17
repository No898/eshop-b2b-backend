# frozen_string_literal: true

module ProductSpecifications
  extend ActiveSupport::Concern

  included do
    # VALIDATIONS - Product specifications
    validates :weight_value, numericality: { greater_than: 0 }, allow_nil: true
    validates :weight_unit, inclusion: { in: %w[kg g l ml] }, allow_nil: true
    validates :ingredients, length: { maximum: 5000 }, allow_blank: true

    # CUSTOM VALIDATION - Weight consistency (both or neither)
    validate :weight_fields_consistency
  end

  # BUSINESS METHODS - Product specifications
  def weight_info?
    weight_value.present? && weight_unit.present?
  end

  def formatted_weight
    return nil unless weight_info?

    "#{weight_value.to_f} #{weight_unit}"
  end

  def ingredients?
    ingredients.present?
  end

  def weight_in_grams
    return nil unless weight_info?

    case weight_unit
    when 'kg' then weight_value * 1000
    when 'g'  then weight_value
    when 'l', 'ml' then weight_value * (weight_unit == 'l' ? 1000 : 1)
    end
  end

  def liquid?
    weight_unit.in?(%w[l ml])
  end

  def solid?
    weight_unit.in?(%w[kg g])
  end

  private

  def weight_fields_consistency
    # BUSINESS RULE: Weight value and unit must be both present or both nil
    if weight_value.present? && weight_unit.blank?
      errors.add(:weight_unit, 'je vyžadována když je zadána hmotnost/objem')
    elsif weight_unit.present? && weight_value.blank?
      errors.add(:weight_value, 'je vyžadována když je zadána jednotka')
    end
  end
end

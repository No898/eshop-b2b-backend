# frozen_string_literal: true

# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# This file should contain all the record creation needed to seed the database
# with its default values.
# The data can then be loaded with the bin/rails db:seed command

# Helper methods for variant creation
def create_or_find_variant(parent_product, variant_data, index)
  attr_values = variant_data[:attributes].values.sort.join('-')
  variant_identifier = "popping-#{attr_values}"

  existing_variant = parent_product.variants.find_by(variant_sku: variant_identifier)

  if existing_variant
    Rails.logger.debug { "  ⚠️  Variant already exists: #{existing_variant.variant_display_name}" }
    existing_variant
  else
    parent_product.create_variant!(
      variant_data[:attributes],
      variant_data[:product].merge(variant_sort_order: index + 1, variant_sku: variant_identifier)
    )
  end
end

def create_variant_bulk_pricing(variant)
  [
    { tier_name: '1ks', min_quantity: 1, max_quantity: 11, price_cents: variant.price_cents,
      description: 'Jednotlivé balení' },
    { tier_name: '1bal', min_quantity: 12, max_quantity: 119, price_cents: (variant.price_cents * 0.88).to_i,
      description: 'Balení 12 kusů - úspora 12%' },
    { tier_name: '10bal', min_quantity: 120, max_quantity: nil, price_cents: (variant.price_cents * 0.8).to_i,
      description: 'Kartón 120+ kusů - úspora 20%' }
  ].each do |tier_attrs|
    variant.price_tiers.find_or_create_by!(tier_name: tier_attrs[:tier_name]) do |t|
      t.assign_attributes(tier_attrs)
    end
  end
end

# Create admin user
admin = User.find_or_create_by!(email: 'admin@lootea.cz') do |user|
  user.password = 'password123'
  user.password_confirmation = 'password123'
  user.role = 'admin'
  user.company_name = 'Lootea s.r.o.'
  user.vat_id = 'CZ12345678'
end

Rails.logger.debug { "✅ Admin user created: #{admin.email}" }

# Create sample customer
customer = User.find_or_create_by!(email: 'zakaznik@firma.cz') do |user|
  user.password = 'password123'
  user.password_confirmation = 'password123'
  user.role = 'customer'
  user.company_name = 'Testovací firma s.r.o.'
  user.vat_id = 'CZ87654321'
end

Rails.logger.debug { "✅ Customer created: #{customer.email}" }

# Create products with inventory and specifications
products = [
  {
    name: 'Popping Pearls - Marakuja',
    description: 'Praskající kuličky s příchutí marakuja. Perfektní do bubble tea.',
    price_cents: 25_000, # 250 CZK
    currency: 'CZK',
    available: true,
    quantity: 100,
    low_stock_threshold: 10,
    weight_value: 3.2,
    weight_unit: 'kg',
    ingredients: 'Voda, cukr, přírodní aroma marakuja, alginát sodný, chlorid vápenatý'
  },
  {
    name: 'Bubble Tea Slamky - Černé',
    description: 'Extra široké slamky speciálně navržené pro bubble tea. Balení 100ks.',
    price_cents: 8000, # 80 CZK
    currency: 'CZK',
    available: true,
    quantity: 500,
    low_stock_threshold: 50,
    weight_value: 200,
    weight_unit: 'g',
    ingredients: 'Polypropylén'
  },
  {
    name: 'Tapiokové perly - Černé',
    description: 'Klasické černé tapiokové perly. Sušené, připravené k vaření.',
    price_cents: 15_000, # 150 CZK
    currency: 'CZK',
    available: true,
    quantity: 75,
    low_stock_threshold: 15,
    weight_value: 1.0,
    weight_unit: 'kg',
    ingredients: 'Tapiokový škrob, karamel, voda'
  },
  {
    name: 'Taro Syrup - Fialový',
    description: 'Krémový sirup s příchutí taro. Objem 2.5 litru.',
    price_cents: 32_000, # 320 CZK
    currency: 'CZK',
    available: true,
    quantity: 30,
    low_stock_threshold: 5,
    weight_value: 2.5,
    weight_unit: 'l',
    ingredients: 'Cukr, voda, přírodní aroma taro, konzervant E202'
  }
]

created_products = []
products.each do |product_attrs|
  product = Product.find_or_create_by!(name: product_attrs[:name]) do |p|
    p.assign_attributes(product_attrs)
  end
  created_products << product
  Rails.logger.debug { "✅ Product created: #{product.name} (#{product.formatted_price})" }
end

# Create bulk pricing tiers for products
Rails.logger.debug "\n🏷️ Creating bulk pricing tiers..."

# Popping Pearls - množstevní slevy
popping_pearls = created_products.first
[
  { tier_name: '1ks', min_quantity: 1, max_quantity: 11, price_cents: 25_000, description: 'Jednotlivé balení' },
  { tier_name: '1bal', min_quantity: 12, max_quantity: 119, price_cents: 22_000,
    description: 'Balení 12 kusů - úspora 12%' },
  { tier_name: '10bal', min_quantity: 120, max_quantity: nil, price_cents: 20_000,
    description: 'Kartón 10 balení - úspora 20%' }
].each do |tier_attrs|
  tier = popping_pearls.price_tiers.find_or_create_by!(tier_name: tier_attrs[:tier_name]) do |t|
    t.assign_attributes(tier_attrs)
  end
  Rails.logger.debug { "  ✅ #{tier.tier_name}: #{tier.formatted_price} (#{tier.quantity_range_description})" }
end

# Bubble Tea Slamky - B2B pricing
slamky = created_products[1]
[
  { tier_name: '1ks', min_quantity: 1, max_quantity: 9, price_cents: 8000, description: 'Jednotlivé balení 100ks' },
  { tier_name: '1bal', min_quantity: 10, max_quantity: 49, price_cents: 7200,
    description: 'Balení 10 kusů - úspora 10%' },
  { tier_name: '10bal', min_quantity: 50, max_quantity: nil, price_cents: 6400,
    description: 'Kartón 50+ kusů - úspora 20%' }
].each do |tier_attrs|
  tier = slamky.price_tiers.find_or_create_by!(tier_name: tier_attrs[:tier_name]) do |t|
    t.assign_attributes(tier_attrs)
  end
  Rails.logger.debug { "  ✅ #{tier.tier_name}: #{tier.formatted_price} (#{tier.quantity_range_description})" }
end

# Tapiokové perly - měsíční dodávky
perly = created_products[2]
[
  { tier_name: '1ks', min_quantity: 1, max_quantity: 9, price_cents: 15_000, description: 'Jednotlivý balíček' },
  { tier_name: '1bal', min_quantity: 10, max_quantity: 29, price_cents: 13_500,
    description: 'Měsíční dodávka - úspora 10%' },
  { tier_name: '10bal', min_quantity: 30, max_quantity: nil, price_cents: 12_000,
    description: 'Velkoobchodní cena - úspora 20%' }
].each do |tier_attrs|
  tier = perly.price_tiers.find_or_create_by!(tier_name: tier_attrs[:tier_name]) do |t|
    t.assign_attributes(tier_attrs)
  end
  Rails.logger.debug { "  ✅ #{tier.tier_name}: #{tier.formatted_price} (#{tier.quantity_range_description})" }
end

# Taro Syrup - pouze velkoobchod
syrup = created_products[3]
[
  { tier_name: '1ks', min_quantity: 1, max_quantity: 5, price_cents: 32_000, description: 'Jednotlivý kanystr 2.5L' },
  { tier_name: '1bal', min_quantity: 6, max_quantity: 11, price_cents: 28_800,
    description: 'Balení 6 kusů - úspora 10%' },
  { tier_name: '10bal', min_quantity: 12, max_quantity: nil, price_cents: 25_600,
    description: 'Paletová dodávka - úspora 20%' }
].each do |tier_attrs|
  tier = syrup.price_tiers.find_or_create_by!(tier_name: tier_attrs[:tier_name]) do |t|
    t.assign_attributes(tier_attrs)
  end
  Rails.logger.debug { "  ✅ #{tier.tier_name}: #{tier.formatted_price} (#{tier.quantity_range_description})" }
end

# Create variant attributes and values
Rails.logger.debug "\n🎨 Creating variant attributes..."

# Create flavor attribute with values
flavor_attr = VariantAttribute.find_or_create_flavor!
flavor_values = [
  { value: 'strawberry', display_value: 'Jahoda', color_code: '#FF6B6B', description: 'Sladká chuť jahod' },
  { value: 'mango', display_value: 'Mango', color_code: '#FFD93D', description: 'Tropická chuť manga' },
  { value: 'lychee', display_value: 'Liči', color_code: '#FFB3BA', description: 'Exotická chuť liči' },
  { value: 'passion_fruit', display_value: 'Marakuja', color_code: '#FF8C42', description: 'Intenzivní chuť marakuja' },
  { value: 'coconut', display_value: 'Kokos', color_code: '#F7F7F7', description: 'Krémová chuť kokosu' },
  { value: 'green_apple', display_value: 'Zelené jablko', color_code: '#8FBC8F',
    description: 'Svěží chuť zeleného jablka' }
]

flavor_values.each_with_index do |attrs, index|
  value = flavor_attr.variant_attribute_values.find_or_create_by!(value: attrs[:value]) do |v|
    v.assign_attributes(attrs.merge(sort_order: index + 1))
  end
  Rails.logger.debug { "  ✅ Flavor: #{value.display_value} (#{value.color_code})" }
end

# Create size attribute with values
size_attr = VariantAttribute.find_or_create_size!
size_values = [
  { value: 'small', display_value: 'Malé (1kg)', description: 'Balení 1kg pro menší provozovny' },
  { value: 'medium', display_value: 'Střední (3kg)', description: 'Standardní balení 3kg' },
  { value: 'large', display_value: 'Velké (5kg)', description: 'Velké balení 5kg pro velkoobchod' }
]

size_values.each_with_index do |attrs, index|
  value = size_attr.variant_attribute_values.find_or_create_by!(value: attrs[:value]) do |v|
    v.assign_attributes(attrs.merge(sort_order: index + 1))
  end
  Rails.logger.debug { "  ✅ Size: #{value.display_value}" }
end

# Create parent product for Popping Pearls variants
Rails.logger.debug "\n🫧 Creating Popping Pearls variants..."

# First, convert existing Popping Pearls to parent product
popping_parent = created_products.first
popping_parent.update!(
  is_variant_parent: true,
  name: 'Popping Pearls',
  description: 'Praskající kuličky do bubble tea - různé příchutě a velikosti'
)

# Get flavor and size values
strawberry = VariantAttributeValue.find_by(value: 'strawberry')
mango = VariantAttributeValue.find_by(value: 'mango')
lychee = VariantAttributeValue.find_by(value: 'lychee')
passion_fruit = VariantAttributeValue.find_by(value: 'passion_fruit')

medium_size = VariantAttributeValue.find_by(value: 'medium')
large_size = VariantAttributeValue.find_by(value: 'large')

# Create variants with different flavors and sizes
variants_data = [
  {
    attributes: { 'flavor' => strawberry.id, 'size' => medium_size.id },
    product: { price_cents: 25_000, quantity: 50, description: 'Praskající kuličky s příchutí jahoda - balení 3kg' }
  },
  {
    attributes: { 'flavor' => mango.id, 'size' => medium_size.id },
    product: { price_cents: 26_000, quantity: 45, description: 'Praskající kuličky s příchutí mango - balení 3kg' }
  },
  {
    attributes: { 'flavor' => lychee.id, 'size' => medium_size.id },
    product: { price_cents: 27_000, quantity: 40, description: 'Praskající kuličky s příchutí liči - balení 3kg' }
  },
  {
    attributes: { 'flavor' => passion_fruit.id, 'size' => medium_size.id },
    product: { price_cents: 25_000, quantity: 35, description: 'Praskající kuličky s příchutí marakuja - balení 3kg' }
  },
  {
    attributes: { 'flavor' => strawberry.id, 'size' => large_size.id },
    product: { price_cents: 40_000, quantity: 20,
               description: 'Praskající kuličky s příchutí jahoda - velké balení 5kg' }
  },
  {
    attributes: { 'flavor' => mango.id, 'size' => large_size.id },
    product: { price_cents: 42_000, quantity: 18,
               description: 'Praskající kuličky s příchutí mango - velké balení 5kg' }
  }
]

variants_data.each_with_index do |variant_data, index|
  variant = create_or_find_variant(popping_parent, variant_data, index)
  create_variant_bulk_pricing(variant)

  Rails.logger.debug do
    "  ✅ #{variant.variant_display_name} - #{variant.formatted_price} (SKU: #{variant.variant_sku})"
  end
end

Rails.logger.debug "\n🎯 Database seeded successfully!"
Rails.logger.debug { "📊 Created #{User.count} users, #{Product.count} products, #{ProductPriceTier.count} price tiers" }
Rails.logger.debug do
  "🎨 Created #{VariantAttribute.count} variant attributes, #{VariantAttributeValue.count} variant values"
end
Rails.logger.debug { "🫧 Created #{Product.variant_children.count} product variants" }
Rails.logger.debug "\n💡 Test features:"
Rails.logger.debug '  - Login as: admin@lootea.cz / password123'
Rails.logger.debug '  - Query products with priceTiers and variants fields'
Rails.logger.debug '  - Use priceForQuantity(quantity: X) to see dynamic pricing'
Rails.logger.debug '  - Check variant products with flavor/size attributes'

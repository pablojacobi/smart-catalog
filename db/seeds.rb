# frozen_string_literal: true

require 'json'

# Seed data for SmartCatalog from JSON file
# Run with: docker-compose run --rm app rails db:seed
# Note: Seeds are skipped in test environment to avoid conflicts with factories

# Skip seeding in test environment
if Rails.env.test?
  puts 'Skipping seeds in test environment (use factories instead)'
  return
end

# Create admin user
puts 'Creating admin user...'
admin = User.find_or_create_by!(email: 'pablo@test.com') do |u|
  u.password = '1%8/4&AZ'
  u.password_confirmation = '1%8/4&AZ'
end
puts "✓ Admin user created: #{admin.email}"

puts 'Seeding database from JSON...'

# Load JSON data
json_path = Rails.root.join('db/catalog_1000.json')

unless File.exist?(json_path)
  puts "ERROR: JSON file not found at #{json_path}"
  puts 'Please place catalog_1000.json in the db/ directory'
  raise "Seeding aborted: missing data file at #{json_path}"
end

puts "Loading data from #{json_path}..."
data = JSON.parse(File.read(json_path))

# Create categories
puts 'Creating categories...'
categories_count = 0
data['categories'].each do |cat|
  Category.find_or_create_by!(id: cat['id']) do |c|
    c.name = cat['name']
    c.slug = cat['slug']
    categories_count += 1
  end
end
puts "✓ Created #{categories_count} categories (#{Category.count} total)"

# Create brands
puts 'Creating brands...'
brands_count = 0
data['brands'].each do |brand|
  Brand.find_or_create_by!(id: brand['id']) do |b|
    b.name = brand['name']
    b.slug = brand['name'].parameterize
    brands_count += 1
  end
end
puts "✓ Created #{brands_count} brands (#{Brand.count} total)"

# Create products
puts 'Creating products...'
products_count = 0
failed_products = []

data['products'].each_with_index do |product, index|
  Product.find_or_create_by!(sku: product['sku']) do |p|
    p.id = product['id']
    p.name = product['name']
    p.description = product['description']
    p.price = product['price']
    # Normalize currency: "USD$" -> "USD", "EUR€" -> "EUR", etc.
    p.currency = product['currency'].gsub(/[^A-Z]/, '')
    p.category_id = product['category_id']
    p.brand_id = product['brand_id']
    p.specifications = product['specifications']
    p.status = 'active'
    p.in_stock = true
    p.stock_quantity = rand(5..50)
    products_count += 1
  end

  # Progress indicator every 100 products
  puts "  Processed #{index + 1}/#{data['products'].count} products..." if ((index + 1) % 100).zero?
rescue StandardError => e
  failed_products << { sku: product['sku'], error: e.message }
end

puts "✓ Created #{products_count} products (#{Product.count} total)"

if failed_products.any?
  puts "\n⚠ Failed to create #{failed_products.count} products:"
  failed_products.first(5).each do |failure|
    puts "  - #{failure[:sku]}: #{failure[:error]}"
  end
  puts "  ... and #{failed_products.count - 5} more" if failed_products.count > 5
end

puts "\n✅ Seeding complete!"
puts "  Categories: #{Category.count}"
puts "  Brands: #{Brand.count}"
puts "  Products: #{Product.count}"

# frozen_string_literal: true

# Seed data for SmartCatalog
# Run with: docker-compose exec app rails db:seed

Rails.logger.debug 'Seeding database...'

# Create categories
categories = [
  { name: 'Electronics', slug: 'electronics', description: 'Electronic devices and gadgets' },
  { name: 'Computers', slug: 'computers', description: 'Laptops, desktops, and accessories' },
  { name: 'Phones', slug: 'phones', description: 'Smartphones and accessories' },
  { name: 'Audio', slug: 'audio', description: 'Headphones, speakers, and audio equipment' },
  { name: 'Accessories', slug: 'accessories', description: 'Tech accessories and peripherals' }
].map do |attrs|
  Category.find_or_create_by!(slug: attrs[:slug]) do |c|
    c.name = attrs[:name]
    c.description = attrs[:description]
  end
end

Rails.logger.debug { "Created #{categories.count} categories" }

# Create brands
brands = [
  { name: 'Apple', slug: 'apple' },
  { name: 'Samsung', slug: 'samsung' },
  { name: 'Sony', slug: 'sony' },
  { name: 'Dell', slug: 'dell' },
  { name: 'HP', slug: 'hp' },
  { name: 'Lenovo', slug: 'lenovo' },
  { name: 'Google', slug: 'google' },
  { name: 'Microsoft', slug: 'microsoft' },
  { name: 'Bose', slug: 'bose' },
  { name: 'JBL', slug: 'jbl' }
].map do |attrs|
  Brand.find_or_create_by!(slug: attrs[:slug]) do |b|
    b.name = attrs[:name]
  end
end

Rails.logger.debug { "Created #{brands.count} brands" }

# Create sample products
products_data = [
  {
    name: 'MacBook Pro 14"',
    sku: 'MBP-14-M3',
    description: 'Apple MacBook Pro with M3 Pro chip, 14-inch Liquid Retina XDR display',
    price: 1999.00,
    category: 'computers',
    brand: 'apple',
    specifications: {
      'processor' => 'Apple M3 Pro',
      'memory' => '18GB',
      'storage' => '512GB SSD',
      'display' => '14.2-inch Liquid Retina XDR'
    }
  },
  {
    name: 'iPhone 15 Pro',
    sku: 'IP15-PRO-256',
    description: 'Apple iPhone 15 Pro with A17 Pro chip and titanium design',
    price: 999.00,
    category: 'phones',
    brand: 'apple',
    specifications: {
      'processor' => 'A17 Pro',
      'storage' => '256GB',
      'display' => '6.1-inch Super Retina XDR',
      'camera' => '48MP Main + 12MP Ultra Wide + 12MP Telephoto'
    }
  },
  {
    name: 'Galaxy S24 Ultra',
    sku: 'GS24-ULTRA-512',
    description: 'Samsung Galaxy S24 Ultra with S Pen and AI features',
    price: 1199.00,
    category: 'phones',
    brand: 'samsung',
    specifications: {
      'processor' => 'Snapdragon 8 Gen 3',
      'storage' => '512GB',
      'display' => '6.8-inch QHD+ Dynamic AMOLED',
      'camera' => '200MP Main + 12MP Ultra Wide + 50MP Telephoto'
    }
  },
  {
    name: 'Dell XPS 15',
    sku: 'DELL-XPS15-I7',
    description: 'Dell XPS 15 with Intel Core i7 and OLED display',
    price: 1599.00,
    category: 'computers',
    brand: 'dell',
    specifications: {
      'processor' => 'Intel Core i7-13700H',
      'memory' => '16GB DDR5',
      'storage' => '512GB SSD',
      'display' => '15.6-inch 3.5K OLED'
    }
  },
  {
    name: 'Sony WH-1000XM5',
    sku: 'SONY-WH1000XM5',
    description: 'Sony premium wireless noise-canceling headphones',
    price: 349.00,
    category: 'audio',
    brand: 'sony',
    specifications: {
      'driver' => '30mm',
      'battery' => '30 hours',
      'noise_canceling' => 'Yes',
      'connectivity' => 'Bluetooth 5.2'
    }
  },
  {
    name: 'AirPods Pro 2',
    sku: 'AIRPODS-PRO2',
    description: 'Apple AirPods Pro with USB-C and Adaptive Audio',
    price: 249.00,
    category: 'audio',
    brand: 'apple',
    specifications: {
      'chip' => 'H2',
      'battery' => '6 hours (30 with case)',
      'noise_canceling' => 'Yes',
      'connectivity' => 'Bluetooth 5.3'
    }
  },
  {
    name: 'ThinkPad X1 Carbon',
    sku: 'TP-X1C-G11',
    description: 'Lenovo ThinkPad X1 Carbon Gen 11 ultrabook',
    price: 1449.00,
    category: 'computers',
    brand: 'lenovo',
    specifications: {
      'processor' => 'Intel Core i7-1365U',
      'memory' => '16GB LPDDR5',
      'storage' => '512GB SSD',
      'display' => '14-inch 2.8K OLED'
    }
  },
  {
    name: 'Pixel 8 Pro',
    sku: 'PIXEL8-PRO-256',
    description: 'Google Pixel 8 Pro with Tensor G3 and AI features',
    price: 999.00,
    category: 'phones',
    brand: 'google',
    specifications: {
      'processor' => 'Google Tensor G3',
      'storage' => '256GB',
      'display' => '6.7-inch LTPO OLED',
      'camera' => '50MP Main + 48MP Ultra Wide + 48MP Telephoto'
    }
  },
  {
    name: 'Surface Laptop 5',
    sku: 'SL5-15-I7',
    description: 'Microsoft Surface Laptop 5 with touchscreen',
    price: 1299.00,
    category: 'computers',
    brand: 'microsoft',
    specifications: {
      'processor' => 'Intel Core i7-1255U',
      'memory' => '16GB LPDDR5x',
      'storage' => '512GB SSD',
      'display' => '15-inch PixelSense Touch'
    }
  },
  {
    name: 'Bose QuietComfort Ultra',
    sku: 'BOSE-QC-ULTRA',
    description: 'Bose QuietComfort Ultra wireless headphones with spatial audio',
    price: 429.00,
    category: 'audio',
    brand: 'bose',
    specifications: {
      'battery' => '24 hours',
      'noise_canceling' => 'Yes',
      'spatial_audio' => 'Yes',
      'connectivity' => 'Bluetooth 5.3'
    }
  }
]

categories_map = Category.all.index_by(&:slug)
brands_map = Brand.all.index_by(&:slug)

products_data.each do |data|
  Product.find_or_create_by!(sku: data[:sku]) do |p|
    p.name = data[:name]
    p.description = data[:description]
    p.price = data[:price]
    p.currency = 'USD'
    p.category = categories_map[data[:category]]
    p.brand = brands_map[data[:brand]]
    p.specifications = data[:specifications]
    p.in_stock = true
    p.stock_quantity = rand(10..100)
  end
end

Rails.logger.debug { "Created #{Product.count} products" }

Rails.logger.debug 'Seeding complete!'

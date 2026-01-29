# Seed Data

## Overview

The seed data for SmartCatalog consists of 1000+ electronic device products (laptops, tablets, mobile accessories) with real brands, coherent specifications, and detailed descriptions.

## Data File

The seed script expects a JSON file at `db/catalog_1000.json` with the following structure:

```json
{
  "generated_at": "ISO-8601 timestamp",
  "categories": [
    {
      "id": "uuid",
      "name": "Category Name",
      "slug": "category-slug"
    }
  ],
  "brands": [
    {
      "id": "uuid",
      "name": "Brand Name"
    }
  ],
  "products": [
    {
      "id": "uuid",
      "document_id": "uuid (ignored by seeds)",
      "name": "Product Name",
      "description": "Detailed product description",
      "price": 999.99,
      "currency": "USD$",
      "sku": "UNIQUE-SKU-CODE",
      "specifications": {
        "type": "laptop|tablet|accessory",
        "cpu": "Processor model",
        "ram_gb": 16,
        "storage_gb": 512,
        "display_size_in": 14.0,
        "...": "other specs"
      },
      "category_id": "uuid",
      "brand_id": "uuid"
    }
  ]
}
```

## Getting the Data

The `catalog_1000.json` file is not included in the repository due to its size (~1MB). You can:

1. **Generate your own data** following the structure above
2. **Request the sample file** from the project maintainer
3. **Use the existing sample seeds** in `db/seeds.rb` (10 products only)

## Running Seeds

### Local Development

```bash
# Place catalog_1000.json in db/ directory
cp path/to/catalog_1000.json db/

# Run migrations and seeds
docker-compose run --rm app rails db:migrate db:seed
```

### Production

```bash
# Set environment and run seeds
RAILS_ENV=production rails db:migrate db:seed
```

### Idempotency

The seed script is idempotent:
- Categories are created by UUID
- Brands are created by UUID
- Products are created by SKU (unique constraint)

Running seeds multiple times will not create duplicates.

## Resetting Data

To completely reset the database and reseed:

```bash
# Development
docker-compose run --rm app rails db:reset db:seed

# Production (DESTRUCTIVE - use with caution)
RAILS_ENV=production rails db:reset db:seed
```

## Data Statistics

When fully seeded:
- **Categories**: 3 (Laptops, Tablets, Mobile Accessories)
- **Brands**: 40 (Apple, Samsung, Dell, HP, Lenovo, etc.)
- **Products**: 1000+ with complete specifications

## Seed Script Features

- Progress indicators every 100 products
- Error handling with detailed failure reports
- Currency normalization (USD$, EUR€ → USD, EUR)
- Random stock quantities (5-50 units)
- All products marked as active and in stock

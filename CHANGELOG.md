# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-01-28

### Added
- Initial release of SmartCatalog portfolio demo
- **AI Features**
  - Hybrid search combining vector similarity (pgvector) with SQL filters
  - LLM query classification using Google Gemini
  - Contextual conversation support with message history
  - Cost-optimized response strategies (direct SQL vs LLM)
- **API Endpoints**
  - Chat completions (OpenAI-compatible format)
  - Products CRUD with advanced filtering
  - Categories and Brands management
  - Documents management
  - Stats overview endpoint
  - Health check with version info
- **Architecture Patterns**
  - Service-oriented architecture with `CallableService`
  - Result objects for explicit error handling
  - Query objects for complex database queries
  - Blueprinter serializers for JSON responses
  - Centralized error handling with custom exceptions
- **Testing**
  - 100% code coverage with RSpec
  - Request specs for all API endpoints
  - Unit tests for services, models, and queries
  - WebMock stubs for external API calls
- **DevOps**
  - Docker and docker-compose configuration
  - GitHub Actions CI pipeline
  - RuboCop linting configuration
  - Brakeman security scanning

### Technical Stack
- Ruby 3.4.1
- Rails 8.1
- PostgreSQL 16 with pgvector
- Google Gemini 1.5 Flash
- RSpec + FactoryBot + WebMock + SimpleCov

## [Unreleased]

### Planned
- OpenAPI/Swagger documentation
- Rate limiting with Redis
- API authentication (JWT)
- Caching layer for frequent queries

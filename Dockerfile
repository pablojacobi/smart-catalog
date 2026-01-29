# syntax=docker/dockerfile:1
FROM ruby:3.4.8-slim

# Install dependencies
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential \
    git \
    libpq-dev \
    libyaml-dev \
    curl \
    && rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Set working directory
WORKDIR /app

# Install bundler
RUN gem install bundler -v 2.6.2

# Copy Gemfile
COPY Gemfile Gemfile.lock ./

# Add platform and install gems
RUN bundle lock --add-platform x86_64-linux && \
    bundle install --jobs 4 --retry 3

# Copy application
COPY . .

# Create required directories
RUN mkdir -p tmp/pids tmp/cache tmp/sockets log

# Precompile assets for production
ENV RAILS_ENV=production
ENV SECRET_KEY_BASE=dummy_key_for_precompilation
RUN bundle exec rails assets:precompile

# Expose port
EXPOSE 3000

# Default command
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]

# frozen_string_literal: true

ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)

require 'bundler/setup'

# Skip bootsnap in CI to avoid frozen array issues with Devise
require 'bootsnap/setup' unless ENV['CI']

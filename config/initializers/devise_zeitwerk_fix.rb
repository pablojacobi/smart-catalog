# frozen_string_literal: true

# Fix for Devise 4.9.x + Rails 8.1 + Zeitwerk compatibility
#
# Problem: In production, Zeitwerk eager loads ALL files including Devise's mailer.
# Devise::Mailer uses inheritance patterns that Zeitwerk can't resolve properly.
#
# Solution: Since we don't use Devise email features (no :confirmable, :recoverable),
# we pre-define Devise::Mailer as a stub before Zeitwerk tries to autoload it.
#
# This initializer runs early (alphabetically before 'd') and creates the constant
# so Zeitwerk won't try to load the problematic file.

if Rails.env.production?
  # Ensure ActionMailer is loaded first
  require 'action_mailer' unless defined?(ActionMailer)

  # Pre-define Devise::Mailer to prevent Zeitwerk from trying to load it
  module Devise
    class Mailer < ApplicationMailer
      # Stub mailer - we don't use Devise email features
      def self.method_missing(method, *_args)
        new.tap { |m| m.class.define_method(method) { |*| self } }
      end

      def self.respond_to_missing?(*)
        true
      end
    end
  end
end

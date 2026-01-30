# frozen_string_literal: true

# Fix for Devise 4.9.x + Rails 8.1 + Zeitwerk compatibility
#
# Problem: Devise::Mailer needs a parent mailer class to inherit from.
# By default it looks for ApplicationMailer.
#
# Solution: We've created app/mailers/application_mailer.rb and configured
# Devise to use it via config.parent_mailer = 'ApplicationMailer' in devise.rb
#
# This is the standard Rails approach and works properly with Zeitwerk.
# Even though we don't use Devise email features (:confirmable, :recoverable),
# Zeitwerk still tries to load Devise::Mailer during eager loading in production.
#
# No code needed here - this file documents the fix for future reference.

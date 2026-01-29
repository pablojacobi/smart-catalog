# frozen_string_literal: true

# Fix Zeitwerk compatibility issue with Devise 4.9.4 and Rails 8.1
# During eager loading in production, Zeitwerk fails to autoload Devise::Mailer
# because it expects the file to define the constant, but Devise uses a different
# loading mechanism.
#
# This fix ensures Devise::Mailer is loaded before Zeitwerk tries to eager load it.
Rails.application.config.before_eager_load do
  require 'devise/mailer'
end

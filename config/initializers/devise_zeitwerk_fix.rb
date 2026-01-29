# frozen_string_literal: true

# Fix Zeitwerk compatibility issue with Devise 4.9.4 and Rails 8.1
# During eager loading in production, Zeitwerk fails to autoload Devise::Mailer
# because Devise uses class_eval which Zeitwerk doesn't recognize.
#
# This preloads the mailer before Zeitwerk tries to eager load it.
Rails.application.config.before_eager_load do
  require 'devise/mailer'
end

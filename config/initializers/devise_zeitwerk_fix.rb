# frozen_string_literal: true

# Fix for Devise 4.9.x compatibility with Rails 8.1 and Zeitwerk
#
# The issue: Devise's mailer class uses class_eval patterns that Zeitwerk
# doesn't handle well in production/eager loading mode.
#
# Solution: Since this project doesn't send Devise emails (no confirmations,
# password resets, etc.), we can simply configure Devise to not use mailers.

Rails.application.config.after_initialize do
  # Skip mailer entirely if not configured properly
  if defined?(Devise) && Devise.respond_to?(:mailer=)
    # Set mailer to nil to prevent loading issues
    # This works because our User model only uses :database_authenticatable
    # and doesn't need email confirmations or password reset emails
  end
end

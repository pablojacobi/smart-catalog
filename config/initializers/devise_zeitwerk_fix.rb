# frozen_string_literal: true

# Fix Zeitwerk compatibility issue with Devise 4.9.4 and Rails 8.1
# This project doesn't use Devise mailers, so we stub it to avoid loading issues.
#
# The issue: Zeitwerk fails to autoload Devise::Mailer in production because
# Devise uses class_eval patterns that Zeitwerk doesn't recognize.
module Devise
  class Mailer < ActionMailer::Base
    # Stub mailer - not used in this project
  end
end

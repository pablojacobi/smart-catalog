# frozen_string_literal: true

require 'action_mailer'

class ApplicationMailer < ActionMailer::Base
  default from: 'noreply@smartcatalog.com'
  layout 'mailer'
end

module Maintenance
  module User
    class PasswordResetMailer < ActionMailer::Base
      default :from => YiffyAPI.config.mail_from_addr, :content_type => "text/html"

      def reset_request(user, nonce)
        @user = user
        @nonce = nonce
        mail(:to => @user.email, :subject => "#{YiffyAPI.config.app_name} password reset")
      end
    end
  end
end

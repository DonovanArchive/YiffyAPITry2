module Maintenance
  module User
    class EmailConfirmationMailer < ActionMailer::Base
      helper ApplicationHelper
      helper UsersHelper
      default :from => YiffyAPI.config.mail_from_addr, :content_type => "text/html"

      def confirmation(user)
        @user = user
        mail(:to => @user.email, :subject => "#{YiffyAPI.config.app_name} account confirmation")
      end
    end
  end
end

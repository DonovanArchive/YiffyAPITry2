class StaticController < ApplicationController
  def privacy
    @page = WikiPage.find_by(title: "e621:privacy_policy")
    if @page.nil?
      render "static/404", formats: [:html], status: 404
    end
  end

  def terms_of_service
    @page = WikiPage.find_by(title: "e621:terms_of_service")
    if @page.nil?
      render "static/404", formats: [:html], status: 404
    end
  end

  def contact
    @page = WikiPage.find_by(title: "e621:contact")
    if @page.nil?
      render "static/404", formats: [:html], status: 404
    end
  end

  def takedown
    @page = WikiPage.find_by(title: "e621:takedown")
    if @page.nil?
      render "static/404", formats: [:html], status: 404
    end
  end

  def not_found
    render "static/404", formats: [:html], status: 404
  end

  def error
  end

  def site_map
  end

  def home
    render layout: "blank"
  end

  def theme
  end

  def disable_mobile_mode
    if CurrentUser.is_member? && !YiffyAPI.config.readonly_mode?
      user = CurrentUser.user
      user.disable_responsive_mode = !user.disable_responsive_mode
      user.save
    else
      if cookies[:disable_mobile_mode]
        cookies.delete(:disable_mobile_mode)
      else
        cookies.permanent[:disable_mobile_mode] = '1'
      end
    end
    redirect_back fallback_location: posts_path
  end

  def discord
    unless CurrentUser.can_discord?
      raise User::PrivilegeError.new("You must have an account for at least one week in order to join the Discord server.")
    end
    if request.post?
      time = (Time.now + 5.minutes).to_i
      secret = YiffyAPI.config.discord_secret
      # TODO: Proper HMAC
      hashed_values = Digest::SHA256.hexdigest("#{CurrentUser.name} #{CurrentUser.id} #{time} #{secret}")
      user_hash = "?user_id=#{CurrentUser.id}&username=#{CurrentUser.name}&time=#{time}&hash=#{hashed_values}"

      redirect_to(YiffyAPI.config.discord_site + user_hash, allow_other_host: true)
    end
  end

  def enforce_readonly
  end
end

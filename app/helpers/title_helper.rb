module TitleHelper
  def get_title
    return YiffyAPI.config.app_name if current_page? root_path
    return content_for(:page_title) + " - " + YiffyAPI.config.app_name if content_for? :page_title
  end
end

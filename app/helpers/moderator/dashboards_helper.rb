module Moderator
  module DashboardsHelper
    def user_level_select_tag(name, options = {})
      choices = [["", ""]]
      YiffyAPI.config.levels.each { |level_name, level_value| choices << [level_name, level_value] }

      select_tag(name, options_for_select(choices, params[name].to_i), options)
    end
  end
end

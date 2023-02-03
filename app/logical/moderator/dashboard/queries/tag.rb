module Moderator
  module Dashboard
    module Queries
      Tag = ::Struct.new(:user, :count) do
        def self.all(min_date, max_level)
          records = PostVersion.where("updated_at > ?", min_date).group(:updater).count.map do |user, count|
            new(user, count)
          end

          records.select { |rec| rec.user.level <= max_level }.sort_by(&:count).reverse.take(10)
        end
      end
    end
  end
end

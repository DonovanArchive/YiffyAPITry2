# typed: false
# frozen_string_literal: true

require "digest/md5"
require "net/http"
require "tempfile"

unless Rails.env.test?
  puts "== Creating elasticsearch indices ==\n"

  Post.__elasticsearch__.create_index!
end

puts "== Seeding database with sample content ==\n"

# Uncomment to see detailed logs
# ActiveRecord::Base.logger = ActiveSupport::Logger.new($stdout)
#
def create_user(name, level, created_at = nil)
  user = User.find_or_initialize_by(name: name) do |usr|
    yield(usr) if block_given?
    usr.created_at = created_at unless created_at.nil?
    usr.password = name
    usr.password_confirmation = name
    usr.password_hash = ""
    usr.email = "#{name.downcase}@yiffy.local"
    usr.level = level
  end
  user.save(validate: false) if user.new_record?

  unless Rails.env.production?
    ApiKey.create(user_id: user.id, key: name)
  end
  user
end

admin = create_user("admin", User::Levels::ADMIN, 2.weeks.ago) do |user|
  user.can_upload_free = true
  user.can_approve_posts = true
  user.replacements_beta = true
end

create_user(YiffyAPI.config.system_user, User::Levels::SYSTEM, 2.weeks.ago) do |user|
  user.can_upload_free = true
  user.can_approve_posts = true
end

ForumCategory.find_or_create_by!(id: YiffyAPI.config.alias_implication_forum_category) do |category|
  category.name = "Tag Alias and Implication Suggestions"
  category.can_view = User::Levels::ANONYMOUS
end

def api_request(path, base = "https://e621.net")
  auth = nil
  unless ENV.fetch("SEED_USERNAME", nil).nil? && ENV.fetch("SEED_APIKEY", nil).nil?
    auth = {
      username: ENV.fetch("SEED_USERNAME"),
      password: ENV.fetch("SEED_APIKEY"),
    }
  end
  response = HTTParty.get("#{base}#{path}", {
    headers: { "User-Agent" => "YiffyAPI/seeding" },
    basic_auth: auth,
  })
  JSON.parse(response.body)
end



def create_post(post)
  url = post["file"]["url"]
  url = "https://static1.e621.net/data/#{post["file"]["md5"][0..1]}/#{post["file"]["md5"][2..3]}/#{post["file"]["md5"]}.#{post["file"]["ext"]}" if url.nil?
  puts "Pulling Post ##{post['id']} (#{url})"
  post["tags"].each do |category, tags|
    Tag.find_or_create_by_name_list(tags.map { |tag| "#{category}:#{tag}" })
  end

  post["sources"] << "https://e621.net/posts/#{post['id']}"
  service = UploadService.new({
    uploader: CurrentUser.user,
    uploader_ip_addr: CurrentUser.ip_addr,
    direct_url: url,
    tag_string: post["tags"].values.flatten.join(" "),
    source: post["sources"].join("\n"),
    description: post["description"],
    rating: post["rating"],
  })
  upload = service.start!
  if upload.post.nil?
    puts "Upload Failed: #{upload.errors.full_messages.join(', ')}"
  end
  upload.post
end

def import_posts
  ENV["YIFFYAPI_DISABLE_THROTTLES"] = "1"
  resources = YAML.load_file Rails.root.join("db/seeds.yml")
  search_tags = resources["post_ids"].blank? ? resources["tags"] : ["id:#{resources['post_ids'].join(',')}"]
  json = api_request("/posts.json?limit=#{ENV.fetch('SEED_POST_COUNT', 100)}&tags=#{search_tags.join('%20')}")
  json["posts"].each do |post|
    create_post(post)
  end
end

def import_mascots
  api_request("/mascots.json", "https://yiff.rest/msc").each do |mascot|
    puts mascot["url_path"]
    Mascot.create!(
      creator: CurrentUser.user,
      mascot_file: Downloads::File.new(mascot["url_path"]).download!,
      display_name: mascot["display_name"],
      background_color: mascot["background_color"],
      artist_url: mascot["artist_url"],
      artist_name: mascot["artist_name"],
      safe_mode_only: mascot["safe_mode_only"],
      active: mascot["active"],
    )
  end
end

unless Rails.env.test?
  CurrentUser.user = admin
  CurrentUser.ip_addr = "127.0.0.1"
  import_posts
  import_mascots
end

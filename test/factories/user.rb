FactoryBot.define do
  factory(:user, aliases: [:creator, :updater]) do
    sequence :name do |n|
      "user#{n}"
    end
    password { "password" }
    password_confirmation { "password" }
    password_hash {"password"}
    sequence(:email) { |n| "user_email_#{n}@example.com" }
    default_image_size { "large" }
    base_upload_limit { 10 }
    level { User::Levels::MEMBER }
    created_at {Time.now}
    last_logged_in_at {Time.now}

    factory(:banned_user) do
      transient { ban_duration { 3 } }
      is_banned { true }
    end

    factory(:member_user) do
      level { User::Levels::MEMBER }
    end

    factory(:privileged_user) do
      level { User::Levels::PRIVILIGED }
    end

    factory(:former_staff_user) do
      level { User::Levels::FORMER_STAFF }
    end

    factory(:janitor_user) do
      level { User::Levels::JANITOR }
      can_upload_free { true }
      can_approve_posts { true }
    end

    factory(:moderator_user) do
      level { User::Levels::MODERATOR }
      can_approve_posts { true }
    end

    factory(:mod_user) do
      level { User::Levels::MODERATOR }
      can_approve_posts { true }
    end

    factory(:admin_user) do
      level { User::Levels::ADMIN }
      can_approve_posts { true }
    end
  end
end

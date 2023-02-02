class StatsUpdater
  def self.run!
    stats = {
      started: Post.find(Post.minimum("id")).created_at,
      posts: {
        total: Post.maximum("id") || 0,
        active: Post.tag_match("status:active").count_only,
        deleted: Post.tag_match("status:deleted").count_only,
        destroyed: 0,
        existing: 0,
        average_per_day: 0,
        votes: PostVote.count,
        favorites: Favorite.count,
        ratings: {
          safe: Post.tag_match("status:any rating:s").count_only,
          questionable: Post.tag_match("status:any rating:q").count_only,
          explicit: Post.tag_match("status:any rating:e").count_only,
        },
        files: {
          average_size: Post.average("file_size").round(2),
          total_size: Post.sum("file_size"),
        },
      },
      notes: {
        total: Note.count,
        active: Note.where(is_active: true).count,
        deleted: 0,
      },
      pools: {
        total: Pool.maximum("id") || 0,
        active: Pool.where(is_active: true).count,
        inactive: 0,
        deleted: 0,
        existing: 0,
        collection: Pool.where(category: "collection").count,
        series: Pool.where(category: "series").count,
        average_posts: 0,
      },
      sets: {
        total: PostSet.maximum("id") || 0,
        active: PostSet.count,
        deleted: 0,
        public: PostSet.where(is_public: true).count,
        private: 0,
        average_posts: 0,
      },
      users: {
        total: User.count,
        average_per_day: 0,
        unactivated: User.where.not(email_verification_key: nil).count,
      },
      dmails: {
        total: Dmail.maximum("id") / 2,
        average_per_day: 0,
      },
      comments: {
        total: Comment.maximum("id") || 0,
        active: Comment.where(is_hidden: false).count,
        sticky: Comment.where(is_sticky: true).count,
        hidden: Comment.where(is_hidden: true).count,
        deleted: 0,
        average_per_day: 0,
        warnings: {},
      },
      forum_topics: {
        total: ForumTopic.count,
        active: ForumTopic.where(is_hidden: false).count,
        sticky: ForumTopic.where(is_sticky: true).count,
        locked: ForumTopic.where(is_locked: true).count,
        hidden: ForumTopic.where(is_hidden: true).count,
        average_per_day: 0,
      },
      forum_posts: {
        total: ForumPost.maximum("id") || 0,
        active: ForumPost.count,
        hidden: ForumPost.where(is_hidden: true).count,
        deleted: 0,
        average_per_day: 0,
        warnings: {},
      },
      blips: {
        total: Blip.maximum("id") || 0,
        active: Blip.count,
        hidden: Blip.where(is_hidden: true).count,
        deleted: 0,
        average_per_day: 0,
        warnings: {},
      },
      tags: {
        total: Tag.count,
        empty: Tag.where(post_count: 0).count,
      },
    }

    ### Posts ##
    stats[:posts][:destroyed] = stats[:posts][:total] - (stats[:posts][:active] + stats[:posts][:deleted])
    stats[:posts][:average_per_day] = (stats[:posts][:total] / ((Time.now - stats[:started]) / (60 * 60 * 24))).round unless stats[:posts][:total] == 0
    stats[:posts][:existing] = stats[:posts][:active] + stats[:posts][:deleted]

    YiffyAPI.config.max_file_sizes.each do |ext, _limit|
      stats[:posts][:files][ext.to_sym] = Post.tag_match("status:any type:#{ext}").count_only
    end

    ### Pools ##
    stats[:pools][:inactive] = stats[:pools][:total] - stats[:pools][:active]
    stats[:pools][:deleted] = stats[:pools][:total] - (stats[:pools][:active] + stats[:pools][:inactive])
    stats[:pools][:average_posts] = Pool.average(Arel.sql("cardinality(post_ids)")) || 0
    stats[:pools][:existing] = stats[:pools][:active] + stats[:pools][:deleted]

    ### Sets ##
    stats[:sets][:deleted] = stats[:sets][:total] - stats[:sets][:active]
    stats[:sets][:private] = stats[:sets][:active] - stats[:sets][:public]
    stats[:sets][:average_posts] = PostSet.average(Arel.sql("cardinality(post_ids)")) || 0

    ### Notes ##
    stats[:notes][:deleted] = stats[:notes][:total] - stats[:notes][:active]


    ### Users ##
    stats[:users][:average_per_day] = (stats[:users][:total] / ((Time.now - stats[:started]) / (60 * 60 * 24))).round unless stats[:users][:total] == 0

    YiffyAPI.config.levels.reject { |_name, level| level == User::Levels::ANONYMOUS }.each do |name, level|
      stats[:users][name.downcase.tr(" ", "_").to_sym] = User.where(level: level).count
    end

    ### Dmails ##
    stats[:dmails][:average_per_day] = (stats[:dmails][:total] / ((Time.now - stats[:started]) / (60 * 60 * 24))).round unless stats[:dmails][:total] == 0

    ### Comments ###
    stats[:comments][:deleted] = stats[:comments][:total] - stats[:comments][:active]
    unless stats[:comments][:total] == 0
      stats[:comments][:deleted] = stats[:comments][:total] - (stats[:comments][:active] + stats[:comments][:hidden])
      stats[:comments][:average_per_day] = (stats[:comments][:total] / ((Time.now - stats[:started]) / (60 * 60 * 24))).round
    end

    Comment.warning_types.each do |name, type|
      stats[:comments][:warnings][name.to_sym] = Comment.where(warning_type: type).count
    end

    ### Forum Topics ###
    stats[:forum_topics][:deleted] = stats[:forum_topics][:total] - stats[:forum_topics][:active]
    stats[:forum_topics][:average_per_day] = (stats[:forum_topics][:total] / ((Time.now - stats[:started]) / (60 * 60 * 24))).round unless stats[:forum_topics][:total] == 0

    ### Forum Posts ###
    stats[:forum_posts][:deleted] = stats[:forum_posts][:total] - stats[:forum_posts][:active]
    stats[:forum_posts][:average_per_day] = (stats[:forum_posts][:total] / ((Time.now - stats[:started]) / (60 * 60 * 24))).round unless stats[:forum_posts][:total] == 0

    ForumPost.warning_types.each do |name, type|
      stats[:forum_posts][:warnings][name.to_sym] = ForumPost.where(warning_type: type).count
    end

    ### Blips ###
    stats[:blips][:average_per_day] = (stats[:blips][:total] / ((Time.now - stats[:started]) / (60 * 60 * 24))).round unless stats[:blips][:total] == 0

    Blip.warning_types.each do |name, type|
      stats[:blips][:warnings][name.to_sym] = Blip.where(warning_type: type).count
    end
    ### Tags ###

    TagCategory.categories.each do |cat|
      stats[:tags][cat.to_sym] = Tag.where(category: TagCategory.mapping[cat]).count
    end

    RedisClient.client.set("e6stats", stats.to_json)
    stats
  end
end

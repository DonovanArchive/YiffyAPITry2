class PostQueryBuilder
  attr_accessor :query_string

  def initialize(query_string)
    @query_string = query_string
  end

  def add_range_relation(arr, field, relation)
    return relation if arr.nil?

    case arr[0]
    when :eq
      if arr[1].is_a?(Time)
        relation.where("#{field} between ? and ?", arr[1].beginning_of_day, arr[1].end_of_day)
      else
        relation.where(["#{field} = ?", arr[1]])
      end

    when :gt
      relation.where(["#{field} > ?", arr[1]])

    when :gte
      relation.where(["#{field} >= ?", arr[1]])

    when :lt
      relation.where(["#{field} < ?", arr[1]])

    when :lte
      relation.where(["#{field} <= ?", arr[1]])

    when :in
      relation.where(["#{field} in (?)", arr[1]])

    when :between
      relation.where(["#{field} BETWEEN ? AND ?", arr[1], arr[2]])

    else
      relation
    end
  end

  def escape_string_for_tsquery(array)
    array.map(&:to_escaped_for_tsquery)
  end

  def add_tag_string_search_relation(tags, relation)
    tag_query_sql = []

    if tags[:include].any?
      tag_query_sql << ("(#{escape_string_for_tsquery(tags[:include]).join(' | ')})")
    end

    if tags[:related].any?
      tag_query_sql << ("(#{escape_string_for_tsquery(tags[:related]).join(' & ')})")
    end

    if tags[:exclude].any?
      tag_query_sql << ("!(#{escape_string_for_tsquery(tags[:exclude]).join(' | ')})")
    end

    if tag_query_sql.any?
      relation = relation.where("posts.tag_index @@ to_tsquery('danbooru', E?)", tag_query_sql.join(" & "))
    end

    relation
  end

  def hide_deleted_posts?(query)
    return false if CurrentUser.admin_mode?
    return false if query[:status].in?(%w[deleted active any all])
    return false if query[:status_neg].in?(%w[deleted active any all])
    true
  end

  def build
    unless query_string.is_a?(Hash)
      query = Tag.parse_query(query_string)
    end

    relation = Post.all

    if query[:tag_count].to_i > YiffyAPI.config.tag_query_limit
      raise ::Post::SearchError, "You cannot search for more than #{YiffyAPI.config.tag_query_limit} tags at a time"
    end

    if CurrentUser.safe_mode?
      relation = relation.where("posts.rating = 's'")
    end

    relation = add_range_relation(query[:post_id], "posts.id", relation)
    relation = add_range_relation(query[:mpixels], "posts.image_width * posts.image_height / 1000000.0", relation)
    relation = add_range_relation(query[:ratio], "ROUND(1.0 * posts.image_width / GREATEST(1, posts.image_height), 2)", relation)
    relation = add_range_relation(query[:width], "posts.image_width", relation)
    relation = add_range_relation(query[:height], "posts.image_height", relation)
    relation = add_range_relation(query[:score], "posts.score", relation)
    relation = add_range_relation(query[:fav_count], "posts.fav_count", relation)
    relation = add_range_relation(query[:filesize], "posts.file_size", relation)
    relation = add_range_relation(query[:change_seq], "posts.change_seq", relation)
    relation = add_range_relation(query[:date], "posts.created_at", relation)
    relation = add_range_relation(query[:age], "posts.created_at", relation)
    TagCategory.categories.each do |category|
      relation = add_range_relation(query["#{category}_tag_count".to_sym], "posts.tag_count_#{category}", relation)
    end
    relation = add_range_relation(query[:post_tag_count], "posts.tag_count", relation)

    Tag::COUNT_METATAGS.each do |column|
      relation = add_range_relation(query[column.to_sym], "posts.#{column}", relation)
    end

    if query[:md5]
      relation = relation.where("posts.md5": query[:md5])
    end

    if query[:status] == "pending"
      relation = relation.where("posts.is_pending = TRUE")
    elsif query[:status] == "flagged"
      relation = relation.where("posts.is_flagged = TRUE")
    elsif query[:status] == "modqueue"
      relation = relation.where("posts.is_pending = TRUE OR posts.is_flagged = TRUE")
    elsif query[:status] == "deleted"
      relation = relation.where("posts.is_deleted = TRUE")
    elsif query[:status] == "active"
      relation = relation.where("posts.is_pending = FALSE AND posts.is_deleted = FALSE AND posts.is_flagged = FALSE")
    elsif query[:status] == "all" || query[:status] == "any"
      # do nothing
    elsif query[:status_neg] == "pending"
      relation = relation.where("posts.is_pending = FALSE")
    elsif query[:status_neg] == "flagged"
      relation = relation.where("posts.is_flagged = FALSE")
    elsif query[:status_neg] == "modqueue"
      relation = relation.where("posts.is_pending = FALSE AND posts.is_flagged = FALSE")
    elsif query[:status_neg] == "deleted"
      relation = relation.where("posts.is_deleted = FALSE")
    elsif query[:status_neg] == "active"
      relation = relation.where("posts.is_pending = TRUE OR posts.is_deleted = TRUE OR posts.is_flagged = TRUE")
    end

    if hide_deleted_posts?(query)
      relation = relation.where("posts.is_deleted = FALSE")
    end

    if query[:filetype]
      relation = relation.where("posts.file_ext": query[:filetype])
    end

    if query[:filetype_neg]
      relation = relation.where.not("posts.file_ext": query[:filetype_neg])
    end

    # The SourcePattern SQL function replaces Pixiv sources with "pixiv/[suffix]", where
    # [suffix] is everything past the second-to-last slash in the URL.  It leaves non-Pixiv
    # URLs unchanged.  This is to ease database load for Pixiv source searches.
    if query[:source]
      case query[:source]
      when "none%"
        relation = relation.where("posts.source = ''")
      when "http%"
        relation = relation.where("(lower(posts.source) like ?)", "http%")
      when %r{^(?:https?://)?%\.?pixiv(?:\.net(?:/img)?)?(?:%/img/|%/|(?=%$))(.+)$}i
        relation = relation.where("SourcePattern(lower(posts.source)) LIKE lower(?) ESCAPE E'\\\\'", "pixiv/#{$1}")
      else
        relation = relation.where("SourcePattern(lower(posts.source)) LIKE SourcePattern(lower(?)) ESCAPE E'\\\\'", query[:source])
      end
    end

    if query[:source_neg]
      case query[:source_neg]
      when "none%"
        relation = relation.where("posts.source != ''")
      when "http%"
        relation = relation.where("(lower(posts.source) not like ?)", "http%")
      when %r{^(?:https?://)?%\.?pixiv(?:\.net(?:/img)?)?(?:%/img/|%/|(?=%$))(.+)$}i
        relation = relation.where("SourcePattern(lower(posts.source)) NOT LIKE lower(?) ESCAPE E'\\\\'", "pixiv/#{$1}")
      else
        relation = relation.where("SourcePattern(lower(posts.source)) NOT LIKE SourcePattern(lower(?)) ESCAPE E'\\\\'", query[:source_neg])
      end
    end

    case query[:pool]
    when "none"
      relation = relation.where("posts.pool_string = ''")
    when "any"
      relation = relation.where("posts.pool_string != ''")
    end

    if query[:uploader_id_neg]
      relation = relation.where.not("posts.uploader_id": query[:uploader_id_neg])
    end

    if query[:uploader_id]
      relation = relation.where("posts.uploader_id": query[:uploader_id])
    end

    if query[:approver_id_neg]
      relation = relation.where.not("posts.approver_id": query[:approver_id_neg])
    end

    if query[:approver_id]
      case query[:approver_id]
      when "any"
        relation = relation.where.not(posts: { approver_id: nil })
      when "none"
        relation = relation.where("posts.approver_id is null")
      else
        relation = relation.where("posts.approver_id": query[:approver_id])
      end
    end

    query[:commenter_ids]&.each do |commenter_id|
      case commenter_id
      when "any"
        relation = relation.where.not(posts: { last_commented_at: nil })
      when "none"
        relation = relation.where("posts.last_commented_at is null")
      else
        relation = relation.where("posts.id": Comment.unscoped.where(creator_id: commenter_id).select(:post_id).distinct)
      end
    end

    query[:noter_ids]&.each do |noter_id|
      case noter_id
      when "any"
        relation = relation.where.not(posts: { last_noted_at: nil })
      when "none"
        relation = relation.where("posts.last_noted_at is null")
      else
        relation = relation.where("posts.id": Note.unscoped.where(creator_id: noter_id).select("post_id").distinct)
      end
    end

    query[:note_updater_ids]&.each do |note_updater_id|
      relation = relation.where("posts.id": NoteVersion.unscoped.where(updater_id: note_updater_id).select("post_id").distinct)
    end

    if query[:post_id_negated]
      relation = relation.where.not(posts: { id: query[:post_id_negated] })
    end

    if query[:parent] == "none"
      relation = relation.where("posts.parent_id IS NULL")
    elsif query[:parent] == "any"
      relation = relation.where.not(posts: { parent_id: nil })
    elsif query[:parent]
      relation = relation.where("posts.parent_id = ?", query[:parent].to_i)
    end

    if query[:parent_neg_ids]
      neg_ids = query[:parent_neg_ids].map(&:to_i)
      neg_ids.delete(0)
      if neg_ids.present?
        relation = relation.where("posts.id not in (?) and (posts.parent_id is null or posts.parent_id not in (?))", neg_ids, neg_ids)
      end
    end

    case query[:child]
    when "none"
      relation = relation.where("posts.has_children = FALSE")
    when "any"
      relation = relation.where("posts.has_children = TRUE")
    end

    case query[:rating]
    when /^q/
      relation = relation.where("posts.rating = 'q'")
    when /^s/
      relation = relation.where("posts.rating = 's'")
    when /^e/
      relation = relation.where("posts.rating = 'e'")
    end

    case query[:rating_negated]
    when /^q/
      relation = relation.where("posts.rating <> 'q'")
    when /^s/
      relation = relation.where("posts.rating <> 's'")
    when /^e/
      relation = relation.where("posts.rating <> 'e'")
    end

    case query[:locked]
    when "rating"
      relation = relation.where("posts.is_rating_locked = TRUE")
    when "note", "notes"
      relation = relation.where("posts.is_note_locked = TRUE")
    when "status"
      relation = relation.where("posts.is_status_locked = TRUE")
    end

    case query[:locked_negated]
    when "rating"
      relation = relation.where("posts.is_rating_locked = FALSE")
    when "note", "notes"
      relation = relation.where("posts.is_note_locked = FALSE")
    when "status"
      relation = relation.where("posts.is_status_locked = FALSE")
    end

    relation = add_tag_string_search_relation(query[:tags], relation)

    if query[:upvote].present?
      user_id = query[:upvote]
      post_ids = PostVote.where(user_id: user_id).where("score > 0").limit(400).pluck(:post_id)
      relation = relation.where("posts.id": post_ids)
    end

    if query[:downvote].present?
      user_id = query[:downvote]
      post_ids = PostVote.where(user_id: user_id).where("score < 0").limit(400).pluck(:post_id)
      relation = relation.where("posts.id": post_ids)
    end

    # HACK: if we're using a date: or age: metatag, default to ordering by
    # created_at instead of id so that the query will use the created_at index.
    if query[:date].present? || query[:age].present?
      case query[:order]
      when "id", "id_asc"
        query[:order] = "created_at_asc"
      when "id_desc", nil
        query[:order] = "created_at_desc"
      end
    end

    case query[:order]
    when "rank"
      relation = relation.where("posts.score > 0 and posts.created_at >= ?", 2.days.ago)
    when "landscape", "portrait"
      relation = relation.where("posts.image_width IS NOT NULL and posts.image_height IS NOT NULL")
    end

    case query[:order]
    when "id", "id_asc"
      relation = relation.order("posts.id ASC")

    when "id_desc"
      relation = relation.order("posts.id DESC")

    when "score", "score_desc"
      relation = relation.order("posts.score DESC, posts.id DESC")

    when "score_asc"
      relation = relation.order("posts.score ASC, posts.id ASC")

    when "favcount"
      relation = relation.order("posts.fav_count DESC, posts.id DESC")

    when "favcount_asc"
      relation = relation.order("posts.fav_count ASC, posts.id ASC")

    when "created_at", "created_at_desc"
      relation = relation.order("posts.created_at DESC")

    when "created_at_asc"
      relation = relation.order("posts.created_at ASC")

    when "change", "change_desc"
      relation = relation.order("posts.change_seq DESC, posts.id DESC")

    when "change_asc"
      relation = relation.order("posts.change_seq ASC, posts.id ASC")

    when "updated", "updated_desc"
      relation = relation.order("posts.updated_at DESC, posts.id DESC")

    when "updated_asc"
      relation = relation.order("posts.updated_at ASC, posts.id ASC")

    when "comment", "comm"
      relation = relation.order("posts.last_commented_at DESC NULLS LAST, posts.id DESC")

    when "comment_asc", "comm_asc"
      relation = relation.order("posts.last_commented_at ASC NULLS LAST, posts.id ASC")

    when "comment_bumped"
      relation = relation.order("posts.last_comment_bumped_at DESC NULLS LAST")

    when "comment_bumped_asc"
      relation = relation.order("posts.last_comment_bumped_at ASC NULLS FIRST")

    when "note"
      relation = relation.order("posts.last_noted_at DESC NULLS LAST")

    when "note_asc"
      relation = relation.order("posts.last_noted_at ASC NULLS FIRST")

    when "mpixels", "mpixels_desc"
      relation = relation.where(Arel.sql("posts.image_width is not null and posts.image_height is not null"))
      # Use "w*h/1000000", even though "w*h" would give the same result, so this can use
      # the posts_mpixels index.
      relation = relation.order(Arel.sql("posts.image_width * posts.image_height / 1000000.0 DESC"))

    when "mpixels_asc"
      relation = relation.where("posts.image_width is not null and posts.image_height is not null")
      relation = relation.order(Arel.sql("posts.image_width * posts.image_height / 1000000.0 ASC"))

    when "portrait"
      relation = relation.order(Arel.sql("1.0 * posts.image_width / GREATEST(1, posts.image_height) ASC"))

    when "landscape"
      relation = relation.order(Arel.sql("1.0 * posts.image_width / GREATEST(1, posts.image_height) DESC"))

    when "filesize", "filesize_desc"
      relation = relation.order("posts.file_size DESC")

    when "filesize_asc"
      relation = relation.order("posts.file_size ASC")

    when /\A(?<column>#{Tag::COUNT_METATAGS.join("|")})(_(?<direction>asc|desc))?\z/i
      column = $~[:column]
      direction = $~[:direction] || "desc"
      relation = relation.order(column => direction, :id => direction)

    when "tagcount", "tagcount_desc"
      relation = relation.order("posts.tag_count DESC")

    when "tagcount_asc"
      relation = relation.order("posts.tag_count ASC")

    when /(#{TagCategory.short_name_regex})tags(?:\Z|_desc)/
      relation = relation.order("posts.tag_count_#{TagCategory.short_name_mapping[$1]} DESC")

    when /(#{TagCategory.short_name_regex})tags_asc/
      relation = relation.order("posts.tag_count_#{TagCategory.short_name_mapping[$1]} ASC")

    when "rank"
      relation = relation.order(Arel.sql("log(3, posts.score) + (extract(epoch from posts.created_at) - extract(epoch from timestamp '2005-05-24')) / 35000 DESC"))

    else
      relation = relation.order("posts.id DESC")
    end

    relation
  end
end

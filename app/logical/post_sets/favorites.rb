module PostSets
  class Favorites < PostSets::Base
    attr_reader :page, :limit

    def initialize(user, page = 1, limit = CurrentUser.per_page)
      @user = user
      @page = page
      @limit = limit || CurrentUser.per_page
    end

    def public_tag_string
      "fav:#{@user.name}"
    end

    def current_page
      [page.to_i, 1].max
    end

    def posts
      @post_count ||= ::Post.tag_match("fav:#{@user.name} status:any").count_only
      @posts ||= begin
                   favs = ::Favorite.for_user(@user.id).includes(:post).order(created_at: :desc).paginate(page, exact_count: @post_count, limit: @limit)
                   new_opts = {mode: :numbered, per_page: favs.records_per_page, total: @post_count, current_page: current_page}
                   ::YiffyAPI::Paginator::PaginatedArray.new(favs.map {|f| f.post},
                                                             new_opts
                                                           )
                 end
    end

    def api_posts
      _posts = posts
      fill_children(_posts)
      fill_tag_types(_posts)
      _posts
    end

    def is_pattern_search?
      false
    end

    def is_empty_tag?
      false
    end

    def unordered_tag_array
      []
    end

    def tag_array
      []
    end

    def presenter
      ::PostSetPresenters::Post.new(self)
    end
  end
end

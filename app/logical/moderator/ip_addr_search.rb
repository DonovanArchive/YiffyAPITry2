module Moderator
  class IpAddrSearch
    attr_reader :params

    def initialize(params)
      @params = params
    end

    def execute
      with_history = params[:with_history].to_s.truthy?
      if params[:user_id].present?
        search_by_user_id(params[:user_id].split(/,/).map(&:strip), with_history)
      elsif params[:user_name].present?
        search_by_user_name(params[:user_name].split(/,/).map(&:strip), with_history)
      elsif params[:ip_addr].present?
        ip_addrs = params[:ip_addr].split(/,/).map(&:strip)
        if params[:add_ip_mask].to_s.truthy? && ip_addrs.count == 1 && ip_addrs[0].exclude?("/")
          mask = IPAddr.new(ip_addrs[0]).ipv4? ? 24 : 64
          ip_addrs[0] = "#{ip_addrs[0]}/#{mask}"
        end
        search_by_ip_addr(ip_addrs, with_history)
      else
        []
      end
    end

    private

    def add_by(type, value, with_history)
      add_by_ip_addr = lambda do |target, name, ips, klass, ip_field, id_field|
        if ips.size == 1
          target.merge!({ name => klass.where("#{ip_field} <<= ?", ips[0]).group(id_field).count })
        else
          target.merge!({ name => klass.where(ip_field => ips).group(id_field).count })
        end
      end

      add_by_user_id = lambda do |target, name, ids, klass, ip_field, id_field|
        target.merge!({ name => klass.where(id_field => ids).where.not(ip_field => nil).group(ip_field).count })
      end

      method = type == :ip_addr ? add_by_ip_addr : add_by_user_id
      sums = {}
      method.call(sums, :comment, value, ::Comment, :creator_ip_addr, :creator_id)
      method.call(sums, :dmail, value, ::Dmail, :creator_ip_addr, :from_id)
      method.call(sums, :blip, value, ::Blip, :creator_ip_addr, :creator_id)
      method.call(sums, :post_flag, value, ::PostFlag, :creator_ip_addr, :creator_id)
      method.call(sums, :posts, value, ::Post, :uploader_ip_addr, :uploader_id)
      method.call(sums, :last_login, value, ::User, :last_ip_addr, :id)

      if with_history
        method.call(sums, :artist_version, value, ::ArtistVersion, :updater_ip_addr, :updater_id)
        method.call(sums, :note_version, value, ::NoteVersion, :updater_ip_addr, :updater_id)
        method.call(sums, :pool_version, value, ::PoolVersion, :updater_ip_addr, :updater_id)
        method.call(sums, :post_version, value, ::PostVersion, :updater_ip_addr, :updater_id)
        method.call(sums, :wiki_page_version, value, ::WikiPageVersion, :updater_ip_addr, :updater_id)
      end

      sums
    end

    def search_by_ip_addr(ip_addrs, with_history)
      sums = add_by(:ip_addr, ip_addrs, with_history)

      user_ids = sums.map { |_, v| v.map { |k, _| k } }.reduce([]) { |ids, id| ids + id }.uniq
      users = ::User.where(id: user_ids).index_by(&:id)
      { sums: sums, users: users }
    end

    def search_by_user_name(user_names, with_history)
      user_ids = user_names.map { |name| ::User.name_to_id(name) }
      search_by_user_id(user_ids, with_history)
    end

    def search_by_user_id(user_ids, with_history)
      sums = add_by(:user_id, user_ids, with_history)

      ip_addrs = sums.map { |_, v| v.map { |k, _| k } }.reduce([]) { |ids, id| ids + id }.uniq
      { sums: sums, ip_addrs: ip_addrs }
    end
  end
end

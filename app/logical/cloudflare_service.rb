module CloudflareService
  def self.ips(expiry: 24.hours)
    text, code = Cache.fetch("cloudflare_ips", expiry) do
      resp = HTTParty.get("https://api.cloudflare.com/client/v4/ips", YiffyAPI.config.httparty_options)
      [resp.body, resp.code]
    end
    return [] unless code == 200

    json = JSON.parse(text, symbolize_names: true)
    ips = json[:result][:ipv4_cidrs] + json[:result][:ipv6_cidrs]
    ips.map { |ip| IPAddr.new(ip) }
  end
end

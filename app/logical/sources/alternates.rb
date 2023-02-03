module Sources
  module Alternates
    def self.all
      [Alternates::Furaffinity, Alternates::Pixiv]
    end

    def self.find(url, default: Alternates::Null)
      alternate = all.map { |alt| alt.new(url) }.detect(&:match?)
      alternate || default&.new(url)
    end
  end
end

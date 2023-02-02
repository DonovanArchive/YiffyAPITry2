class StatsController < ApplicationController
  respond_to :html, :json

  def index
    client = RedisClient.client
    raw = client.get("e6stats")
    raw ||= StatsUpdater.run!
    @stats = JSON.parse(raw)
    respond_to do |format|
      format.html
      format.json do
        render json: @stats
      end
    end
  end
end

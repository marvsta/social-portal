module Instagram
  # Thin wrapper around the Instagram Graph API.
  # Two-step container/publish flow:
  #   1. POST /{ig-user-id}/media         -> creation_id
  #   2. POST /{ig-user-id}/media_publish -> media_id (the published post)
  # Insights:
  #   GET /{media-id}/insights?metric=...
  #
  # See: https://developers.facebook.com/docs/instagram-platform/content-publishing
  class Client
    GRAPH_VERSION = "v19.0".freeze
    GRAPH_HOST = "https://graph.facebook.com".freeze

    Error = Class.new(StandardError)
    NotConfigured = Class.new(Error)

    def initialize(channel)
      @channel = channel
      raise NotConfigured, "Channel missing access_token" if channel.access_token.blank?
      raise NotConfigured, "Channel missing external_account_id (IG Business Account ID)" if channel.external_account_id.blank?
    end

    def publish_image(image_url:, caption: nil)
      creation = post_path("/#{@channel.external_account_id}/media",
        image_url: image_url, caption: caption)
      creation_id = creation.fetch("id")
      result = post_path("/#{@channel.external_account_id}/media_publish",
        creation_id: creation_id)
      {
        external_id: result.fetch("id"),
        external_url: media_permalink(result.fetch("id"))
      }
    end

    def publish_video(video_url:, caption: nil)
      creation = post_path("/#{@channel.external_account_id}/media",
        media_type: "REELS", video_url: video_url, caption: caption)
      creation_id = creation.fetch("id")
      wait_until_ready(creation_id)
      result = post_path("/#{@channel.external_account_id}/media_publish",
        creation_id: creation_id)
      {
        external_id: result.fetch("id"),
        external_url: media_permalink(result.fetch("id"))
      }
    end

    def fetch_insights(media_id)
      response = get_path("/#{media_id}/insights",
        metric: "impressions,reach,likes,comments,saved,shares")
      data = response.fetch("data", [])
      data.each_with_object({}) do |row, h|
        name = row["name"]
        val  = row.dig("values", 0, "value").to_i
        h[name] = val
      end
    end

    def media_permalink(media_id)
      response = get_path("/#{media_id}", fields: "permalink")
      response["permalink"]
    rescue Error
      nil
    end

    private

    def wait_until_ready(creation_id, timeout: 120)
      start = Time.current
      loop do
        info = get_path("/#{creation_id}", fields: "status_code")
        case info["status_code"]
        when "FINISHED"  then return true
        when "ERROR", "EXPIRED" then raise Error, "Container failed: #{info.inspect}"
        end
        raise Error, "Timed out waiting for container" if (Time.current - start) > timeout
        sleep 5
      end
    end

    def get_path(path, params = {})
      run_request(:get, path, params)
    end

    def post_path(path, params = {})
      run_request(:post, path, params)
    end

    def run_request(verb, path, params)
      url = "#{GRAPH_HOST}/#{GRAPH_VERSION}#{path}"
      params = params.merge(access_token: @channel.access_token)
      response = Faraday.send(verb, url, params)
      body = JSON.parse(response.body) rescue {}
      if response.status >= 400
        message = body.dig("error", "message") || body.to_s
        raise Error, "Instagram API #{response.status}: #{message}"
      end
      body
    end
  end
end

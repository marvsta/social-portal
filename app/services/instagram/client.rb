module Instagram
  # Thin wrapper around the Instagram Graph API.
  # Two-step container/publish flow:
  #   1. POST /{ig-user-id}/media         -> creation_id
  #   2. POST /{ig-user-id}/media_publish -> media_id (the published post)
  # Carousels create one container per item (is_carousel_item), then a
  # CAROUSEL container referencing the children, then publish that.
  # Insights:
  #   GET /{media-id}/insights?metric=...
  #
  # See: https://developers.facebook.com/docs/instagram-platform/content-publishing
  class Client
    GRAPH_VERSION = "v19.0".freeze
    GRAPH_HOST = "https://graph.facebook.com".freeze
    MAX_CAROUSEL_ITEMS = 10 # Instagram's hard limit

    Error = Class.new(StandardError)
    NotConfigured = Class.new(Error)
    # Meta 5xx / rate limits / network hiccups — safe to retry the publish.
    TransientError = Class.new(Error)

    def initialize(channel)
      @channel = channel
      raise NotConfigured, "Channel missing access_token" if channel.access_token.blank?
      raise NotConfigured, "Channel missing external_account_id (IG Business Account ID)" if channel.external_account_id.blank?
    end

    def publish_image(image_url:, caption: nil)
      creation = post_path("/#{@channel.external_account_id}/media",
        image_url: image_url, caption: caption)
      publish_container(creation.fetch("id"))
    end

    def publish_video(video_url:, caption: nil)
      creation = post_path("/#{@channel.external_account_id}/media",
        media_type: "REELS", video_url: video_url, caption: caption)
      creation_id = creation.fetch("id")
      wait_until_ready(creation_id)
      publish_container(creation_id)
    end

    # Stories take a single image or video and no caption; they expire after
    # 24 hours (the permalink may come back nil once expired).
    def publish_story(url:, video: false)
      params = video ? { media_type: "STORIES", video_url: url } : { media_type: "STORIES", image_url: url }
      creation = post_path("/#{@channel.external_account_id}/media", **params)
      creation_id = creation.fetch("id")
      wait_until_ready(creation_id) if video
      publish_container(creation_id)
    end

    # items: [{ url:, video: true/false }, ...] — 2..10 of them.
    def publish_carousel(items:, caption: nil)
      raise Error, "A carousel needs 2–#{MAX_CAROUSEL_ITEMS} items" unless items.size.between?(2, MAX_CAROUSEL_ITEMS)

      child_ids = items.map do |item|
        params = if item[:video]
          { media_type: "VIDEO", video_url: item[:url], is_carousel_item: true }
        else
          { image_url: item[:url], is_carousel_item: true }
        end
        creation = post_path("/#{@channel.external_account_id}/media", **params)
        creation.fetch("id")
      end
      # Video children process asynchronously; image children are ready at once.
      items.each_with_index { |item, i| wait_until_ready(child_ids[i]) if item[:video] }

      creation = post_path("/#{@channel.external_account_id}/media",
        media_type: "CAROUSEL", children: child_ids.join(","), caption: caption)
      creation_id = creation.fetch("id")
      wait_until_ready(creation_id)
      publish_container(creation_id)
    end

    # Valid metric names differ by media product type: reels take "plays"
    # but not "impressions"; stories take "replies". Callers pass the set
    # matching what was published (see Metrics::FetchInstagramJob).
    DEFAULT_INSIGHT_METRICS = "impressions,reach,likes,comments,saved,shares".freeze

    def fetch_insights(media_id, metrics: DEFAULT_INSIGHT_METRICS)
      response = get_path("/#{media_id}/insights", metric: metrics)
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

    def publish_container(creation_id)
      result = post_path("/#{@channel.external_account_id}/media_publish",
        creation_id: creation_id)
      {
        external_id: result.fetch("id"),
        external_url: media_permalink(result.fetch("id"))
      }
    end

    def wait_until_ready(creation_id, timeout: 120)
      start = Time.current
      interval = 3
      loop do
        info = get_path("/#{creation_id}", fields: "status_code")
        case info["status_code"]
        when "FINISHED"  then return true
        when "ERROR", "EXPIRED" then raise Error, "Container failed: #{info.inspect}"
        end
        raise TransientError, "Timed out waiting for container #{creation_id}" if (Time.current - start) > timeout
        sleep interval
        interval = [ interval * 2, 15 ].min
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
      # Token goes in a header, not the query string, so it can't leak into
      # request logs on either end.
      response = Faraday.send(verb, url, params, { "Authorization" => "Bearer #{@channel.access_token}" })
      body = JSON.parse(response.body) rescue {}
      if response.status == 429 || response.status >= 500
        message = body.dig("error", "message") || body.to_s
        raise TransientError, "Instagram API #{response.status}: #{message}"
      elsif response.status >= 400
        message = body.dig("error", "message") || body.to_s
        raise Error, "Instagram API #{response.status}: #{message}"
      end
      body
    rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
      raise TransientError, "Instagram API unreachable: #{e.message}"
    end
  end
end

module Posts
  class PublishJob < ApplicationJob
    queue_as :default

    def perform(post_id, force: false)
      post = Post.find_by(id: post_id)
      return if post.nil?
      return unless force || %w[scheduled approved].include?(post.status)

      post.update!(status: "publishing")
      success = false
      any_failure = false

      post.channel_posts.where.not(status: "published").each do |cp|
        if publish_channel(cp, post)
          success = true
        else
          any_failure = true
        end
      end

      post.update!(status: resolve_status(post, success, any_failure))

      if post.channel_posts.published.any?
        Metrics::FetchInstagramJob.set(wait: 30.minutes).perform_later(post.id)
      end
    end

    private

    def publish_channel(channel_post, post)
      channel = channel_post.social_channel
      channel_post.mark_publishing!

      case channel.platform
      when "instagram"
        publish_to_instagram(channel_post, post)
      else
        # Other platforms not wired up — mark skipped with a clear note.
        channel_post.update!(status: "skipped", last_error: "#{channel.platform_label} auto-publish not implemented yet. Publish manually.")
        false
      end
    rescue Instagram::Client::NotConfigured => e
      channel_post.mark_failed!("Instagram not configured: #{e.message}")
      false
    rescue Instagram::Client::Error => e
      channel_post.mark_failed!(e.message)
      false
    rescue StandardError => e
      Rails.logger.error("PublishJob failed: #{e.class}: #{e.message}")
      channel_post.mark_failed!("Unexpected: #{e.message}")
      false
    end

    def publish_to_instagram(channel_post, post)
      channel = channel_post.social_channel
      caption = [ post.caption, post.hashtags ].compact_blank.join("\n\n")

      blob = post.media.first
      raise Instagram::Client::Error, "Instagram requires at least one image or video" if blob.nil?

      url = public_blob_url(blob)
      raise Instagram::Client::Error, "Cannot publish without a public media URL. Configure your storage to expose a public URL." if url.blank?

      client = Instagram::Client.new(channel)
      result = if blob.video?
        client.publish_video(video_url: url, caption: caption)
      else
        client.publish_image(image_url: url, caption: caption)
      end
      channel_post.mark_published!(external_id: result[:external_id], external_url: result[:external_url])
      true
    end

    def public_blob_url(blob)
      Rails.application.routes.url_helpers.rails_blob_url(blob, host: ENV.fetch("APP_HOST", "http://localhost:3000"))
    rescue StandardError
      nil
    end

    def resolve_status(post, success, any_failure)
      remaining = post.channel_posts.where(status: %w[pending publishing])
      remaining.update_all(status: "failed", last_error: "Job ended without publishing")
      total_published = post.channel_posts.published.count
      total = post.channel_posts.count
      return "published" if total_published == total
      return "partial_failure" if total_published.positive?
      "failed"
    end
  end
end

module Posts
  class PublishJob < ApplicationJob
    queue_as :default

    # Channel posts a run is allowed to pick up. "publishing" is deliberately
    # excluded: it means another run has claimed the row, which is what makes
    # concurrent runs (double-click, scheduled job racing "publish now") safe.
    CLAIMABLE_STATUSES = %w[pending failed skipped].freeze

    # Transient Meta errors (5xx, rate limits, network) re-run the whole job;
    # already-published channel posts are skipped on re-entry, so only the
    # channels that bounced are retried.
    retry_on Instagram::Client::TransientError, wait: :polynomially_longer, attempts: 4 do |job, error|
      post = Post.find_by(id: job.arguments.first)
      next if post.nil?
      post.with_lock do
        post.channel_posts.where(status: %w[publishing pending])
            .update_all(status: "failed", last_error: "Gave up after retries: #{error.message}")
        post.update!(status: Posts::PublishJob.aggregate_status(post))
      end
    end

    # scheduled_for pins the job to the scheduled_at it was enqueued for. If
    # the post has been rescheduled since (a fresh job carries the new time),
    # this job is stale and must not fire.
    def perform(post_id, force: false, scheduled_for: nil)
      post = Post.find_by(id: post_id)
      return if post.nil?

      claimed = claim_channel_posts(post, force: force, scheduled_for: scheduled_for)
      return if claimed.empty?

      transient = nil
      claimed.each do |cp|
        publish_channel(cp, post)
      rescue Instagram::Client::TransientError => e
        # Put the row back so the retry can claim it, finish the other
        # channels first, then re-raise to trigger retry_on.
        cp.update!(status: "pending", last_error: e.message)
        transient = e
      end
      raise transient if transient

      finalize(post)
    end

    def self.aggregate_status(post)
      counts = post.channel_posts.group(:status).count
      published = counts["published"].to_i
      failed = counts["failed"].to_i
      if published.positive?
        failed.positive? ? "partial_failure" : "published"
      else
        # Nothing auto-published. Skipped-only posts land here too: no channel
        # succeeded, so the publish attempt failed (each row says why).
        "failed"
      end
    end

    private

    def claim_channel_posts(post, force:, scheduled_for:)
      post.with_lock do
        next [] unless force || %w[scheduled publishing].include?(post.status)
        # Stale check: the post was rescheduled after this job was enqueued —
        # a fresh job carries the new time.
        next [] if scheduled_for.present? && post.scheduled_at&.to_i != scheduled_for.to_i

        claimed = post.channel_posts.where(status: CLAIMABLE_STATUSES).to_a
        next [] if claimed.empty?

        post.update!(status: "publishing")
        claimed.each(&:mark_publishing!)
        claimed
      end
    end

    def finalize(post)
      post.with_lock do
        # Anything still "publishing" belongs to this run and never resolved.
        post.channel_posts.where(status: "publishing")
            .update_all(status: "failed", last_error: "Job ended without publishing")
        post.update!(status: self.class.aggregate_status(post))
      end

      if post.channel_posts.published.any?
        Metrics::FetchInstagramJob.set(wait: 30.minutes).perform_later(post.id)
      end
    end

    def publish_channel(channel_post, post)
      channel = channel_post.social_channel

      case channel.platform
      when "instagram"
        publish_to_instagram(channel_post, post)
      else
        # Other platforms not wired up — mark skipped with a clear note.
        channel_post.update!(status: "skipped", last_error: "#{channel.platform_label} auto-publish not implemented yet. Publish manually.")
      end
    rescue Instagram::Client::TransientError
      raise # handled by perform / retry_on
    rescue Instagram::Client::NotConfigured => e
      channel_post.mark_failed!("Instagram not configured: #{e.message}")
    rescue Instagram::Client::Error => e
      channel_post.mark_failed!(e.message)
    rescue StandardError => e
      Rails.logger.error("PublishJob failed: #{e.class}: #{e.message}")
      channel_post.mark_failed!("Unexpected: #{e.message}")
    end

    def publish_to_instagram(channel_post, post)
      channel = channel_post.social_channel
      caption = [ post.caption, post.hashtags ].compact_blank.join("\n\n")

      blobs = post.media.to_a
      raise Instagram::Client::Error, "Instagram requires at least one image or video" if blobs.empty?

      items = blobs.first(Instagram::Client::MAX_CAROUSEL_ITEMS).map do |blob|
        { url: public_blob_url(blob), video: blob.video? }
      end

      client = Instagram::Client.new(channel)
      result = if items.size > 1
        client.publish_carousel(items: items, caption: caption)
      elsif items.first[:video]
        client.publish_video(video_url: items.first[:url], caption: caption)
      else
        client.publish_image(image_url: items.first[:url], caption: caption)
      end
      channel_post.mark_published!(external_id: result[:external_id], external_url: result[:external_url])
    end

    def public_blob_url(blob)
      host = ENV["APP_HOST"].presence
      if host.blank?
        raise Instagram::Client::Error,
          "No public media URL: set APP_HOST to this app's public URL (a tunnel like ngrok in development) so Instagram can fetch the media."
      end
      Rails.application.routes.url_helpers.rails_blob_url(blob, host: host)
    end
  end
end

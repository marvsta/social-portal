module Metrics
  class FetchInstagramJob < ApplicationJob
    queue_as :default

    def perform(post_id)
      post = Post.find_by(id: post_id)
      return if post.nil?

      post.channel_posts.published.includes(:social_channel).each do |cp|
        next unless cp.social_channel.platform == "instagram"
        next if cp.external_id.blank?
        capture_for(cp)
      end
    end

    def capture_for(channel_post)
      client = Instagram::Client.new(channel_post.social_channel)
      data = client.fetch_insights(channel_post.external_id)
      reach       = data["reach"].to_i
      impressions = data["impressions"].to_i
      likes       = data["likes"].to_i
      comments    = data["comments"].to_i
      saves       = data["saved"].to_i
      shares      = data["shares"].to_i
      total_eng   = likes + comments + saves + shares
      rate        = reach.positive? ? (total_eng.to_f / reach * 100).round(2) : 0
      channel_post.post_metrics.create!(
        likes: likes, comments: comments, shares: shares, saves: saves,
        reach: reach, impressions: impressions, video_views: 0,
        engagement_rate: rate, captured_at: Time.current
      )
    rescue Instagram::Client::NotConfigured, Instagram::Client::Error => e
      Rails.logger.warn("FetchInstagramJob: #{e.message}")
    end
  end
end

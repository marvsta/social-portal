class PostMetricsController < ApplicationController
  include CompanyScoped

  def index
    @post = @company.posts.find(params[:post_id])
    @channel_posts = @post.channel_posts.includes(:social_channel, :post_metrics)
    @timeseries = build_timeseries(@channel_posts)
    @latest_totals = build_latest_totals(@channel_posts)
  end

  private

  def build_latest_totals(channel_posts)
    channel_posts.map do |cp|
      m = cp.latest_metric
      {
        channel: cp.social_channel,
        likes: m&.likes.to_i,
        comments: m&.comments.to_i,
        shares: m&.shares.to_i,
        saves: m&.saves.to_i,
        reach: m&.reach.to_i,
        impressions: m&.impressions.to_i,
        engagement_rate: m&.engagement_rate.to_f,
        captured_at: m&.captured_at
      }
    end
  end

  def build_timeseries(channel_posts)
    channel_posts.map do |cp|
      points = cp.post_metrics.order(:captured_at).pluck(:captured_at, :likes, :comments, :saves, :shares).map do |t, l, c, sv, sh|
        { x: t.iso8601, y: l.to_i + c.to_i + sv.to_i + sh.to_i }
      end
      {
        label: "#{cp.social_channel.platform_label} · #{cp.social_channel.display}",
        color: cp.social_channel.platform_color,
        data: points
      }
    end
  end
end

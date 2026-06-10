class DashboardsController < ApplicationController
  include CompanyScoped

  def show
    @range = (params[:days].presence&.to_i || 30).clamp(7, 180)
    range_start = @range.days.ago

    @published_posts = @company.posts.published.where("updated_at >= ?", range_start)
    @published_count = @published_posts.count
    @scheduled_count = @company.posts.where(status: %w[scheduled approved pending_review]).count
    @draft_count = @company.posts.where(status: "draft").count

    metrics = PostMetric.joins(channel_post: { post: :company })
      .where(companies: { id: @company.id })
      .where("post_metrics.captured_at >= ?", range_start)

    @total_reach = metrics.sum(:reach)
    @total_impressions = metrics.sum(:impressions)
    @total_engagement = metrics.sum("post_metrics.likes + post_metrics.comments + post_metrics.shares + post_metrics.saves")
    avg_rate = metrics.average(:engagement_rate)
    @avg_engagement_rate = avg_rate.to_f.round(2)

    @engagement_by_day = metrics
      .group(Arel.sql("DATE(post_metrics.captured_at)"))
      .pluck(Arel.sql("DATE(post_metrics.captured_at)"), Arel.sql("SUM(post_metrics.likes + post_metrics.comments + post_metrics.shares + post_metrics.saves)"))
      .sort_by(&:first)

    @top_posts = @company.posts.published.includes(channel_posts: :post_metrics)
      .sort_by { |p| -p.total_engagement }.first(5)

    @engagement_by_platform = @company.social_channels.includes(channel_posts: :post_metrics).map do |c|
      eng = c.channel_posts.flat_map { |cp| [ cp.latest_metric&.total_engagement.to_i ] }.sum
      { platform: c.platform_label, color: c.platform_color, engagement: eng }
    end.reject { |row| row[:engagement].zero? }
  end
end

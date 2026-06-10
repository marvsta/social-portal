class CalendarsController < ApplicationController
  include CompanyScoped

  def show
    Time.use_zone(@company.timezone) do
      range_from = (Date.current - 60).beginning_of_day
      range_to = (Date.current + 90).end_of_day
      @posts = @company.posts.includes(:social_channels, channel_posts: :social_channel)
        .where("scheduled_at IS NOT NULL")
        .where(scheduled_at: range_from..range_to)
        .order(:scheduled_at)
      @events = @posts.map { |p| calendar_event_for(p) }
      @upcoming = @company.posts.upcoming.where("scheduled_at >= ?", Time.current).limit(8)
      @recent_published = @company.posts.published.order(updated_at: :desc).limit(5)
    end
  end

  private

  def calendar_event_for(post)
    {
      id: post.id,
      title: post.title.presence || post.caption.to_s.truncate(60),
      start: post.scheduled_at&.iso8601,
      url: company_post_path(@company, post),
      backgroundColor: post.status_color,
      borderColor: post.status_color,
      extendedProps: {
        status: post.status_label,
        channels: post.social_channels.map(&:platform_label).join(", ")
      }
    }
  end
end

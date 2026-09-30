class PostsController < ApplicationController
  include CompanyScoped

  before_action :require_publisher, only: %i[new create edit update submit_for_review schedule publish_now generate_caption generate_image]
  # Deleting is reserved for admins/owners; editors can only edit their content.
  before_action :require_manager, only: %i[approve destroy]
  before_action :load_post, only: %i[show edit update destroy submit_for_review approve schedule publish_now]

  def index
    @status = params[:status].presence
    scope = @company.posts.includes(:author, :social_channels).order(scheduled_at: :desc, created_at: :desc)
    scope = scope.where(status: @status) if @status && Post::STATUSES.include?(@status)
    @posts = scope
  end

  def new
    @post = @company.posts.build(scheduled_at: parse_scheduled_at)
    @channels = @company.social_channels.active
  end

  def create
    @post = @company.posts.build(post_params)
    @post.author = current_user
    @post.social_channel_ids = Array(params.dig(:post, :social_channel_ids)).reject(&:blank?)

    if @post.save
      redirect_to company_post_path(@company, @post), notice: "Post saved as #{@post.status_label.downcase}."
    else
      @channels = @company.social_channels.active
      render :new, status: :unprocessable_content
    end
  end

  def show
    @channel_posts = @post.channel_posts.includes(:social_channel, :post_metrics)
  end

  def edit
    @channels = @company.social_channels.active
  end

  def update
    was_approved = %w[approved scheduled].include?(@post.status)
    was_scheduled_for = @post.scheduled_at

    @post.assign_attributes(post_params)
    if params.dig(:post, :social_channel_ids)
      requested = Array(params[:post][:social_channel_ids]).reject(&:blank?).map(&:to_i)
      # Channels that already published keep their ChannelPost no matter what —
      # dropping it would destroy the publishing record and its metric history.
      locked = @post.channel_posts.where(status: "published").pluck(:social_channel_id)
      @post.social_channel_ids = (requested | locked)
    end

    if @post.save
      notice = "Post updated."
      if was_approved && @post.status == "pending_review"
        notice = "Post updated. Content changed after approval, so it's back in review."
      elsif @post.status == "scheduled" && @post.scheduled_at != was_scheduled_for
        # Rescheduled: enqueue a job pinned to the new time. The job enqueued
        # for the old time carries the old scheduled_for and won't fire.
        enqueue_publish_job
        notice = "Post rescheduled for #{l(@post.scheduled_at, format: :long)}."
      end
      redirect_to company_post_path(@company, @post), notice: notice
    else
      @channels = @company.social_channels.active
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @post.destroy
    redirect_to company_posts_path(@company), notice: "Post deleted."
  end

  def submit_for_review
    @post.submit_for_review!
    redirect_to company_post_path(@company, @post), notice: "Submitted for review."
  end

  def approve
    @post.approve!(current_user)
    redirect_to company_post_path(@company, @post), notice: "Approved. Schedule it to queue for publishing."
  end

  def schedule
    if @post.scheduled_at.blank?
      redirect_to edit_company_post_path(@company, @post), alert: "Set a schedule date first."
      return
    end
    if @post.scheduled_at < 1.minute.ago
      redirect_to edit_company_post_path(@company, @post),
        alert: "The schedule date is in the past. Pick a new date, or use Publish now."
      return
    end
    @post.schedule!
    @post.channel_posts.where(status: %w[skipped failed]).update_all(status: "pending")
    enqueue_publish_job
    redirect_to company_post_path(@company, @post), notice: "Scheduled for #{l(@post.scheduled_at, format: :long)}."
  end

  def publish_now
    @post.update!(status: "publishing")
    @post.channel_posts.where(status: %w[skipped failed]).update_all(status: "pending")
    Posts::PublishJob.perform_later(@post.id, force: true)
    redirect_to company_post_path(@company, @post), notice: "Publishing now."
  end

  def generate_caption
    result = Ai::CaptionGenerator.new(
      company: @company,
      instructions: params[:instructions],
      platforms: Array(params[:platforms]),
      title: params[:title]
    ).generate
    render json: result
  rescue Ai::NotConfigured => e
    render json: { error: "AI isn't configured yet — #{e.message}. Set the key and restart the server, or pick a different provider in AI settings." }, status: :service_unavailable
  rescue Ai::Error => e
    render json: { error: e.message }, status: :unprocessable_content
  end

  def generate_image
    result = Ai::ImageGenerator.new(
      company: @company,
      mode: params[:mode],
      description: params[:description],
      caption: params[:caption],
      title: params[:title],
      size: params[:size],
      image: params[:image]
    ).generate

    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(result[:png]),
      filename: "ai-image-#{Time.current.strftime('%Y%m%d-%H%M%S')}.png",
      content_type: "image/png"
    )
    render json: {
      signed_id: blob.signed_id,
      url: rails_blob_path(blob, only_path: true),
      prompt: result[:prompt]
    }
  rescue Ai::NotConfigured => e
    render json: { error: "AI images aren't configured yet — #{e.message}. Set the key and restart the server." }, status: :service_unavailable
  rescue Ai::Error => e
    render json: { error: e.message }, status: :unprocessable_content
  end

  private

  # Every scheduled job is pinned to the scheduled_at it was created for, so
  # rescheduling doesn't need to cancel the old job — it just goes stale.
  def enqueue_publish_job
    if @post.scheduled_at <= 1.minute.from_now
      Posts::PublishJob.perform_later(@post.id, scheduled_for: @post.scheduled_at)
    else
      Posts::PublishJob.set(wait_until: @post.scheduled_at).perform_later(@post.id, scheduled_for: @post.scheduled_at)
    end
  end

  def load_post
    @post = @company.posts.find(params[:id])
  end

  def post_params
    # Status is intentionally NOT permitted here: it is only ever changed through
    # the workflow actions (submit_for_review/approve/schedule/publish_now), so a
    # form cannot jump a post straight to "approved" or "published".
    params.require(:post).permit(:title, :caption, :hashtags, :scheduled_at, :review_notes, media: [])
  end

  def parse_scheduled_at
    return nil if params[:scheduled_at].blank?
    Time.zone.parse(params[:scheduled_at])
  rescue ArgumentError
    nil
  end
end

class PostsController < ApplicationController
  include CompanyScoped

  before_action :require_publisher, only: %i[new create edit update destroy submit_for_review schedule publish_now]
  before_action :require_manager, only: %i[approve]
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
    @post.assign_attributes(post_params)
    if params.dig(:post, :social_channel_ids)
      @post.social_channel_ids = Array(params[:post][:social_channel_ids]).reject(&:blank?)
    end
    if @post.save
      redirect_to company_post_path(@company, @post), notice: "Post updated."
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
    @post.update!(status: "scheduled")
    @post.channel_posts.where(status: "skipped").update_all(status: "pending")
    if @post.scheduled_at <= 1.minute.from_now
      Posts::PublishJob.perform_later(@post.id)
    else
      Posts::PublishJob.set(wait_until: @post.scheduled_at).perform_later(@post.id)
    end
    redirect_to company_post_path(@company, @post), notice: "Scheduled for #{l(@post.scheduled_at, format: :long)}."
  end

  def publish_now
    @post.update!(status: "publishing")
    @post.channel_posts.where(status: %w[pending failed]).update_all(status: "pending")
    Posts::PublishJob.perform_later(@post.id, force: true)
    redirect_to company_post_path(@company, @post), notice: "Publishing now."
  end

  private

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

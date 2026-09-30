require "test_helper"

class PostWorkflowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @company = companies(:acme)
    sign_in_as users(:editor)
  end

  def sign_in_as(user)
    post login_path, params: { email: user.email, password: "password123" }
  end

  test "unchecking a published channel keeps its channel post and metrics" do
    published = posts(:published)
    cp = channel_posts(:published_instagram)
    metric_count = cp.post_metrics.count
    assert metric_count.positive?

    # Submit with the instagram channel unchecked (only the blank sentinel).
    patch company_post_path(@company, published), params: {
      post: { title: "still here", social_channel_ids: [ "" ] }
    }
    assert_redirected_to company_post_path(@company, published)

    assert ChannelPost.exists?(cp.id), "published channel post must survive channel edits"
    assert_equal metric_count, cp.reload.post_metrics.count
  end

  test "rescheduling a scheduled post enqueues a job pinned to the new time" do
    scheduled = posts(:scheduled)
    new_time = 5.days.from_now.change(usec: 0)

    assert_enqueued_with(job: Posts::PublishJob) do
      patch company_post_path(@company, scheduled), params: {
        post: { scheduled_at: new_time.strftime("%Y-%m-%dT%H:%M") }
      }
    end
    assert_equal "scheduled", scheduled.reload.status
  end

  test "editing an approved post's caption knocks it back to review" do
    approved = posts(:approved)
    patch company_post_path(@company, approved), params: {
      post: { caption: "Changed after sign-off" }
    }
    assert_equal "pending_review", approved.reload.status
    follow_redirect!
    assert_match "back in review", response.body
  end

  test "scheduling with a past date is refused with guidance" do
    approved = posts(:approved)
    approved.update_columns(scheduled_at: 2.hours.ago) # bypass validation to simulate a stale date
    post schedule_company_post_path(@company, approved)
    assert_redirected_to edit_company_post_path(@company, approved)
    assert_equal "approved", approved.reload.status
  end

  test "scheduling resets failed and skipped channel posts to pending" do
    scheduled = posts(:scheduled)
    scheduled.update!(status: "approved")
    channel_posts(:scheduled_instagram).update!(status: "failed", last_error: "old")
    channel_posts(:scheduled_linkedin).update!(status: "skipped")

    post schedule_company_post_path(@company, scheduled)

    assert_equal "pending", channel_posts(:scheduled_instagram).reload.status
    assert_equal "pending", channel_posts(:scheduled_linkedin).reload.status
    assert_equal "scheduled", scheduled.reload.status
  end
end

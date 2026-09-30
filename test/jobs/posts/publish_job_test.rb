require "test_helper"

module Posts
  class PublishJobTest < ActiveJob::TestCase
    setup do
      @post = posts(:scheduled)
      @instagram_cp = channel_posts(:scheduled_instagram)
      @linkedin_cp = channel_posts(:scheduled_linkedin)
      ENV["APP_HOST"] = "https://example.test"
    end

    teardown { ENV.delete("APP_HOST") }

    FakeClient = Struct.new(:result) do
      def publish_image(**) = result
      def publish_video(**) = result
      def publish_carousel(**) = result
    end

    def attach_image(post)
      status = post.status
      post.media.attach(
        io: StringIO.new("fake-png"), filename: "a.png", content_type: "image/png"
      )
      # Attaching media to an approved/scheduled post reverts it to review
      # (that's covered by PostTest); restore the state under test here.
      post.update_columns(status: status)
    end

    def run_with_fake_instagram(result: { external_id: "999", external_url: "https://ig/p" }, **opts)
      Instagram::Client.stub :new, FakeClient.new(result) do
        PublishJob.perform_now(@post.id, **opts)
      end
    end

    test "publishes instagram, skips linkedin, and the skip doesn't drag the post to partial_failure" do
      attach_image(@post)
      run_with_fake_instagram

      assert_equal "published", @instagram_cp.reload.status
      assert_equal "999", @instagram_cp.external_id
      assert_equal "skipped", @linkedin_cp.reload.status
      assert_equal "published", @post.reload.status
      assert_enqueued_with(job: Metrics::FetchInstagramJob)
    end

    test "a failed publish with nothing published resolves the post to failed" do
      attach_image(@post)
      failing = Object.new
      def failing.publish_image(**) = raise Instagram::Client::Error, "boom"
      # Only instagram is attempted for real; make it fail.
      Instagram::Client.stub :new, failing do
        PublishJob.perform_now(@post.id)
      end
      assert_equal "failed", @instagram_cp.reload.status
      assert_equal "failed", @post.reload.status
      assert_match "boom", @instagram_cp.last_error
    end

    test "does not run on a post knocked back to pending_review (stale scheduled job)" do
      @post.update!(status: "pending_review", approved_by: nil, approved_at: nil)
      run_with_fake_instagram
      assert_equal "pending", @instagram_cp.reload.status
      assert_equal "pending_review", @post.reload.status
    end

    test "does not run when the post was rescheduled after enqueue" do
      stale_time = @post.scheduled_at
      @post.update!(scheduled_at: stale_time + 3.days)
      run_with_fake_instagram(scheduled_for: stale_time)
      assert_equal "pending", @instagram_cp.reload.status
      assert_equal "scheduled", @post.reload.status
    end

    test "runs when scheduled_for matches the current schedule" do
      attach_image(@post)
      run_with_fake_instagram(scheduled_for: @post.scheduled_at)
      assert_equal "published", @instagram_cp.reload.status, "last_error: #{@instagram_cp.last_error.inspect}"
    end

    test "claims nothing while another run holds the channel posts" do
      @post.channel_posts.update_all(status: "publishing")
      run_with_fake_instagram(force: true)
      # Untouched: still publishing (owned by the other run), no double publish.
      assert_equal "publishing", @instagram_cp.reload.status
      assert_equal "scheduled", @post.reload.status
    end

    test "already published channel posts are never re-published" do
      @instagram_cp.update!(status: "published", external_id: "111")
      @linkedin_cp.update!(status: "skipped")
      attach_image(@post)
      run_with_fake_instagram(force: true) # re-claims only the linkedin skip
      assert_equal "111", @instagram_cp.reload.external_id
      assert_equal "skipped", @linkedin_cp.reload.status
    end

    test "fails with a clear error when APP_HOST is missing" do
      ENV.delete("APP_HOST")
      attach_image(@post)
      run_with_fake_instagram
      assert_equal "failed", @instagram_cp.reload.status
      assert_match "APP_HOST", @instagram_cp.last_error
    end

    test "transient instagram errors put the channel back to pending and retry the job" do
      attach_image(@post)
      flaky = Object.new
      def flaky.publish_image(**) = raise Instagram::Client::TransientError, "IG 500"
      Instagram::Client.stub :new, flaky do
        PublishJob.perform_now(@post.id)
      end
      # retry_on intercepts the raise and re-enqueues instead of bubbling.
      assert_enqueued_with(job: PublishJob)
      assert_equal "pending", @instagram_cp.reload.status
      assert_match "IG 500", @instagram_cp.last_error
    end

    test "aggregate_status treats skips as neutral but all-skipped as failed" do
      @instagram_cp.update!(status: "skipped")
      @linkedin_cp.update!(status: "skipped")
      assert_equal "failed", PublishJob.aggregate_status(@post)

      @instagram_cp.update!(status: "published")
      assert_equal "published", PublishJob.aggregate_status(@post)

      @linkedin_cp.update!(status: "failed")
      assert_equal "partial_failure", PublishJob.aggregate_status(@post)
    end

    test "multiple images publish as a carousel" do
      attach_image(@post)
      attach_image(@post)
      calls = []
      recorder = Object.new
      recorder.define_singleton_method(:publish_carousel) do |items:, caption:|
        calls << items.size
        { external_id: "car1", external_url: nil }
      end
      Instagram::Client.stub :new, recorder do
        PublishJob.perform_now(@post.id)
      end
      assert_equal [ 2 ], calls
      assert_equal "published", @instagram_cp.reload.status
    end
  end
end

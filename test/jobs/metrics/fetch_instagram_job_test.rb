require "test_helper"

module Metrics
  class FetchInstagramJobTest < ActiveJob::TestCase
    setup do
      @post = posts(:published)
      @cp = channel_posts(:published_instagram)
    end

    FakeInsights = Struct.new(:data) do
      attr_reader :requested_metrics
      def fetch_insights(_media_id, metrics:)
        @requested_metrics = metrics
        data
      end
    end

    test "reels request plays and store them as video_views" do
      @post.update_columns(post_type: "reel")
      fake = FakeInsights.new({ "reach" => 100, "likes" => 5, "comments" => 1, "saved" => 2, "shares" => 1, "plays" => 400 })
      Instagram::Client.stub :new, fake do
        FetchInstagramJob.perform_now(@post.id)
      end
      assert_includes fake.requested_metrics, "plays"
      refute_includes fake.requested_metrics, "impressions"
      metric = @cp.post_metrics.order(:captured_at).last
      assert_equal 400, metric.video_views
      assert_equal 5, metric.likes
    end

    test "stories request replies and store them as comments" do
      @post.update_columns(post_type: "story")
      fake = FakeInsights.new({ "reach" => 80, "impressions" => 90, "replies" => 3 })
      Instagram::Client.stub :new, fake do
        FetchInstagramJob.perform_now(@post.id)
      end
      assert_includes fake.requested_metrics, "replies"
      metric = @cp.post_metrics.order(:captured_at).last
      assert_equal 3, metric.comments
      assert_equal 90, metric.impressions
    end

    test "feed posts keep the default metric set" do
      fake = FakeInsights.new({ "reach" => 50, "impressions" => 60, "likes" => 4 })
      Instagram::Client.stub :new, fake do
        FetchInstagramJob.perform_now(@post.id)
      end
      assert_includes fake.requested_metrics, "impressions"
      refute_includes fake.requested_metrics, "plays"
    end
  end
end

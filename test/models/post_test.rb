require "test_helper"

class PostTest < ActiveSupport::TestCase
  test "rejects a past scheduled_at while the post hasn't published yet" do
    post = posts(:draft)
    post.scheduled_at = 1.hour.ago
    assert_not post.valid?
    assert_includes post.errors[:scheduled_at], "must be in the future"
  end

  test "allows editing a published post that carries its past scheduled_at" do
    post = posts(:published)
    post.title = "New title"
    assert post.valid?
  end

  test "schedule! raises without a scheduled_at" do
    post = posts(:draft)
    assert_raises(ArgumentError) { post.schedule! }
  end

  test "editing the caption of an approved post sends it back to review" do
    post = posts(:approved)
    post.update!(caption: "Something totally different")
    assert_equal "pending_review", post.status
    assert_nil post.approved_by
    assert_nil post.approved_at
  end

  test "editing the caption of a scheduled post sends it back to review" do
    post = posts(:scheduled)
    post.update!(caption: "Sneaky post-approval edit")
    assert_equal "pending_review", post.status
  end

  test "rescheduling alone does not drop the approval" do
    post = posts(:scheduled)
    post.update!(scheduled_at: 3.days.from_now)
    assert_equal "scheduled", post.status
    assert_equal users(:owner), post.approved_by
  end

  test "workflow status transitions are exempt from the approval revert" do
    post = posts(:approved)
    post.schedule!
    assert_equal "scheduled", post.status
  end

  test "attaching media to a scheduled post sends it back to review" do
    post = posts(:scheduled)
    post.media.attach(io: StringIO.new("x"), filename: "a.png", content_type: "image/png")
    assert_equal "pending_review", post.reload.status
  end

  test "editing a draft never touches review state" do
    post = posts(:draft)
    post.update!(caption: "Reworded draft")
    assert_equal "draft", post.status
  end

  test "stories don't require a caption" do
    post = posts(:draft)
    post.post_type = "story"
    post.caption = nil
    assert post.valid?
    post.post_type = "post"
    assert_not post.valid?
  end

  test "changing the post type after approval sends it back to review" do
    post = posts(:approved)
    post.update!(post_type: "story")
    assert_equal "pending_review", post.status
  end

  test "publish_blockers enforce type/media rules only when instagram is targeted" do
    post = posts(:scheduled) # targets instagram + linkedin, no media
    assert_includes post.publish_blockers.join, "at least one image or video"

    post.media.attach(io: StringIO.new("img"), filename: "a.png", content_type: "image/png")
    assert_empty post.publish_blockers

    post.post_type = "reel"
    assert_includes post.publish_blockers.join, "exactly one video"

    post.post_type = "story"
    assert_empty post.publish_blockers
    post.media.attach(io: StringIO.new("img2"), filename: "b.png", content_type: "image/png")
    assert_includes post.publish_blockers.join, "exactly one image or video"

    no_ig = posts(:draft) # no channels at all
    assert_empty no_ig.publish_blockers
  end

  test "display_title survives a caption-less story" do
    post = Post.new(post_type: "story", id: 7)
    assert_equal "Story #7", post.display_title
  end
end

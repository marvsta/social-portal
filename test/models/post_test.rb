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
end

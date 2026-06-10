class CreatePostMetrics < ActiveRecord::Migration[8.1]
  def change
    create_table :post_metrics do |t|
      t.references :channel_post, null: false, foreign_key: true
      t.integer :likes, default: 0, null: false
      t.integer :comments, default: 0, null: false
      t.integer :shares, default: 0, null: false
      t.integer :saves, default: 0, null: false
      t.integer :reach, default: 0, null: false
      t.integer :impressions, default: 0, null: false
      t.integer :video_views, default: 0, null: false
      t.decimal :engagement_rate, precision: 6, scale: 3, default: 0
      t.datetime :captured_at, null: false

      t.timestamps
    end
    add_index :post_metrics, [ :channel_post_id, :captured_at ]
  end
end

class CreateChannelPosts < ActiveRecord::Migration[8.1]
  def change
    create_table :channel_posts do |t|
      t.references :post, null: false, foreign_key: true
      t.references :social_channel, null: false, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.string :external_id
      t.string :external_url
      t.datetime :published_at
      t.datetime :last_attempted_at
      t.integer :attempts, null: false, default: 0
      t.text :last_error

      t.timestamps
    end
    add_index :channel_posts, [ :post_id, :social_channel_id ], unique: true
    add_index :channel_posts, :status
  end
end

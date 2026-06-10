class CreatePosts < ActiveRecord::Migration[8.1]
  def change
    create_table :posts do |t|
      t.references :company, null: false, foreign_key: true
      t.references :author, null: false, foreign_key: { to_table: :users }
      t.string :title
      t.text :caption
      t.text :hashtags
      t.string :status, null: false, default: "draft"
      t.datetime :scheduled_at
      t.datetime :approved_at
      t.references :approved_by, foreign_key: { to_table: :users }
      t.text :review_notes

      t.timestamps
    end
    add_index :posts, [ :company_id, :status ]
    add_index :posts, [ :company_id, :scheduled_at ]
  end
end

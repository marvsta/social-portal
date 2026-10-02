class AddPostTypeToPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :posts, :post_type, :string, default: "post", null: false
    add_index :posts, [ :company_id, :post_type ]
  end
end

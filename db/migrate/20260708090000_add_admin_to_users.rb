class AddAdminToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :admin, :boolean, null: false, default: false
    # "admin" used to be a per-company membership role; it's now a platform-wide
    # flag on users. Legacy admin memberships become company owners.
    execute "UPDATE memberships SET role = 'owner' WHERE role = 'admin'"
  end

  def down
    remove_column :users, :admin
  end
end

# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_05_08_141052) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "channel_posts", force: :cascade do |t|
    t.integer "attempts", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "external_id"
    t.string "external_url"
    t.datetime "last_attempted_at"
    t.text "last_error"
    t.bigint "post_id", null: false
    t.datetime "published_at"
    t.bigint "social_channel_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["post_id", "social_channel_id"], name: "index_channel_posts_on_post_id_and_social_channel_id", unique: true
    t.index ["post_id"], name: "index_channel_posts_on_post_id"
    t.index ["social_channel_id"], name: "index_channel_posts_on_social_channel_id"
    t.index ["status"], name: "index_channel_posts_on_status"
  end

  create_table "companies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "logo_url"
    t.string "name", null: false
    t.string "slug", null: false
    t.string "timezone", default: "UTC", null: false
    t.datetime "updated_at", null: false
    t.string "website"
    t.index ["slug"], name: "index_companies_on_slug", unique: true
  end

  create_table "memberships", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.string "role", default: "member", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["company_id"], name: "index_memberships_on_company_id"
    t.index ["user_id", "company_id"], name: "index_memberships_on_user_id_and_company_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "post_metrics", force: :cascade do |t|
    t.datetime "captured_at", null: false
    t.bigint "channel_post_id", null: false
    t.integer "comments", default: 0, null: false
    t.datetime "created_at", null: false
    t.decimal "engagement_rate", precision: 6, scale: 3, default: "0.0"
    t.integer "impressions", default: 0, null: false
    t.integer "likes", default: 0, null: false
    t.integer "reach", default: 0, null: false
    t.integer "saves", default: 0, null: false
    t.integer "shares", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "video_views", default: 0, null: false
    t.index ["channel_post_id", "captured_at"], name: "index_post_metrics_on_channel_post_id_and_captured_at"
    t.index ["channel_post_id"], name: "index_post_metrics_on_channel_post_id"
  end

  create_table "posts", force: :cascade do |t|
    t.datetime "approved_at"
    t.bigint "approved_by_id"
    t.bigint "author_id", null: false
    t.text "caption"
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.text "hashtags"
    t.text "review_notes"
    t.datetime "scheduled_at"
    t.string "status", default: "draft", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["approved_by_id"], name: "index_posts_on_approved_by_id"
    t.index ["author_id"], name: "index_posts_on_author_id"
    t.index ["company_id", "scheduled_at"], name: "index_posts_on_company_id_and_scheduled_at"
    t.index ["company_id", "status"], name: "index_posts_on_company_id_and_status"
    t.index ["company_id"], name: "index_posts_on_company_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["token"], name: "index_sessions_on_token", unique: true
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "social_channels", force: :cascade do |t|
    t.text "access_token"
    t.string "avatar_url"
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.string "display_name"
    t.string "external_account_id"
    t.string "handle"
    t.string "platform", null: false
    t.string "status", default: "active", null: false
    t.datetime "token_expires_at"
    t.datetime "updated_at", null: false
    t.index ["company_id", "platform"], name: "index_social_channels_on_company_id_and_platform"
    t.index ["company_id"], name: "index_social_channels_on_company_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "current_company_id"
    t.string "email", null: false
    t.string "name"
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index "lower((email)::text)", name: "index_users_on_lower_email", unique: true
    t.index ["current_company_id"], name: "index_users_on_current_company_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "channel_posts", "posts"
  add_foreign_key "channel_posts", "social_channels"
  add_foreign_key "memberships", "companies"
  add_foreign_key "memberships", "users"
  add_foreign_key "post_metrics", "channel_posts"
  add_foreign_key "posts", "companies"
  add_foreign_key "posts", "users", column: "approved_by_id"
  add_foreign_key "posts", "users", column: "author_id"
  add_foreign_key "sessions", "users"
  add_foreign_key "social_channels", "companies"
  add_foreign_key "users", "companies", column: "current_company_id"
end

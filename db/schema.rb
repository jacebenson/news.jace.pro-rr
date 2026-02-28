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

ActiveRecord::Schema[8.0].define(version: 2026_02_27_200003) do
  create_table "companies", force: :cascade do |t|
    t.string "name"
    t.text "alias", default: "[]"
    t.boolean "active", default: true
    t.boolean "is_customer", default: false
    t.boolean "is_partner", default: false
    t.string "website"
    t.string "image_url"
    t.text "notes"
    t.string "city"
    t.string "state"
    t.string "country"
    t.string "build_level"
    t.string "consulting_level"
    t.string "reseller_level"
    t.string "service_provider_level"
    t.string "partner_level"
    t.string "servicenow_url"
    t.string "rss_feed_url"
    t.string "servicenow_page_url"
    t.text "products", default: "[]"
    t.text "services", default: "[]"
    t.datetime "last_fetched_at"
    t.datetime "last_sitemap_check"
    t.boolean "has_sitemap"
    t.datetime "last_found_in_partner_list"
    t.text "locked_fields", default: "[]"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_companies_on_active"
    t.index ["is_customer"], name: "index_companies_on_is_customer"
    t.index ["is_partner"], name: "index_companies_on_is_partner"
    t.index ["name"], name: "index_companies_on_name", unique: true
  end

  create_table "knowledge_session_lists", force: :cascade do |t|
    t.integer "knowledge_session_id", null: false
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["knowledge_session_id"], name: "index_knowledge_session_lists_on_knowledge_session_id"
    t.index ["user_id"], name: "index_knowledge_session_lists_on_user_id"
  end

  create_table "knowledge_session_participants", force: :cascade do |t|
    t.integer "knowledge_session_id", null: false
    t.integer "participant_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["knowledge_session_id"], name: "index_knowledge_session_participants_on_knowledge_session_id"
    t.index ["participant_id"], name: "index_knowledge_session_participants_on_participant_id"
  end

  create_table "knowledge_sessions", force: :cascade do |t|
    t.string "code"
    t.string "session_id"
    t.string "title"
    t.string "title_sort"
    t.text "abstract"
    t.string "published"
    t.datetime "modified"
    t.string "event_id"
    t.text "participants"
    t.text "times"
    t.string "recording_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["session_id"], name: "index_knowledge_sessions_on_session_id", unique: true
  end

  create_table "mvp_awards", force: :cascade do |t|
    t.integer "participant_id", null: false
    t.integer "year", null: false
    t.string "award_type", null: false
    t.string "source_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["award_type"], name: "index_mvp_awards_on_award_type"
    t.index ["participant_id", "year", "award_type"], name: "index_mvp_awards_unique", unique: true
    t.index ["participant_id"], name: "index_mvp_awards_on_participant_id"
    t.index ["year"], name: "index_mvp_awards_on_year"
  end

  create_table "news_feeds", force: :cascade do |t|
    t.string "title"
    t.boolean "active", default: true
    t.string "status", default: "active"
    t.text "notes"
    t.string "image_url"
    t.string "url"
    t.string "default_author"
    t.string "feed_type", default: "rss"
    t.string "fetch_url"
    t.datetime "last_successful_fetch"
    t.text "last_error"
    t.integer "error_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_news_feeds_on_active"
    t.index ["feed_type"], name: "index_news_feeds_on_feed_type"
    t.index ["status"], name: "index_news_feeds_on_status"
    t.index ["title"], name: "index_news_feeds_on_title"
  end

  create_table "news_item_participants", force: :cascade do |t|
    t.integer "news_item_id", null: false
    t.integer "participant_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["news_item_id"], name: "index_news_item_participants_on_news_item_id"
    t.index ["participant_id"], name: "index_news_item_participants_on_participant_id"
  end

  create_table "news_item_tags", force: :cascade do |t|
    t.integer "news_item_id", null: false
    t.integer "tag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["news_item_id"], name: "index_news_item_tags_on_news_item_id"
    t.index ["tag_id"], name: "index_news_item_tags_on_tag_id"
  end

  create_table "news_items", force: :cascade do |t|
    t.string "item_type", default: "article"
    t.boolean "active", default: true
    t.string "state", default: "new"
    t.string "title"
    t.text "body"
    t.string "url"
    t.string "image_url"
    t.string "duration"
    t.datetime "published_at"
    t.datetime "event_start"
    t.datetime "event_end"
    t.string "event_location"
    t.string "ad_url"
    t.string "call_to_action"
    t.integer "news_feed_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["news_feed_id"], name: "index_news_items_on_news_feed_id"
    t.index ["title", "published_at"], name: "index_news_items_on_title_and_published_at"
    t.index ["url"], name: "index_news_items_on_url", unique: true
  end

  create_table "participants", force: :cascade do |t|
    t.string "name"
    t.text "alias"
    t.string "company_name"
    t.string "title"
    t.text "bio"
    t.string "image_url"
    t.string "linkedin_url"
    t.integer "user_id"
    t.integer "company_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_participants_on_company_id"
    t.index ["name"], name: "index_participants_on_name", unique: true
    t.index ["user_id"], name: "index_participants_on_user_id"
  end

  create_table "servicenow_investments", force: :cascade do |t|
    t.string "investment_type"
    t.text "content"
    t.text "summary"
    t.string "url"
    t.string "amount"
    t.string "currency"
    t.datetime "date"
    t.text "people"
    t.string "company_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "servicenow_store_apps", force: :cascade do |t|
    t.string "source_app_id"
    t.string "title"
    t.string "tagline"
    t.text "store_description"
    t.string "company_name"
    t.string "company_logo"
    t.string "logo"
    t.string "app_type"
    t.string "app_sub_type"
    t.string "version"
    t.text "versions_data"
    t.integer "purchase_count"
    t.integer "review_count"
    t.integer "table_count"
    t.text "key_features"
    t.text "business_challenge"
    t.text "system_requirements"
    t.text "supporting_media"
    t.text "support_links"
    t.text "support_contacts"
    t.text "purchase_trend"
    t.string "display_price"
    t.string "landing_page"
    t.boolean "allow_for_existing_customers"
    t.boolean "allow_for_non_customers"
    t.boolean "allow_on_customer_subprod"
    t.boolean "allow_on_developer_instance"
    t.boolean "allow_on_servicenow_instance"
    t.boolean "allow_trial"
    t.boolean "allow_without_license"
    t.datetime "last_fetched_at"
    t.datetime "published_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["source_app_id"], name: "index_servicenow_store_apps_on_source_app_id", unique: true
  end

  create_table "snapp_cards", force: :cascade do |t|
    t.integer "participant_id", null: false
    t.string "edition", null: false
    t.string "card_name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["edition"], name: "index_snapp_cards_on_edition"
    t.index ["participant_id", "edition", "card_name"], name: "index_snapp_cards_unique", unique: true
    t.index ["participant_id"], name: "index_snapp_cards_on_participant_id"
  end

  create_table "startup_founders", force: :cascade do |t|
    t.integer "participant_id", null: false
    t.string "company_name", null: false
    t.string "source_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_name"], name: "index_startup_founders_on_company_name"
    t.index ["participant_id", "company_name"], name: "index_startup_founders_unique", unique: true
    t.index ["participant_id"], name: "index_startup_founders_on_participant_id"
  end

  create_table "tags", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_tags_on_name", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email"
    t.string "password_digest"
    t.string "name"
    t.string "link"
    t.string "roles"
    t.string "reset_token"
    t.datetime "reset_token_expires_at"
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "knowledge_session_lists", "knowledge_sessions"
  add_foreign_key "knowledge_session_lists", "users"
  add_foreign_key "knowledge_session_participants", "knowledge_sessions"
  add_foreign_key "knowledge_session_participants", "participants"
  add_foreign_key "mvp_awards", "participants"
  add_foreign_key "news_item_participants", "news_items"
  add_foreign_key "news_item_participants", "participants"
  add_foreign_key "news_item_tags", "news_items"
  add_foreign_key "news_item_tags", "tags"
  add_foreign_key "news_items", "news_feeds"
  add_foreign_key "participants", "companies"
  add_foreign_key "participants", "users"
  add_foreign_key "snapp_cards", "participants"
  add_foreign_key "startup_founders", "participants"
end

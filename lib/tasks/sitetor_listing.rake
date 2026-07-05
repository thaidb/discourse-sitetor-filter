# frozen_string_literal: true

# Backfill: parse every existing topic in the configured categories.
# Run inside the container:  rake sitetor_listing:backfill
# Idempotent — only overwrites a field when parsing yields a value.
desc "Parse price/frontage/area/type/address for all existing property topics"
task "sitetor_listing:backfill" => :environment do
  # One-time migration: rename legacy bds_* custom fields (pre-0.4 installs)
  # to listing_* — keeps previously backfilled data without re-parsing.
  legacy_renames = {
    "bds_gia" => SitetorListing::FIELD_PRICE,
    "bds_mat_tien" => SitetorListing::FIELD_FRONTAGE,
    "bds_dien_tich" => SitetorListing::FIELD_AREA,
    "bds_loai" => SitetorListing::FIELD_TYPE,
    "bds_vi_tri" => SitetorListing::FIELD_POSITION,
    "bds_huong" => SitetorListing::FIELD_DIRECTION,
    "bds_so_nha" => SitetorListing::FIELD_STREET_NUMBER,
    "bds_duong" => SitetorListing::FIELD_STREET,
    "bds_phuong" => SitetorListing::FIELD_WARD,
    "bds_quan" => SitetorListing::FIELD_DISTRICT,
    "bds_tinh" => SitetorListing::FIELD_PROVINCE,
  }
  migrated = 0
  legacy_renames.each do |old_name, new_name|
    migrated += TopicCustomField.where(name: old_name).update_all(name: new_name)
  end
  puts "Migrated #{migrated} legacy bds_* field rows to listing_*." if migrated > 0

  cat_ids = SitetorListing::Extract.category_ids # includes sub-categories
  scope = Topic.where(category_id: cat_ids).where(deleted_at: nil)
  total = scope.count
  done = 0
  hit = 0

  # Clean garbage values from previous runs (non-numeric, or implausible price)
  cleaned = TopicCustomField
    .where(name: [SitetorListing::FIELD_PRICE, SitetorListing::FIELD_FRONTAGE, SitetorListing::FIELD_AREA])
    .where.not("value ~ '^\\d+(\\.\\d+)?$'")
    .delete_all
  cleaned += TopicCustomField
    .where(name: SitetorListing::FIELD_PRICE)
    .where(
      "CAST(value AS numeric) < ? OR CAST(value AS numeric) > ?",
      SitetorListing::Parser::MIN_PLAUSIBLE_PRICE,
      SitetorListing::Parser::MAX_PLAUSIBLE_PRICE,
    )
    .delete_all
  puts "Cleaned #{cleaned} garbage values." if cleaned > 0

  puts "Backfilling #{total} topics in categories #{cat_ids.inspect}..."

  scope.find_each do |topic|
    first_post = topic.first_post
    next unless first_post

    # shares logic with the realtime hook (price/frontage/area + type/position/direction + address)
    if SitetorListing::Extract.apply(topic, "#{topic.title} #{first_post.raw}")
      topic.save_custom_fields(true)
      hit += 1
    end

    done += 1
    puts "  #{done}/#{total} (extracted: #{hit})" if (done % 500).zero?
  end

  puts "Done: #{done} topics, extracted data for #{hit} (#{(hit * 100.0 / [total, 1].max).round}%)"
end

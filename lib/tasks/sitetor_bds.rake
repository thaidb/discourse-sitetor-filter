# frozen_string_literal: true

# Backfill: parse toàn bộ topic cũ trong các category cấu hình.
# Chạy trong container:  rake sitetor_bds:backfill
# Chạy lại an toàn (idempotent) — chỉ ghi đè field khi parse ra giá trị.
desc "Parse giá/mặt tiền/diện tích cho toàn bộ topic BĐS cũ"
task "sitetor_bds:backfill" => :environment do
  cat_ids = SiteSetting.sitetor_bds_categories.split("|").map(&:to_i)
  scope = Topic.where(category_id: cat_ids).where(deleted_at: nil)
  total = scope.count
  done = 0
  hit = 0

  puts "Backfill #{total} topics trong categories #{cat_ids.inspect}..."

  scope.find_each do |topic|
    first_post = topic.first_post
    next unless first_post

    parsed = SitetorBds::Parser.parse(
      "#{topic.title} #{first_post.raw}",
      usd_rate: SiteSetting.sitetor_bds_usd_rate,
    )

    if parsed.values.any?
      topic.custom_fields[SitetorBds::FIELD_GIA] = parsed[:gia] if parsed[:gia]
      topic.custom_fields[SitetorBds::FIELD_MAT_TIEN] = parsed[:mat_tien] if parsed[:mat_tien]
      topic.custom_fields[SitetorBds::FIELD_DIEN_TICH] = parsed[:dien_tich] if parsed[:dien_tich]
      topic.save_custom_fields(true)
      hit += 1
    end

    done += 1
    puts "  #{done}/#{total} (trích được: #{hit})" if (done % 500).zero?
  end

  puts "Xong: #{done} topics, trích được dữ liệu: #{hit} (#{(hit * 100.0 / [total, 1].max).round}%)"
end

# frozen_string_literal: true

# Query lọc topic dùng chung cho FilterController (JSON) và PageController#seo
# (HTML cho crawler). Nhận hash filter đã chuẩn hoá, trả {total:, topics:}.
module SitetorListing
  module TopicFilter
    SORTS = {
      "price_asc" => [SitetorListing::FIELD_PRICE, "ASC"],
      "price_desc" => [SitetorListing::FIELD_PRICE, "DESC"],
      "area_desc" => [SitetorListing::FIELD_AREA, "DESC"],
    }.freeze

    module_function

    # f: { q:, price_min:, price_max:, frontage_min:, frontage_max:, area_min:, area_max:,
    #      multi: {"type"=>["Nhà mặt phố"], ...}, sort:, page: }
    def run(f, category_ids, per:)
      scope = Topic.visible.listable_topics.where(category_id: category_ids)

      if f[:q].present?
        scope = scope.where("topics.title ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(f[:q])}%")
      end

      scope = range(scope, SitetorListing::FIELD_PRICE, f[:price_min], f[:price_max])
      scope = range(scope, SitetorListing::FIELD_FRONTAGE, f[:frontage_min], f[:frontage_max])
      scope = range(scope, SitetorListing::FIELD_AREA, f[:area_min], f[:area_max])

      (f[:multi] || {}).each do |param, values|
        next if values.blank?
        if SitetorListing::ENUM_TAG_PARAMS.include?(param)
          scope = by_enum(scope, param, values)
        elsif (field = SitetorListing::MULTI_FILTERS[param])
          scope = by_field(scope, field, values)
        end
      end

      scope = by_tags(scope, f[:tags]) if f[:tags].present?

      total = scope.count
      page = f[:page].to_i
      topics = sort(scope, f[:sort]).offset(page * per).limit(per)
      { total: total, topics: topics }
    end

    # Match-all tag intersection: topic must carry EVERY tag in `names`.
    def by_tags(scope, names)
      tag_ids = Tag.where(name: names).pluck(:id)
      return scope.none if tag_ids.size < names.uniq.size

      tag_ids.each_with_index do |tid, i|
        scope = scope.joins(<<~SQL)
          INNER JOIN topic_tags tt_#{i}
            ON tt_#{i}.topic_id = topics.id AND tt_#{i}.tag_id = #{tid.to_i}
        SQL
      end
      scope
    end

    # Lọc 1 chiều enum (type/position/direction) bằng TAG. OR trong-chiều (topic
    # mang BẤT KỲ tag nào đã chọn), AND giữa-các-chiều (mỗi lần gọi thêm một
    # WHERE riêng → giao). Value đến có thể là tên tag chuẩn (thanh filter
    # /c/listing) hoặc chữ hiển thị field (SEO/trang /listing cũ) — đều quy về
    # tag qua enum_value_to_tag. Value không map được tag ("Nhà hẻm"/"Tầng
    # thương mại") rơi về field (OR chung trong chiều).
    def by_enum(scope, param, values)
      vocab = SitetorListing::DemandFilter.enum_tag_names(SitetorListing::ENUM_GROUP_PARAM[param])
      tag_names = []
      field_values = []
      values.each do |v|
        tag = enum_value_to_tag(param, v, vocab)
        tag ? (tag_names << tag) : (field_values << v)
      end

      conds = []
      binds = []
      if tag_names.any?
        tag_ids = Tag.where(name: tag_names).pluck(:id)
        if tag_ids.any?
          conds << "EXISTS (SELECT 1 FROM topic_tags te WHERE te.topic_id = topics.id AND te.tag_id IN (?))"
          binds << tag_ids
        end
      end
      if field_values.any? && (field = SitetorListing::MULTI_FILTERS[param])
        conds << "EXISTS (SELECT 1 FROM topic_custom_fields fe WHERE fe.topic_id = topics.id AND fe.name = ? AND fe.value IN (?))"
        binds << field << field_values
      end

      return scope.none if conds.empty?
      scope.where(conds.join(" OR "), *binds)
    end

    # Chữ hiển thị / tên tag → tên tag chuẩn trong group; nil nếu không có tag
    # tương ứng (→ caller dùng field-fallback).
    def enum_value_to_tag(param, value, vocab)
      v = value.to_s.strip
      return nil if v.empty?
      return v if vocab.include?(v) # đã là tên tag chuẩn

      case param
      when "type" then SitetorListing::TYPE_TAG[v]
      when "position" then SitetorListing::POSITION_TAG[v]
      when "direction"
        d = v.tr(" ", "-")
        vocab.include?(d) ? d : nil
      end
    end

    def by_field(scope, field, values)
      scope.joins(<<~SQL).where("mf_#{field}.value IN (?)", values)
        INNER JOIN topic_custom_fields mf_#{field}
          ON mf_#{field}.topic_id = topics.id
          AND mf_#{field}.name = '#{field}'
      SQL
    end

    def range(scope, field, min, max)
      return scope if min.blank? && max.blank?

      scope = scope.joins(<<~SQL)
        INNER JOIN topic_custom_fields tcf_#{field}
          ON tcf_#{field}.topic_id = topics.id
          AND tcf_#{field}.name = '#{field}'
          AND tcf_#{field}.value ~ '^\\d+(\\.\\d+)?$'
      SQL
      scope = scope.where("CAST(tcf_#{field}.value AS numeric) >= ?", min.to_f) if min.present?
      scope = scope.where("CAST(tcf_#{field}.value AS numeric) <= ?", max.to_f) if max.present?
      scope
    end

    def sort(scope, key)
      field, dir = SORTS[key.to_s]
      return scope.order(bumped_at: :desc) unless field

      scope
        .joins(<<~SQL)
          LEFT JOIN topic_custom_fields sort_#{field}
            ON sort_#{field}.topic_id = topics.id
            AND sort_#{field}.name = '#{field}'
            AND sort_#{field}.value ~ '^\\d+(\\.\\d+)?$'
        SQL
        .order(Arel.sql("CAST(sort_#{field}.value AS numeric) #{dir} NULLS LAST, topics.bumped_at DESC"))
    end

    def serialize(t)
      cf = t.custom_fields
      {
        id: t.id,
        title: t.title,
        slug: t.slug,
        category_id: t.category_id,
        created_at: t.created_at,
        bumped_at: t.bumped_at,
        tags: t.tags.pluck(:name),
        image: t.image_url,
        price: cf[SitetorListing::FIELD_PRICE]&.to_i,
        frontage: cf[SitetorListing::FIELD_FRONTAGE]&.to_f,
        area: cf[SitetorListing::FIELD_AREA]&.to_f,
        type: cf[SitetorListing::FIELD_TYPE],
        position: cf[SitetorListing::FIELD_POSITION],
        direction: cf[SitetorListing::FIELD_DIRECTION],
        street_number: cf[SitetorListing::FIELD_STREET_NUMBER],
        street: cf[SitetorListing::FIELD_STREET],
        ward: cf[SitetorListing::FIELD_WARD],
        district: cf[SitetorListing::FIELD_DISTRICT],
        province: cf[SitetorListing::FIELD_PROVINCE],
      }
    end
  end
end

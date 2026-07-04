# frozen_string_literal: true

module SitetorFilter
  class FilterController < ::ApplicationController
    requires_plugin SitetorFilter::PLUGIN_NAME

    SORTS = {
      "new" => "topics.bumped_at DESC",
      "price_asc" => :gia_asc,
      "price_desc" => :gia_desc,
      "area_desc" => :dt_desc,
    }.freeze

    # GET /listing/filter.json
    # Params: q (từ khóa tiêu đề) | gia_min, gia_max (VND) | mt_min, mt_max (m)
    #         dt_min, dt_max (m2) | category_id | sort (new/price_asc/price_desc/area_desc) | page
    def index
      page = params[:page].to_i
      per = SiteSetting.sitetor_filter_page_size

      topics = Topic
        .visible
        .listable_topics
        .where(category_id: allowed_category_ids)

      if params[:q].present?
        topics = topics.where("topics.title ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(params[:q])}%")
      end

      topics = apply_range(topics, SitetorFilter::FIELD_GIA, :gia_min, :gia_max)
      topics = apply_range(topics, SitetorFilter::FIELD_MAT_TIEN, :mt_min, :mt_max)
      topics = apply_range(topics, SitetorFilter::FIELD_DIEN_TICH, :dt_min, :dt_max)

      total = topics.count
      topics = apply_sort(topics).offset(page * per).limit(per)

      render json: {
        total: total,
        page: page,
        per_page: per,
        topics: topics.map { |t| serialize_topic(t) },
      }
    end

    private

    def allowed_category_ids
      ids = SiteSetting.sitetor_filter_categories.split("|").map(&:to_i)
      if params[:category_id].present? && ids.include?(params[:category_id].to_i)
        [params[:category_id].to_i]
      else
        ids
      end
    end

    def apply_range(scope, field, min_key, max_key)
      min = params[min_key]
      max = params[max_key]
      return scope if min.blank? && max.blank?

      # numeric (không phải bigint) để không tràn với giá trị rác;
      # regex loại giá trị không phải số trước khi CAST.
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

    # Sort theo custom field: LEFT JOIN để tin thiếu dữ liệu vẫn hiện (xếp cuối)
    def apply_sort(scope)
      case SORTS[params[:sort].to_s]
      when :gia_asc
        sort_by_field(scope, SitetorFilter::FIELD_GIA, "ASC")
      when :gia_desc
        sort_by_field(scope, SitetorFilter::FIELD_GIA, "DESC")
      when :dt_desc
        sort_by_field(scope, SitetorFilter::FIELD_DIEN_TICH, "DESC")
      else
        scope.order(bumped_at: :desc)
      end
    end

    def sort_by_field(scope, field, dir)
      scope
        .joins(<<~SQL)
          LEFT JOIN topic_custom_fields sort_#{field}
            ON sort_#{field}.topic_id = topics.id
            AND sort_#{field}.name = '#{field}'
            AND sort_#{field}.value ~ '^\\d+(\\.\\d+)?$'
        SQL
        .order(Arel.sql("CAST(sort_#{field}.value AS numeric) #{dir} NULLS LAST, topics.bumped_at DESC"))
    end

    def serialize_topic(t)
      cf = t.custom_fields
      {
        id: t.id,
        title: t.title,
        slug: t.slug,
        category_id: t.category_id,
        created_at: t.created_at,
        bumped_at: t.bumped_at,
        tags: t.tags.pluck(:name),
        gia: cf[SitetorFilter::FIELD_GIA]&.to_i,
        mat_tien: cf[SitetorFilter::FIELD_MAT_TIEN]&.to_f,
        dien_tich: cf[SitetorFilter::FIELD_DIEN_TICH]&.to_f,
      }
    end
  end
end

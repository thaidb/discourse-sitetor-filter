# frozen_string_literal: true

module SitetorListing
  # Chủ topic (hoặc staff) nhập/sửa thông tin NHU CẦU (Cần mua/Cần thuê):
  # ngân sách, diện tích, mặt tiền, khu vực, mục đích, ngành nghề, thông tin khách.
  # Custom field là NGUỒN CHUẨN (đối xứng field listing_* để ghép tin /mapping);
  # tag SEO được đồng bộ song song từ purpose/industry/hướng/vị trí (giá trị == tên tag).
  # Sau khi nhập tay, cờ listing_manual=true chặn parser ghi đè.
  class DemandInfoController < ::ApplicationController
    requires_plugin SitetorListing::PLUGIN_NAME
    before_action :ensure_logged_in, only: [:update]

    INTEGER_PARAMS = %w[budget_from budget_to number_floor].freeze
    FLOAT_PARAMS = %w[area_from area_to frontage_from frontage_to floor_area_from floor_area_to].freeze
    MULTI_PARAMS = %w[purpose industry view].freeze
    # địa chỉ trên topic nhu cầu là multi (JSON array) — 1 nhu cầu nhắm nhiều khu vực
    ADDRESS_MULTI_PARAMS = SitetorListing::DEMAND_ADDRESS_MULTI
    SELECT_PARAMS = {
      "demand_type" => SitetorListing::DEMAND_TYPES,
      "listing_type" => SitetorListing::SeoSlugs::TYPES,
      "direction" => SitetorListing::DEMAND_DIRECTIONS,
      "position" => SitetorListing::DEMAND_POSITIONS,
    }.freeze

    TEXT_MAX = 120
    NOTE_MAX = 2000
    MULTI_MAX = 30

    # listing_position do parser cũ ghi (giá trị có dấu cách) → chuẩn hóa về tên tag
    POSITION_NORMALIZE = {
      "Mặt tiền" => "Mặt-tiền",
      "Đường Nội Bộ" => "Nội-bộ",
      "Khu Compound" => "Khu-compound",
    }.freeze

    # GET /listing/demand-info/:topic_id
    def show
      topic = find_topic
      guardian.ensure_can_see!(topic)
      render json: info_for(topic)
    end

    # POST /listing/demand-info/:topic_id — blank = xóa giá trị field đó
    def update
      topic = find_topic
      guardian.ensure_can_edit!(topic)

      SitetorListing::DEMAND_UPDATABLE.each do |param, field|
        next unless params.key?(param)
        write_field(topic, field, cast_param(param, params[param]))
      end

      topic.custom_fields[SitetorListing::FIELD_MANUAL] = "true"
      topic.save_custom_fields(true)
      sync_tags(topic)

      render json: info_for(topic)
    end

    private

    def find_topic
      Topic.find_by(id: params[:topic_id].to_i) || raise(Discourse::NotFound)
    end

    def write_field(topic, field, value)
      if value.nil?
        topic.custom_fields.delete(field)
      else
        topic.custom_fields[field] = value
      end
    end

    def cast_param(param, raw)
      if INTEGER_PARAMS.include?(param)
        value = raw.presence&.to_f
        value && value > 0 ? value.round : nil
      elsif FLOAT_PARAMS.include?(param)
        value = raw.presence&.to_f
        value && value > 0 ? value : nil
      elsif MULTI_PARAMS.include?(param) || ADDRESS_MULTI_PARAMS.include?(param)
        list =
          parse_multi(raw)
            .map { |v| v.to_s.strip.slice(0, TEXT_MAX) }
            .reject(&:blank?)
            .uniq
            .first(MULTI_MAX)
        list &= SitetorListing::DEMAND_PURPOSES if param == "purpose"
        list.present? ? list.to_json : nil
      elsif (allowed = SELECT_PARAMS[param])
        value = raw.presence
        allowed.include?(value) ? value : nil
      else
        raw.presence&.slice(0, param == "note" ? NOTE_MAX : TEXT_MAX)
      end
    end

    # multi field nhận JSON array string từ client (lưu nguyên dạng đó vào custom field)
    def parse_multi(raw)
      return raw if raw.is_a?(Array)
      parsed = JSON.parse(raw.to_s)
      parsed.is_a?(Array) ? parsed : []
    rescue JSON::ParserError
      []
    end

    def multi_values(topic, field)
      parse_multi(topic.custom_fields[field])
    end

    # địa chỉ: giá trị mới là JSON array; giá trị cũ (parser ghi chuỗi đơn)
    # bọc thành mảng 1 phần tử để client prefill được
    def address_values(raw)
      return [] if raw.blank?
      parsed = JSON.parse(raw.to_s)
      parsed.is_a?(Array) ? parsed : [raw.to_s]
    rescue JSON::ParserError
      [raw.to_s]
    end

    # Đồng bộ tag SEO song song — custom field là nguồn chuẩn, tag chỉ là
    # hình chiếu (nhóm H mục đích / I ngành nghề / E hướng / D vị trí).
    # Chỉ append, không xóa tag cũ.
    def sync_tags(topic)
      new_names =
        multi_values(topic, SitetorListing::FIELD_DEMAND_PURPOSE) +
          multi_values(topic, SitetorListing::FIELD_DEMAND_INDUSTRY) +
          [
            topic.custom_fields[SitetorListing::FIELD_DIRECTION],
            topic.custom_fields[SitetorListing::FIELD_POSITION],
          ]
      new_names =
        new_names
          .map { |n| n.to_s.tr(" ", "-") } # "Đông Nam" (parser cũ) → tag "Đông-Nam"
          .reject(&:blank?)
          .uniq
      return if new_names.empty?

      DiscourseTagging.tag_topic_by_names(
        topic,
        Guardian.new(Discourse.system_user),
        (topic.tags.pluck(:name) + new_names).uniq,
        append: true,
      )
    end

    def info_for(topic)
      cf = topic.custom_fields
      out = {
        topic_id: topic.id,
        can_edit: guardian.can_edit?(topic),
        manual: cf[SitetorListing::FIELD_MANUAL] == "true",
      }
      SitetorListing::DEMAND_UPDATABLE.each do |param, field|
        out[param] =
          if MULTI_PARAMS.include?(param)
            parse_multi(cf[field])
          elsif ADDRESS_MULTI_PARAMS.include?(param)
            address_values(cf[field])
          elsif INTEGER_PARAMS.include?(param)
            cf[field]&.to_i
          elsif FLOAT_PARAMS.include?(param)
            cf[field]&.to_f
          elsif param == "direction"
            cf[field]&.tr(" ", "-") # prefill khớp option dạng tên tag
          elsif param == "position"
            POSITION_NORMALIZE.fetch(cf[field], cf[field])
          else
            cf[field]
          end
      end
      out
    end
  end
end

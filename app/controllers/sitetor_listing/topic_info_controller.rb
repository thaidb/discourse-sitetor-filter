# frozen_string_literal: true

module SitetorListing
  # Chủ topic (hoặc staff) tự nhập/sửa thông tin BĐS có cấu trúc cho topic:
  # giá, diện tích, mặt tiền, loại SP, vị trí, hướng, địa chỉ.
  # Sau khi nhập tay, cờ listing_manual=true chặn parser ghi đè.
  class TopicInfoController < ::ApplicationController
    requires_plugin SitetorListing::PLUGIN_NAME
    before_action :ensure_logged_in, only: [:update]

    NUMERIC_FIELDS = {
      "price" => SitetorListing::FIELD_PRICE,
      "frontage" => SitetorListing::FIELD_FRONTAGE,
      "area" => SitetorListing::FIELD_AREA,
    }.freeze

    SELECT_FIELDS = {
      "type" => [SitetorListing::FIELD_TYPE, SitetorListing::SeoSlugs::TYPES],
      "position" => [SitetorListing::FIELD_POSITION, SitetorListing::SeoSlugs::POSITIONS],
      "direction" => [SitetorListing::FIELD_DIRECTION, SitetorListing::SeoSlugs::DIRECTIONS],
    }.freeze

    TEXT_FIELDS = {
      "street_number" => SitetorListing::FIELD_STREET_NUMBER,
      "street" => SitetorListing::FIELD_STREET,
      "ward" => SitetorListing::FIELD_WARD,
      "district" => SitetorListing::FIELD_DISTRICT,
      "province" => SitetorListing::FIELD_PROVINCE,
    }.freeze

    # GET /listing/topic-info.json?topic_id=
    def show
      topic = find_topic
      guardian.ensure_can_see!(topic)
      render json: info_for(topic)
    end

    # PUT /listing/topic-info.json — blank = xóa giá trị field đó
    def update
      topic = find_topic
      guardian.ensure_can_edit!(topic)

      NUMERIC_FIELDS.each do |param, field|
        next unless params.key?(param)
        value = params[param].presence&.to_f
        value = nil if value && value <= 0
        value = SitetorListing::Parser.clamp_price(value.round) if value && field == SitetorListing::FIELD_PRICE
        write_field(topic, field, value)
      end

      SELECT_FIELDS.each do |param, (field, allowed)|
        next unless params.key?(param)
        value = params[param].presence
        value = nil if value && !allowed.include?(value)
        write_field(topic, field, value)
      end

      TEXT_FIELDS.each do |param, field|
        next unless params.key?(param)
        write_field(topic, field, params[param].presence&.slice(0, 120))
      end

      topic.custom_fields[SitetorListing::FIELD_MANUAL] = "true"
      topic.save_custom_fields(true)

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

    def info_for(topic)
      cf = topic.custom_fields
      {
        topic_id: topic.id,
        can_edit: guardian.can_edit?(topic),
        manual: cf[SitetorListing::FIELD_MANUAL] == "true",
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

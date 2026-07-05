# frozen_string_literal: true

require "json"

# SEO filter pages: two-way conversion between pretty URLs and filter params.
#   /listing/ban/nha-mat-pho/quan-3/duong-vo-van-tan
#   ↔ { category_slug: "ban", type: "Nhà mặt phố", district: "Quận 3", street: "Võ Văn Tần" }
# Each segment kind has its own Vietnamese slug prefix so parsing is unambiguous
# (prefixes are USER-FACING SEO URLs — keep them Vietnamese):
#   product type: bare slug ("nha-mat-pho") | district: "quan-3"/"quan-go-vap"
#   ward: "phuong-12"/"phuong-thao-dien" | street: "duong-vo-van-tan"
#   position: "vi-tri-mat-tien" | direction: "huong-dong-nam" | page: "trang-N"
# Pure Ruby (catalog.json), unit-testable standalone.
module SitetorListing
  class SeoSlugs
    CATALOG_PATH = File.expand_path("data/catalog.json", __dir__)

    TYPES = [
      "Nhà mặt phố", "Nhà hẻm", "Văn phòng", "Kho, nhà xưởng",
      "Căn hộ, chung cư", "Bán đất", "Tầng thương mại",
    ].freeze
    POSITIONS = ["Mặt tiền", "Đường Nội Bộ", "Hẻm", "Khu Compound"].freeze
    DIRECTIONS = ["Đông", "Tây", "Nam", "Bắc", "Đông Nam", "Đông Bắc", "Tây Nam", "Tây Bắc"].freeze

    def self.default
      @default ||= new(JSON.parse(File.read(CATALOG_PATH, encoding: "utf-8")))
    end

    def self.slugify(s)
      s.to_s.downcase.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").tr("đ", "d")
        .gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "")
    end

    def initialize(catalog)
      s = self.class.method(:slugify)
      @types = TYPES.to_h { |v| [s.call(v), v] }
      @positions = POSITIONS.to_h { |v| ["vi-tri-#{s.call(v)}", v] }
      @directions = DIRECTIONS.to_h { |v| ["huong-#{s.call(v)}", v] }
      @districts = catalog["districts"].to_h { |d| ["quan-#{s.call(strip_district_prefix(d["name"]))}", d["name"]] }
      @wards = catalog["wards"].to_h { |w| ["phuong-#{s.call(strip_ward_prefix(w["name"]))}", w["name"]] }
      @streets = catalog["streets"].to_h { |st| ["duong-#{s.call(st["name"])}", st["name"]] }
    end

    # @param segments [Array<String>] path segments (excluding category slug)
    # @param category_slugs [Hash] slug → category_id (resolved by the controller)
    # @return [Hash, nil] filter params; nil when a segment is unrecognized (→ 404)
    def parse(segments, category_slugs: {})
      out = {}
      segments.each do |seg|
        seg = seg.to_s.downcase
        if category_slugs.key?(seg)
          out[:category_id] = category_slugs[seg]
          out[:category_slug] = seg
        elsif @types.key?(seg) then out[:type] = @types[seg]
        elsif @positions.key?(seg) then out[:position] = @positions[seg]
        elsif @directions.key?(seg) then out[:direction] = @directions[seg]
        elsif @districts.key?(seg) then out[:district] = @districts[seg]
        elsif @wards.key?(seg) then out[:ward] = @wards[seg]
        elsif @streets.key?(seg) then out[:street] = @streets[seg]
        elsif (m = seg.match(/\Atrang-(\d+)\z/)) then out[:page] = m[1].to_i - 1
        else
          return nil
        end
      end
      out
    end

    # Reverse: single-value filters → path segments in canonical order
    def build(category_slug: nil, type: nil, position: nil, direction: nil, district: nil, ward: nil, street: nil, page: nil)
      s = self.class.method(:slugify)
      segs = []
      segs << category_slug if category_slug
      segs << s.call(type) if type
      segs << "vi-tri-#{s.call(position)}" if position
      segs << "quan-#{s.call(strip_district_prefix(district))}" if district
      segs << "phuong-#{s.call(strip_ward_prefix(ward))}" if ward
      segs << "duong-#{s.call(street)}" if street
      segs << "huong-#{s.call(direction)}" if direction
      segs << "trang-#{page + 1}" if page && page > 0
      segs.join("/")
    end

    # Title/H1 matching the search keyword: "Bán Nhà mặt phố đường Võ Văn Tần Quận 3"
    def title(category_name: nil, type: nil, position: nil, direction: nil, district: nil, ward: nil, street: nil, province: nil, page: nil)
      parts = []
      parts << category_name if category_name
      parts << type if type
      parts << "vị trí #{position}" if position
      parts << "đường #{street}" if street
      parts << ward_display(ward) if ward
      parts << district if district
      parts << province if province
      parts << "hướng #{direction}" if direction
      t = parts.join(" ")
      t += " - Trang #{page + 1}" if page && page > 0
      t
    end

    private

    def strip_district_prefix(name)
      name.to_s.sub(/\A(Quận|Huyện|Thành phố|Thị xã)\s+/i, "")
    end

    def strip_ward_prefix(name)
      name.to_s.sub(/\A(Phường|Xã|Thị trấn)\s+/i, "")
    end

    def ward_display(name)
      name =~ /\A(Phường|Xã|Thị trấn)/i ? name : "phường #{name}"
    end
  end
end

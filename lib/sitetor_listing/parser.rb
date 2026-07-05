# frozen_string_literal: true

# Extracts price / frontage / area from Vietnamese real-estate listing text.
# Pure Ruby — no Discourse dependency, unit-testable standalone (test/parser_test.rb).
# NOTE: regex patterns intentionally match *normalized Vietnamese* text
# ("mat tien", "trieu", "ty"...) — do not translate them.
module SitetorListing
  module Parser
    # USD→VND rate used when a listing quotes USD (overridable via site setting)
    DEFAULT_USD_RATE = 26_000

    NUM = /\d+(?:[.,]\d+)?/

    # Plausible price range: 100k VND (cheapest rent) .. 20,000 billion — outside = garbage
    MIN_PLAUSIBLE_PRICE = 100_000
    MAX_PLAUSIBLE_PRICE = 20_000_000_000_000

    module_function

    # @return [Hash] { price: Integer|nil (VND), frontage: Float|nil (m), area: Float|nil (m2) }
    def parse(text, usd_rate: DEFAULT_USD_RATE)
      t = normalize(text)
      dims = extract_dimensions(t)
      {
        price: extract_price(t, usd_rate: usd_rate),
        frontage: extract_frontage(t) || dims[:width],
        area: extract_area(t) || dims[:area],
      }
    end

    def normalize(text)
      t = text.to_s.downcase
      t = t.tr(" ", " ")
      # strip Vietnamese diacritics for keyword matching (digits untouched)
      t.unicode_normalize(:nfd).gsub(/\p{Mn}/, "")
    end

    # --- Price ---------------------------------------------------------------
    # "5 tỷ", "5,5 ty", "5 tỷ 500", "gia ban 12 ti", "25 triệu/tháng", "25tr/thang",
    # "gia thue 3.500 usd", "3000$/thang"
    def extract_price(t, usd_rate: DEFAULT_USD_RATE)
      # X tỷ Y (triệu)  e.g. "5 tỷ 500"
      if (m = t.match(/(#{NUM})\s*(?:ty|ti)\b(?:\s*(\d{1,3})\b(?!\s*(?:m2|m\b|%)))?/))
        billions = to_f(m[1])
        millions = m[2] ? m[2].to_f : 0
        return clamp_price((billions * 1_000_000_000 + millions * 1_000_000).round)
      end
      # X triệu / X tr  (monthly rent, or price quoted in millions)
      if (m = t.match(/(#{NUM})\s*(?:trieu|tr)\b/))
        return clamp_price((to_f(m[1]) * 1_000_000).round)
      end
      # USD: "3.500 usd", "3500$", "$3500"
      if (m = t.match(/(?:\$\s*)(\d{3,6})\b/) || t.match(/(\d{1,3}(?:[.,]\d{3})*|\d{3,6})\s*(?:usd|\$)/))
        usd = m[1].gsub(/[.,]/, "").to_i
        return clamp_price(usd * usd_rate) if usd >= 100 # avoid tiny-number false hits
      end
      nil
    end

    def clamp_price(vnd)
      vnd.between?(MIN_PLAUSIBLE_PRICE, MAX_PLAUSIBLE_PRICE) ? vnd : nil
    end

    # --- Frontage ------------------------------------------------------------
    # "mặt tiền 6m", "mt 6m", "ngang 5m", "ngang 4,5m", "rộng 6m"
    def extract_frontage(t)
      if (m = t.match(/(?:mat\s*tien|\bmt\b|ngang|rong)[^\d]{0,12}(#{NUM})\s*m(?![²2\w])?/))
        v = to_f(m[1])
        return v if v > 0.5 && v < 100
      end
      nil
    end

    # --- Area ----------------------------------------------------------------
    # "100m2", "100 m²", "dt 100m2", "diện tích: 100,5 m2", "1000m vuong"
    def extract_area(t)
      if (m = t.match(/(?:dien\s*tich|\bdt\b|\bdtsd\b)[^\d]{0,12}(#{NUM})\s*m/)) ||
         (m = t.match(/(#{NUM})\s*(?:m2|m²|m\s*vuong)/))
        v = to_f(m[1])
        return v if v >= 5 && v < 1_000_000
      end
      nil
    end

    # --- Dimensions "5x20" ----------------------------------------------------
    # "5x20", "5 x 20m", "4,5x18", "(5m x 20m)" → width 5, area 100
    def extract_dimensions(t)
      if (m = t.match(/(#{NUM})\s*m?\s*[x×*]\s*(#{NUM})\s*m?\b/))
        a = to_f(m[1])
        b = to_f(m[2])
        # reject date/house-number lookalikes: plausible side 1..200m
        if a > 0.9 && a <= 200 && b > 0.9 && b <= 200
          width = [a, b].min
          return { width: width, area: (a * b).round(1) }
        end
      end
      { width: nil, area: nil }
    end

    def to_f(s)
      s.to_s.tr(",", ".").to_f
    end
  end
end

# frozen_string_literal: true

# Đo tỷ lệ trích xuất trên dữ liệu THẬT (không chạy trong CI — cần file /tmp/real_topics.json
# tạo bởi script fetch từ lms.sitetor.com). Dùng để đánh giá parser trước khi backfill.
require "json"
require_relative "../lib/sitetor_listing/parser"

rows = JSON.parse(File.read(ARGV[0] || "/tmp/real_topics.json", encoding: "utf-8"))
stats = { price: 0, frontage: 0, area: 0, any: 0 }
misses = []

rows.each do |r|
  res = SitetorListing::Parser.parse("#{r["title"]} #{r["excerpt"]}")
  stats[:price] += 1 if res[:price]
  stats[:frontage] += 1 if res[:frontage]
  stats[:area] += 1 if res[:area]
  if res.values.any?
    stats[:any] += 1
  else
    misses << r["title"][0, 70]
  end
end

n = rows.size.to_f
puts "Tổng #{rows.size} tin thật:"
puts "  Giá:       #{stats[:price]} (#{(stats[:price] / n * 100).round}%)"
puts "  Mặt tiền:  #{stats[:frontage]} (#{(stats[:frontage] / n * 100).round}%)"
puts "  Diện tích: #{stats[:area]} (#{(stats[:area] / n * 100).round}%)"
puts "  Ít nhất 1 trường: #{stats[:any]} (#{(stats[:any] / n * 100).round}%)"
puts "--- Tin không trích được gì (tối đa 10):"
misses.first(10).each { |m| puts "  · #{m}" }

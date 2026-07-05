# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/sitetor_listing/parser"

class ParserTest < Minitest::Test
  P = SitetorListing::Parser

  # --- Giá ---
  def test_gia_ty
    assert_equal 5_000_000_000, P.parse("Bán nhà giá 5 tỷ")[:price]
  end

  def test_gia_ty_le
    assert_equal 5_500_000_000, P.parse("giá 5,5 tỷ")[:price]
    assert_equal 12_000_000_000, P.parse("gia ban 12 ti thuong luong")[:price]
  end

  def test_gia_ty_kem_trieu
    assert_equal 5_500_000_000, P.parse("bán gấp 5 tỷ 500")[:price]
  end

  def test_gia_trieu_thang
    assert_equal 25_000_000, P.parse("cho thuê 25 triệu/tháng")[:price]
    assert_equal 25_000_000, P.parse("giá thuê 25tr/tháng")[:price]
  end

  def test_gia_usd
    assert_equal 3_500 * 26_000, P.parse("giá thuê 3.500 USD")[:price]
    assert_equal 3_000 * 26_000, P.parse("thuê $3000 mỗi tháng")[:price]
  end

  def test_khong_nham_sdt_thanh_gia
    assert_nil P.parse("Liên hệ 0901234567 chính chủ")[:price]
  end

  def test_gia_phi_ly_bi_loai
    # số điện thoại dính chữ "tỷ" hoặc giá troll → nil, không được lọt vào DB
    assert_nil P.parse("giá 0901234567 tỷ")[:price]
    assert_nil P.parse("bán 999999999 tỷ")[:price]
    assert_equal 20_000_000_000_000, P.parse("tòa nhà 20000 tỷ")[:price]
  end

  # --- Mặt tiền ---
  def test_frontage
    assert_in_delta 6.0, P.parse("nhà mặt tiền 6m đường lớn")[:frontage]
    assert_in_delta 4.5, P.parse("MT 4,5m nở hậu")[:frontage]
    assert_in_delta 5.0, P.parse("ngang 5m dài 20m")[:frontage]
  end

  # --- Diện tích ---
  def test_area
    assert_in_delta 100.0, P.parse("DT 100m2")[:area]
    assert_in_delta 85.5, P.parse("diện tích: 85,5 m²")[:area]
    assert_in_delta 1000.0, P.parse("khuôn viên 1000m vuông")[:area]
  end

  # --- Kích thước ngang x dài ---
  def test_kich_thuoc_x
    r = P.parse("nhà 5x20 hẻm xe hơi")
    assert_in_delta 5.0, r[:frontage]
    assert_in_delta 100.0, r[:area]
  end

  def test_kich_thuoc_x_don_vi
    r = P.parse("khuôn đất (4,5m x 18m) vuông vức")
    assert_in_delta 4.5, r[:frontage]
    assert_in_delta 81.0, r[:area]
  end

  def test_uu_tien_dt_ghi_ro_hon_tich_x
    r = P.parse("5x20 nhưng DT công nhận 95m2")
    assert_in_delta 95.0, r[:area]
    assert_in_delta 5.0, r[:frontage]
  end

  def test_khong_nham_ngay_thang
    assert_nil P.parse("đăng ngày 30/4 xem nhà 24/7")[:area]
  end

  # --- Tổng hợp tin thật ---
  def test_tin_tong_hop
    r = P.parse("Cho thuê nhà MT Lê Lợi Q1, ngang 6m, DT 120m2, giá 80 triệu/tháng")
    assert_equal 80_000_000, r[:price]
    assert_in_delta 6.0, r[:frontage]
    assert_in_delta 120.0, r[:area]
  end

  def test_tin_ban
    r = P.parse("Bán nhà 2 mặt tiền 8m x 25m, giá 45 tỷ TL")
    assert_equal 45_000_000_000, r[:price]
    assert_in_delta 8.0, r[:frontage]
    assert_in_delta 200.0, r[:area]
  end

  def test_khong_co_gi
    r = P.parse("Cần tư vấn pháp lý sổ hồng")
    assert_nil r[:price]
    assert_nil r[:frontage]
    assert_nil r[:area]
  end
end

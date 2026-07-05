# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/sitetor_listing/address_matcher"
require_relative "../lib/sitetor_listing/attributes"

class AddressMatcherTest < Minitest::Test
  # dùng catalog THẬT đóng gói trong plugin
  M = SitetorListing::AddressMatcher.default

  def test_quan_so
    r = M.match("Cho thuê nhà mặt tiền Quận 3 giá tốt")
    assert_equal "Quận 3", r[:district]
    assert_equal "TP Hồ Chí Minh", r[:province]
  end

  def test_quan_viet_tat
    assert_equal "Quận 1", M.match("nhà đẹp Q1 tiện kinh doanh")[:district]
    assert_equal "Quận 10", M.match("bán nhà q.10 hxh")[:district]
  end

  def test_quan_ten_chu
    assert_equal "Quận Gò Vấp", M.match("cho thuê nhà Gò Vấp 2 lầu")[:district]
    assert_equal "Quận Bình Thạnh", M.match("nhà Bình Thạnh gần chợ")[:district]
  end

  def test_khong_nham_quan_1_voi_12
    assert_equal "Quận 12", M.match("bán đất quận 12 sổ riêng")[:district]
  end

  def test_duong_va_street_number
    r = M.match("Cho thuê nhà 340 Ung Văn Khiêm, Bình Thạnh")
    assert_equal "Quận Bình Thạnh", r[:district]
    assert_equal "Ung Văn Khiêm", r[:street]
    assert_equal "340", r[:street_number]
  end

  def test_duong_pasteur_quan_3
    r = M.match("Cho thuê nhà mặt tiền đường Pasteur Quận 3")
    assert_equal "Pasteur", r[:street]
    assert_equal "Quận 3", r[:district]
  end

  def test_street_number_co_xuyet
    r = M.match("Bán nhà 12/34 Nguyễn Văn Đậu Bình Thạnh")
    assert_equal "Nguyễn Văn Đậu", r[:street]
    assert_equal "12/34", r[:street_number]
  end

  def test_phuong_so
    r = M.match("nhà Phường 12 Quận 10")
    assert_equal "Quận 10", r[:district]
    assert_equal "Phường 12", r[:ward]
  end

  def test_phuong_ten_chu
    r = M.match("căn hộ Thảo Điền Quận 2")
    assert_equal "Quận 2", r[:district]
    assert_equal "Thảo Điền", r[:ward]
  end

  def test_khong_co_dia_chi
    r = M.match("Cần tư vấn hợp đồng thuê nhà")
    assert_nil r[:district]
    assert_nil r[:street]
  end

  def test_khong_nham_ten_duong_thanh_quan_tinh_khac
    # "Nguyễn Huệ" từng bị nhầm thành TP Huế; "Tân Sơn" nhầm huyện tỉnh khác
    r = M.match("Lịch sử chào Đường Nguyễn Huệ TPHCM từ năm 2015")
    assert_equal "Nguyễn Huệ", r[:street]
    refute_equal "Thành phố Huế", r[:district]
    r2 = M.match("Lịch sử chào Tân Sơn từ năm 2015 cho đến nay")
    assert_nil r2[:district]
    assert_equal "Tân Sơn", r2[:street]
  end
end

class AttributesTest < Minitest::Test
  A = SitetorListing::Attributes

  def test_loai
    assert_equal "Văn phòng", A.extract("cho thuê văn phòng 100m2")[:type]
    assert_equal "Kho, nhà xưởng", A.extract("kho xưởng 500m2 Bình Tân")[:type]
    assert_equal "Căn hộ, chung cư", A.extract("căn hộ 2PN full nội thất")[:type]
    assert_equal "Nhà mặt phố", A.extract("nhà mặt tiền Lê Lợi")[:type]
    assert_equal "Nhà hẻm", A.extract("nhà HXH 6m thông")[:type]
    assert_equal "Bán đất", A.extract("bán đất nền dự án")[:type]
    assert_nil A.extract("cần tư vấn")[:type]
  end

  def test_position
    assert_equal "Mặt tiền", A.extract("nhà mặt tiền đường lớn")[:position]
    assert_equal "Hẻm", A.extract("nhà trong hẻm xe hơi")[:position]
    assert_equal "Khu Compound", A.extract("villa khu compound an ninh")[:position]
  end

  def test_huong
    assert_equal "Đông Nam", A.extract("nhà hướng Đông Nam mát mẻ")[:direction]
    assert_equal "Tây", A.extract("cửa hướng tây")[:direction]
    assert_nil A.extract("khu nam sài gòn")[:direction]
  end
end

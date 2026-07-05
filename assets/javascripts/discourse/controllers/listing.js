import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";

const PRICE_UNITS = { million: 1e6, billion: 1e9 };

export default class ListingController extends Controller {
  @service siteSettings;
  @service site;

  queryParams = [
    "q",
    "price_min",
    "price_max",
    "frontage_min",
    "frontage_max",
    "area_min",
    "area_max",
    "category_id",
    "sort",
    "page",
    "type",
    "position",
    "direction",
    "province",
    "district",
    "ward",
    "street",
  ];

  @tracked q = null;
  @tracked price_min = null;
  @tracked price_max = null;
  @tracked frontage_min = null;
  @tracked frontage_max = null;
  @tracked area_min = null;
  @tracked area_max = null;
  @tracked category_id = null;
  @tracked sort = null;
  @tracked page = 0;
  @tracked type = null;
  @tracked position = null;
  @tracked direction = null;
  @tracked province = null;
  @tracked district = null;
  @tracked ward = null;
  @tracked street = null;

  // input tạm — chỉ áp vào queryParams khi bấm Lọc
  @tracked fQ = "";
  @tracked fPriceMin = "";
  @tracked fPriceMax = "";
  @tracked fPriceUnit = "million"; // trieu | ty | usd
  @tracked fFrontageMin = "";
  @tracked fFrontageMax = "";
  @tracked fAreaMin = "";
  @tracked fAreaMax = "";
  @tracked fCategoryId = "";
  @tracked fSort = "new";
  @tracked sTypes = [];
  @tracked sPositions = [];
  @tracked sDirections = [];
  @tracked sProvinces = [];
  @tracked sDistricts = [];
  @tracked sWards = [];
  @tracked sStreets = [];

  // facets từ /listing/facets.json (phường/đường cascade theo quận đã chọn)
  @tracked facets = {};

  get topics() {
    return this.model?.topics || [];
  }

  get total() {
    return this.model?.total || 0;
  }

  get perPage() {
    return this.model?.per_page || this.siteSettings.sitetor_listing_page_size || 30;
  }

  get totalPages() {
    return Math.max(1, Math.ceil(this.total / this.perPage));
  }

  get currentPage() {
    return Number(this.page) + 1; // hiển thị 1-based
  }

  get categoryOptions() {
    const ids = (this.siteSettings.sitetor_listing_categories || "")
      .split("|")
      .map((s) => parseInt(s, 10))
      .filter(Boolean);
    return ids.map((id) => {
      const cat = this.site.categories?.find((c) => c.id === id);
      return { id: String(id), name: cat?.name || `#${id}` };
    });
  }

  // Phân trang nhảy bước: 1,2,3,4,5, 10,15,...,95, 100,200,..., n
  get pageList() {
    const n = this.totalPages;
    const pages = new Set();
    for (let i = 1; i <= Math.min(5, n); i++) {
      pages.add(i);
    }
    for (let i = 10; i < Math.min(100, n); i += 5) {
      pages.add(i);
    }
    for (let i = 100; i <= n; i += 100) {
      pages.add(i);
    }
    pages.add(n);
    pages.add(this.currentPage);
    return [...pages]
      .sort((a, b) => a - b)
      .map((p) => ({ num: p, current: p === this.currentPage }));
  }

  get hasPrev() {
    return this.currentPage > 1;
  }

  get hasNext() {
    return this.currentPage < this.totalPages;
  }

  async loadFacets() {
    const data = {};
    if (this.sDistricts.length) {
      data.district = this.sDistricts.join(",");
    }
    try {
      this.facets = await ajax("/listing/facets.json", { data });
    } catch {
      this.facets = {};
    }
  }

  priceToVnd(v) {
    if (v === "" || v === null) {
      return null;
    }
    const rate =
      this.fPriceUnit === "usd"
        ? this.siteSettings.sitetor_listing_usd_rate || 26000
        : PRICE_UNITS[this.fPriceUnit] || 1e6;
    return Number(v) * rate;
  }

  @action
  updateField(name, event) {
    this[name] = event.target.value;
  }

  @action
  onQKeydown(event) {
    if (event.key === "Enter") {
      this.applyFilter();
    }
  }

  @action
  setSelection(name, values) {
    this[name] = values;
    if (name === "sDistricts") {
      // cascade: đổi quận → nạp lại danh sách phường/đường
      this.sWards = [];
      this.sStreets = [];
      this.loadFacets();
    }
  }

  // gom bộ lọc đang nhập thành object queryParams (dùng chung cho trang
  // /listing lẫn trang SEO — trang SEO transition sang /listing với object này)
  collectFilterParams() {
    const num = (v) => (v === "" || v === null ? null : Number(v));
    const csv = (arr) => (arr.length ? arr.join(",") : null);
    return {
      q: this.fQ || null,
      price_min: this.priceToVnd(this.fPriceMin),
      price_max: this.priceToVnd(this.fPriceMax),
      frontage_min: num(this.fFrontageMin),
      frontage_max: num(this.fFrontageMax),
      area_min: num(this.fAreaMin),
      area_max: num(this.fAreaMax),
      category_id: this.fCategoryId || null,
      sort: this.fSort === "new" ? null : this.fSort,
      type: csv(this.sTypes),
      position: csv(this.sPositions),
      direction: csv(this.sDirections),
      province: csv(this.sProvinces),
      district: csv(this.sDistricts),
      ward: csv(this.sWards),
      street: csv(this.sStreets),
      page: 0,
    };
  }

  // trang SEO gọi để đổ bộ lọc từ path đã parse vào UI
  prefillFromParsed(parsed) {
    if (!parsed) {
      return;
    }
    this.fCategoryId = parsed.category_id ? String(parsed.category_id) : "";
    this.sTypes = parsed.type ? [parsed.type] : [];
    this.sPositions = parsed.position ? [parsed.position] : [];
    this.sDirections = parsed.direction ? [parsed.direction] : [];
    this.sDistricts = parsed.district ? [parsed.district] : [];
    this.sWards = parsed.ward ? [parsed.ward] : [];
    this.sStreets = parsed.street ? [parsed.street] : [];
    this.page = parsed.page || 0;
    this.loadFacets();
  }

  @action
  applyFilter() {
    const p = this.collectFilterParams();
    for (const [k, v] of Object.entries(p)) {
      this[k] = v;
    }
  }

  @action
  resetFilter() {
    this.fQ = "";
    this.fPriceMin = this.fPriceMax = this.fFrontageMin = this.fFrontageMax = this.fAreaMin = this.fAreaMax = "";
    this.fPriceUnit = "million";
    this.fCategoryId = "";
    this.fSort = "new";
    this.sTypes = [];
    this.sPositions = [];
    this.sDirections = [];
    this.sProvinces = [];
    this.sDistricts = [];
    this.sWards = [];
    this.sStreets = [];
    this.applyFilter();
    this.loadFacets();
  }

  @action
  goPage(p) {
    this.page = p - 1;
  }

  @action
  prevPage() {
    if (this.hasPrev) {
      this.page = Number(this.page) - 1;
    }
  }

  @action
  nextPage() {
    if (this.hasNext) {
      this.page = Number(this.page) + 1;
    }
  }
}

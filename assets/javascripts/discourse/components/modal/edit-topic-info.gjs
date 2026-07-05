import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { eq } from "discourse/truth-helpers";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

// giữ đồng bộ với SitetorListing::SeoSlugs::TYPES/POSITIONS/DIRECTIONS (server)
const TYPES = [
  "Nhà mặt phố", "Nhà hẻm", "Văn phòng", "Kho, nhà xưởng",
  "Căn hộ, chung cư", "Bán đất", "Tầng thương mại",
];
const POSITIONS = ["Mặt tiền", "Đường Nội Bộ", "Hẻm", "Khu Compound"];
const DIRECTIONS = ["Đông", "Tây", "Nam", "Bắc", "Đông Nam", "Đông Bắc", "Tây Nam", "Tây Bắc"];

// Form chủ topic tự nhập thông tin BĐS có cấu trúc (thay cho parser).
export default class EditTopicInfoModal extends Component {
  @tracked loading = true;
  @tracked saving = false;
  @tracked saved = false;

  @tracked fPrice = "";
  @tracked fPriceUnit = "million";
  @tracked fFrontage = "";
  @tracked fArea = "";
  @tracked fType = "";
  @tracked fPosition = "";
  @tracked fDirection = "";
  @tracked fStreetNumber = "";
  @tracked fStreet = "";
  @tracked fWard = "";
  @tracked fDistrict = "";
  @tracked fProvince = "";

  types = TYPES;
  positions = POSITIONS;
  directions = DIRECTIONS;

  constructor() {
    super(...arguments);
    this.load();
  }

  async load() {
    try {
      const info = await ajax("/listing/topic-info.json", {
        data: { topic_id: this.args.model.topic.id },
      });
      if (info.price) {
        if (info.price >= 1e9) {
          this.fPrice = String(info.price / 1e9);
          this.fPriceUnit = "billion";
        } else {
          this.fPrice = String(info.price / 1e6);
          this.fPriceUnit = "million";
        }
      }
      this.fFrontage = info.frontage ? String(info.frontage) : "";
      this.fArea = info.area ? String(info.area) : "";
      this.fType = info.type || "";
      this.fPosition = info.position || "";
      this.fDirection = info.direction || "";
      this.fStreetNumber = info.street_number || "";
      this.fStreet = info.street || "";
      this.fWard = info.ward || "";
      this.fDistrict = info.district || "";
      this.fProvince = info.province || "";
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loading = false;
    }
  }

  get priceVnd() {
    if (this.fPrice === "" || this.fPrice === null) {
      return "";
    }
    const rate =
      this.fPriceUnit === "usd"
        ? this.args.model.usdRate || 26000
        : { million: 1e6, billion: 1e9 }[this.fPriceUnit] || 1e6;
    return Number(this.fPrice) * rate;
  }

  @action
  updateField(name, event) {
    this[name] = event.target.value;
  }

  @action
  async save() {
    this.saving = true;
    try {
      await ajax("/listing/topic-info.json", {
        type: "PUT",
        data: {
          topic_id: this.args.model.topic.id,
          price: this.priceVnd,
          frontage: this.fFrontage,
          area: this.fArea,
          type: this.fType,
          position: this.fPosition,
          direction: this.fDirection,
          street_number: this.fStreetNumber,
          street: this.fStreet,
          ward: this.fWard,
          district: this.fDistrict,
          province: this.fProvince,
        },
      });
      this.saved = true;
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.saving = false;
    }
  }

  <template>
    <DModal
      @title={{i18n "sitetor_listing.edit_info_title"}}
      @closeModal={{@closeModal}}
      class="edit-topic-info-modal"
    >
      <:body>
        {{#if this.loading}}
          <p>…</p>
        {{else if this.saved}}
          <p class="edit-info-saved">✅ {{i18n "sitetor_listing.edit_info_saved"}}</p>
        {{else}}
          <p class="edit-info-hint">{{i18n "sitetor_listing.edit_info_hint"}}</p>

          <div class="edit-info-grid">
            <div class="edit-info-field edit-info-price">
              <label>{{i18n "sitetor_listing.price"}}</label>
              <div class="edit-info-row">
                <Input @value={{this.fPrice}} @type="number" min="0" />
                <select {{on "change" (fn this.updateField "fPriceUnit")}}>
                  <option value="million" selected={{eq this.fPriceUnit "million"}}>{{i18n "sitetor_listing.million"}}</option>
                  <option value="billion" selected={{eq this.fPriceUnit "billion"}}>{{i18n "sitetor_listing.billion"}}</option>
                  <option value="usd" selected={{eq this.fPriceUnit "usd"}}>USD</option>
                </select>
              </div>
            </div>

            <div class="edit-info-field">
              <label>{{i18n "sitetor_listing.frontage"}} (m)</label>
              <Input @value={{this.fFrontage}} @type="number" min="0" step="0.1" />
            </div>

            <div class="edit-info-field">
              <label>{{i18n "sitetor_listing.area"}} (m²)</label>
              <Input @value={{this.fArea}} @type="number" min="0" step="0.1" />
            </div>

            <div class="edit-info-field">
              <label>{{i18n "sitetor_listing.product_type"}}</label>
              <select {{on "change" (fn this.updateField "fType")}}>
                <option value="" selected={{eq this.fType ""}}>—</option>
                {{#each this.types as |v|}}
                  <option value={{v}} selected={{eq this.fType v}}>{{v}}</option>
                {{/each}}
              </select>
            </div>

            <div class="edit-info-field">
              <label>{{i18n "sitetor_listing.position"}}</label>
              <select {{on "change" (fn this.updateField "fPosition")}}>
                <option value="" selected={{eq this.fPosition ""}}>—</option>
                {{#each this.positions as |v|}}
                  <option value={{v}} selected={{eq this.fPosition v}}>{{v}}</option>
                {{/each}}
              </select>
            </div>

            <div class="edit-info-field">
              <label>{{i18n "sitetor_listing.direction"}}</label>
              <select {{on "change" (fn this.updateField "fDirection")}}>
                <option value="" selected={{eq this.fDirection ""}}>—</option>
                {{#each this.directions as |v|}}
                  <option value={{v}} selected={{eq this.fDirection v}}>{{v}}</option>
                {{/each}}
              </select>
            </div>

            <div class="edit-info-field">
              <label>{{i18n "sitetor_listing.street_number"}}</label>
              <Input @value={{this.fStreetNumber}} />
            </div>

            <div class="edit-info-field">
              <label>{{i18n "sitetor_listing.street"}}</label>
              <Input @value={{this.fStreet}} />
            </div>

            <div class="edit-info-field">
              <label>{{i18n "sitetor_listing.ward"}}</label>
              <Input @value={{this.fWard}} />
            </div>

            <div class="edit-info-field">
              <label>{{i18n "sitetor_listing.district"}}</label>
              <Input @value={{this.fDistrict}} />
            </div>

            <div class="edit-info-field">
              <label>{{i18n "sitetor_listing.province"}}</label>
              <Input @value={{this.fProvince}} />
            </div>
          </div>

          <p class="edit-info-note">{{i18n "sitetor_listing.edit_info_note"}}</p>
        {{/if}}
      </:body>
      <:footer>
        {{#unless this.saved}}
          <DButton
            @action={{this.save}}
            @label="sitetor_listing.edit_info_save"
            @disabled={{this.saving}}
            class="btn-primary"
          />
        {{/unless}}
        <DButton @action={{@closeModal}} @label="sitetor_listing.close" />
      </:footer>
    </DModal>
  </template>
}

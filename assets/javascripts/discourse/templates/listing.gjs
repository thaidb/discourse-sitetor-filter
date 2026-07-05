import { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";
import MultiSelect from "discourse/plugins/discourse-sitetor-listing/discourse/components/multi-select";

// 25000000 → "25 tr" ; 5500000000 → "5,5 tỷ"
function formatPrice(vnd) {
  if (!vnd) {
    return "—";
  }
  const n = Number(vnd);
  if (n >= 1e9) {
    return `${(n / 1e9).toLocaleString("vi-VN", { maximumFractionDigits: 2 })} tỷ`;
  }
  return `${(n / 1e6).toLocaleString("vi-VN", { maximumFractionDigits: 1 })} tr`;
}

function orDash(v) {
  return v ?? "—";
}

function eq(a, b) {
  return a === b;
}

export default <template>
  <div class="sitetor-listing">
    {{! tiêu đề là link reset về /listing gốc }}
    <h1><a href="/listing" class="listing-home-link">{{i18n "sitetor_listing.title"}}</a></h1>

    <div class="listing-filters">
      <div class="listing-filter-row">
        <div class="listing-filter-group listing-filter-q">
          <Input
            @value={{@controller.fQ}}
            placeholder={{i18n "sitetor_listing.search_hint"}}
            {{on "keydown" @controller.onQKeydown}}
          />
        </div>

        <div class="listing-filter-group">
          <label>{{i18n "sitetor_listing.category"}}</label>
          <select {{on "change" (fn @controller.updateField "fCategoryId")}}>
            <option value="" selected={{eq @controller.fCategoryId ""}}>
              {{i18n "sitetor_listing.all"}}
            </option>
            {{#each @controller.categoryOptions as |c|}}
              <option value={{c.id}} selected={{eq @controller.fCategoryId c.id}}>{{c.name}}</option>
            {{/each}}
          </select>
        </div>

        <MultiSelect
          @label={{i18n "sitetor_listing.product_type"}}
          @options={{@controller.facets.type}}
          @selected={{@controller.sTypes}}
          @onChange={{fn @controller.setSelection "sTypes"}}
        />
        <MultiSelect
          @label={{i18n "sitetor_listing.province"}}
          @options={{@controller.facets.province}}
          @selected={{@controller.sProvinces}}
          @onChange={{fn @controller.setSelection "sProvinces"}}
        />
        <MultiSelect
          @label={{i18n "sitetor_listing.district"}}
          @options={{@controller.facets.district}}
          @selected={{@controller.sDistricts}}
          @onChange={{fn @controller.setSelection "sDistricts"}}
          @searchable={{true}}
        />
        <MultiSelect
          @label={{i18n "sitetor_listing.ward"}}
          @options={{@controller.facets.ward}}
          @selected={{@controller.sWards}}
          @onChange={{fn @controller.setSelection "sWards"}}
          @searchable={{true}}
        />
        <MultiSelect
          @label={{i18n "sitetor_listing.street"}}
          @options={{@controller.facets.street}}
          @selected={{@controller.sStreets}}
          @onChange={{fn @controller.setSelection "sStreets"}}
          @searchable={{true}}
        />
        <MultiSelect
          @label={{i18n "sitetor_listing.position"}}
          @options={{@controller.facets.position}}
          @selected={{@controller.sPositions}}
          @onChange={{fn @controller.setSelection "sPositions"}}
        />
        <MultiSelect
          @label={{i18n "sitetor_listing.direction"}}
          @options={{@controller.facets.direction}}
          @selected={{@controller.sDirections}}
          @onChange={{fn @controller.setSelection "sDirections"}}
        />
      </div>

      <div class="listing-filter-row">
        <div class="listing-filter-group">
          <label>{{i18n "sitetor_listing.price"}}</label>
          <Input @value={{@controller.fPriceMin}} @type="number" placeholder={{i18n "sitetor_listing.from"}} />
          <span>–</span>
          <Input @value={{@controller.fPriceMax}} @type="number" placeholder={{i18n "sitetor_listing.to"}} />
          <select {{on "change" (fn @controller.updateField "fPriceUnit")}}>
            <option value="million" selected={{eq @controller.fPriceUnit "million"}}>{{i18n "sitetor_listing.million"}}</option>
            <option value="billion" selected={{eq @controller.fPriceUnit "billion"}}>{{i18n "sitetor_listing.billion"}}</option>
            <option value="usd" selected={{eq @controller.fPriceUnit "usd"}}>USD</option>
          </select>
        </div>

        <div class="listing-filter-group">
          <label>{{i18n "sitetor_listing.frontage"}} (m)</label>
          <Input @value={{@controller.fFrontageMin}} @type="number" placeholder="min" />
          <span>–</span>
          <Input @value={{@controller.fFrontageMax}} @type="number" placeholder="max" />
        </div>

        <div class="listing-filter-group">
          <label>{{i18n "sitetor_listing.area"}} (m²)</label>
          <Input @value={{@controller.fAreaMin}} @type="number" placeholder="min" />
          <span>–</span>
          <Input @value={{@controller.fAreaMax}} @type="number" placeholder="max" />
        </div>

        <div class="listing-filter-group">
          <label>{{i18n "sitetor_listing.sort_by"}}</label>
          <select {{on "change" (fn @controller.updateField "fSort")}}>
            <option value="new" selected={{eq @controller.fSort "new"}}>{{i18n "sitetor_listing.newest"}}</option>
            <option value="price_asc" selected={{eq @controller.fSort "price_asc"}}>{{i18n "sitetor_listing.price_asc"}}</option>
            <option value="price_desc" selected={{eq @controller.fSort "price_desc"}}>{{i18n "sitetor_listing.price_desc"}}</option>
            <option value="area_desc" selected={{eq @controller.fSort "area_desc"}}>{{i18n "sitetor_listing.area_desc"}}</option>
          </select>
        </div>

        <DButton
          @action={{@controller.applyFilter}}
          @icon="magnifying-glass"
          @label="sitetor_listing.apply_filter"
          class="btn-primary"
        />
        <DButton @action={{@controller.resetFilter}} @label="sitetor_listing.reset_filter" />
      </div>
    </div>

    <p class="listing-total">
      {{i18n "sitetor_listing.total_found" count=@controller.total}}
      · {{i18n "sitetor_listing.page_of" page=@controller.currentPage total=@controller.totalPages}}
      {{#if @controller.model.seo_base}}
        · <a class="listing-seo-link" href="/listing/{{@controller.model.seo_base}}">
          🔗 {{i18n "sitetor_listing.seo_page"}}
        </a>
      {{/if}}
    </p>

    <div class="listing-table-wrap">
      <table class="listing-table">
        <thead>
          <tr>
            <th>ID</th>
            <th>{{i18n "sitetor_listing.product_type"}}</th>
            <th>{{i18n "sitetor_listing.street_number"}}</th>
            <th>{{i18n "sitetor_listing.street"}}</th>
            <th>{{i18n "sitetor_listing.ward"}}</th>
            <th>{{i18n "sitetor_listing.district"}}</th>
            <th>{{i18n "sitetor_listing.price"}}</th>
            <th>{{i18n "sitetor_listing.frontage"}}</th>
          </tr>
        </thead>
        <tbody>
          {{#each @controller.topics as |t|}}
            <tr>
              <td class="listing-num">
                <a href="/t/{{t.slug}}/{{t.id}}" title={{t.title}}>{{t.id}}</a>
              </td>
              <td>{{orDash t.type}}</td>
              <td class="listing-num">{{orDash t.street_number}}</td>
              <td><a href="/t/{{t.slug}}/{{t.id}}" title={{t.title}}>{{orDash t.street}}</a></td>
              <td>{{orDash t.ward}}</td>
              <td>{{orDash t.district}}</td>
              <td class="listing-num">{{formatPrice t.price}}</td>
              <td class="listing-num">{{orDash t.frontage}}</td>
            </tr>
          {{else}}
            <tr><td colspan="8">{{i18n "sitetor_listing.no_results"}}</td></tr>
          {{/each}}
        </tbody>
      </table>
    </div>

    {{! phân trang nhảy bước: 1,2,3,4,5 ... 10,15,20 ... 100,200 ... n }}
    <div class="listing-paging">
      <DButton
        @action={{@controller.prevPage}}
        @disabled={{unless @controller.hasPrev true}}
        @label="sitetor_listing.prev"
      />
      <span class="listing-page-list">
        {{#each @controller.pageList as |p|}}
          {{#if p.current}}
            <span class="listing-page listing-page-current">{{p.num}}</span>
          {{else}}
            <button
              type="button"
              class="listing-page"
              {{on "click" (fn @controller.goPage p.num)}}
            >{{p.num}}</button>
          {{/if}}
        {{/each}}
      </span>
      <DButton
        @action={{@controller.nextPage}}
        @disabled={{unless @controller.hasNext true}}
        @label="sitetor_listing.next"
      />
    </div>
  </div>
</template>

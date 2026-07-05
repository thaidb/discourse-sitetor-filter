import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { i18n } from "discourse-i18n";

// Plain checkbox multi-select dropdown (details/summary, no select-kit
// dependency) with a quick-search box for long lists (streets ~500 items).
// Closes automatically when clicking anywhere outside the dropdown.
// args: @label, @options [{value, count}], @selected [string], @onChange(values)
export default class MultiSelect extends Component {
  @tracked filterText = "";

  element = null;

  @action
  setupOutsideClose(element) {
    this.element = element;
    this.outsideHandler = (event) => {
      if (this.element?.open && !this.element.contains(event.target)) {
        this.element.open = false;
      }
    };
    document.addEventListener("pointerdown", this.outsideHandler, true);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    if (this.outsideHandler) {
      document.removeEventListener("pointerdown", this.outsideHandler, true);
    }
  }

  get filtered() {
    const opts = this.args.options || [];
    const q = this.filterText.trim().toLowerCase();
    return q ? opts.filter((o) => o.value.toLowerCase().includes(q)) : opts;
  }

  get selectedCount() {
    return (this.args.selected || []).length;
  }

  isChecked = (value) => (this.args.selected || []).includes(value);

  @action
  toggle(value) {
    const cur = this.args.selected || [];
    const next = cur.includes(value)
      ? cur.filter((v) => v !== value)
      : [...cur, value];
    this.args.onChange(next);
  }

  @action
  updateFilter(event) {
    this.filterText = event.target.value;
  }

  <template>
    <details class="listing-ms" {{didInsert this.setupOutsideClose}}>
      <summary>
        {{@label}}{{#if this.selectedCount}}
          <span class="listing-ms-count">{{this.selectedCount}}</span>
        {{/if}}
        <span class="listing-ms-caret">▾</span>
      </summary>
      <div class="listing-ms-panel">
        {{#if @searchable}}
          <input
            type="text"
            class="listing-ms-search"
            placeholder={{i18n "sitetor_listing.quick_search"}}
            {{on "input" this.updateFilter}}
          />
        {{/if}}
        <ul>
          {{#each this.filtered as |o|}}
            <li>
              <label>
                <input
                  type="checkbox"
                  checked={{this.isChecked o.value}}
                  {{on "change" (fn this.toggle o.value)}}
                />
                <span class="listing-ms-value">{{o.value}}</span>
                <span class="listing-ms-c">({{o.count}})</span>
              </label>
            </li>
          {{else}}
            <li class="listing-ms-empty">{{i18n "sitetor_listing.no_options"}}</li>
          {{/each}}
        </ul>
      </div>
    </details>
  </template>
}

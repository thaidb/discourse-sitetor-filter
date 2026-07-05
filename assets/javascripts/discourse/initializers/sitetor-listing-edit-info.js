import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import EditTopicInfoModal from "discourse/plugins/discourse-sitetor-listing/discourse/components/modal/edit-topic-info";


// mở rộng danh sách category gồm cả sub/sub-sub (đồng bộ với with_descendants server)
function expandWithDescendants(ids, categories) {
  const set = new Set(ids);
  let changed = true;
  while (changed) {
    changed = false;
    for (const c of categories || []) {
      if (c.parent_category_id && set.has(c.parent_category_id) && !set.has(c.id)) {
        set.add(c.id);
        changed = true;
      }
    }
  }
  return set;
}

// Nút "Cập nhật thông tin BĐS" dưới chân topic (chủ topic / staff):
// mở form nhập giá, diện tích, mặt tiền, loại SP, vị trí, hướng, địa chỉ.
export default {
  name: "sitetor-listing-edit-info",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    if (!siteSettings.sitetor_listing_enabled) {
      return;
    }

    const categoryIds = (
      (siteSettings.sitetor_listing_categories || "") +
      "|" +
      (siteSettings.sitetor_listing_demand_categories || "")
    )
      .split("|")
      .map((s) => parseInt(s, 10))
      .filter(Boolean);

    withPluginApi((api) => {
      api.registerTopicFooterButton({
        id: "listing-edit-info",
        icon: "pencil",
        priority: 245,
        translatedLabel() {
          return i18n("sitetor_listing.edit_info");
        },
        translatedTitle() {
          return i18n("sitetor_listing.edit_info");
        },
        displayed() {
          return (
            !!this.currentUser &&
            expandWithDescendants(categoryIds, this.site?.categories).has(
              this.topic?.category_id
            ) &&
            !!this.topic?.details?.can_edit
          );
        },
        action() {
          container.lookup("service:modal").show(EditTopicInfoModal, {
            model: {
              topic: this.topic,
              usdRate: siteSettings.sitetor_listing_usd_rate,
            },
          });
        },
      });
    });
  },
};

import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import DemandInfoModal from "discourse/plugins/discourse-sitetor-listing/discourse/components/modal/demand-info";
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

function parseIds(setting) {
  return (setting || "")
    .split("|")
    .map((s) => parseInt(s, 10))
    .filter(Boolean);
}

// Nút edit dưới chân topic (chủ topic / staff), rẽ nhánh theo category:
// - category listing (Bán/Cho thuê)  → "Cập nhật thông tin BĐS"      → EditTopicInfoModal
// - category demand (Cần mua/Cần thuê) → "Cập nhật thông tin nhu cầu" → DemandInfoModal
export default {
  name: "sitetor-listing-edit-info",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    if (!siteSettings.sitetor_listing_enabled) {
      return;
    }

    const listingIds = parseIds(siteSettings.sitetor_listing_categories);
    const demandIds = parseIds(siteSettings.sitetor_listing_demand_categories);

    // category nằm trong cả 2 setting → ưu tiên flow listing (giữ hành vi cũ)
    const inListing = (ctx) =>
      expandWithDescendants(listingIds, ctx.site?.categories).has(
        ctx.topic?.category_id
      );
    const inDemand = (ctx) =>
      !inListing(ctx) &&
      expandWithDescendants(demandIds, ctx.site?.categories).has(
        ctx.topic?.category_id
      );

    withPluginApi((api) => {
      api.registerTopicFooterButton({
        id: "listing-edit-info",
        icon: "pencil",
        priority: 245,
        translatedLabel() {
          return i18n(
            inDemand(this)
              ? "sitetor_listing.edit_demand_info"
              : "sitetor_listing.edit_info"
          );
        },
        translatedTitle() {
          return i18n(
            inDemand(this)
              ? "sitetor_listing.edit_demand_info"
              : "sitetor_listing.edit_info"
          );
        },
        displayed() {
          return (
            !!this.currentUser &&
            (inListing(this) || inDemand(this)) &&
            !!this.topic?.details?.can_edit
          );
        },
        action() {
          const modal = container.lookup("service:modal");
          if (inDemand(this)) {
            modal.show(DemandInfoModal, {
              model: { topic: this.topic },
            });
          } else {
            modal.show(EditTopicInfoModal, {
              model: {
                topic: this.topic,
                usdRate: siteSettings.sitetor_listing_usd_rate,
              },
            });
          }
        },
      });
    });
  },
};

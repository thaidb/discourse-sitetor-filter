import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";

// Thêm link "Tìm bất động sản" vào sidebar (mục Cộng đồng) — bấm từ bất kỳ
// trang nào cũng quay về /listing (bộ lọc gốc, không query param).
export default {
  name: "sitetor-filter-sidebar",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    if (!siteSettings.sitetor_filter_enabled) {
      return;
    }

    withPluginApi((api) => {
      api.addCommunitySectionLink((baseSectionLink) => {
        return class SitetorFilterSectionLink extends baseSectionLink {
          name = "sitetor-listing";
          route = "listing";
          text = i18n("sitetor_filter.title");
          title = i18n("sitetor_filter.title");
          defaultPrefixValue = "magnifying-glass";
        };
      });
    });
  },
};

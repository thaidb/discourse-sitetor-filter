import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";

export default class ListingRoute extends DiscourseRoute {
  queryParams = {
    q: { refreshModel: true },
    price_min: { refreshModel: true },
    price_max: { refreshModel: true },
    frontage_min: { refreshModel: true },
    frontage_max: { refreshModel: true },
    area_min: { refreshModel: true },
    area_max: { refreshModel: true },
    category_id: { refreshModel: true },
    sort: { refreshModel: true },
    page: { refreshModel: true },
    type: { refreshModel: true },
    position: { refreshModel: true },
    direction: { refreshModel: true },
    province: { refreshModel: true },
    district: { refreshModel: true },
    ward: { refreshModel: true },
    street: { refreshModel: true },
  };

  model(params) {
    return ajax("/listing/filter.json", { data: params });
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    // nạp options cho các dropdown multi-select (1 lần khi vào trang)
    if (!controller.facets?.type) {
      controller.loadFacets();
    }
  }
}

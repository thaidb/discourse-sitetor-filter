export default function () {
  this.route("listing");
  // SEO filter pages: /listing/ban/nha-mat-pho/district-3/street-vo-van-tan
  this.route("listing-seo", { path: "/listing/*filters" });
}

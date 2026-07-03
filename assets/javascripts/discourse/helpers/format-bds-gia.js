import { helper } from "@ember/component/helper";

// 25000000 → "25 tr" ; 5500000000 → "5,5 tỷ"
export default helper(function ([vnd]) {
  if (!vnd) {
    return "—";
  }
  const n = Number(vnd);
  if (n >= 1e9) {
    return `${(n / 1e9).toLocaleString("vi-VN", { maximumFractionDigits: 2 })} tỷ`;
  }
  return `${(n / 1e6).toLocaleString("vi-VN", { maximumFractionDigits: 1 })} tr`;
});

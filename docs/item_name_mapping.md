# item_name 매핑 기록

purchase 이벤트의 `item_name` 표기가 view_item/add_to_cart와 달라 상품 퍼널에서 구매가 누락되는 상품을 수동으로 매핑한 기록입니다. 매핑은 이름 유사성을 보고 사람이 정했으며, 자동 매칭은 사용하지 않았습니다. 근거 쿼리는 `sql/06b_join_gap_check.sql`, `sql/06c_unmatched_names.sql`, `sql/06d_mapping_verify.sql`입니다 (기간 2020-11-01 ~ 2021-01-31).

## 적용한 매핑 (신뢰도: 높음)

`sql/06_item_funnel.sql`의 CASE 정규화로 purchase 쪽 이름을 조회/장바구니 쪽 이름으로 바꿔서 집계합니다.

| purchase 쪽 이름 (변경 전) | 조회/장바구니 쪽 이름 (변경 후) | purchase item_revenue | purchase 유저 |
|---|---|---|---|
| Google F/C Longsleeve Charcoal | Google F/C Long Sleeve Tee Charcoal | 4,548 | 117 |
| Google F/C Longsleeve Ash | Google F/C Long Sleeve Tee Ash | 3,738 | 121 |
| Womens Google Striped LS | Google Women's Striped L/S | 1,525 | 79 |

- 세 건의 item_revenue 합은 9,811로, purchase 전체 item_revenue(362,110)의 약 2.7%입니다.
- 판단 근거는 표기 차이(`Longsleeve` ↔ `Long Sleeve Tee`, `Womens ... LS` ↔ `Women's ... L/S`)와 색상 일치입니다. item_id로 확인한 근거는 없습니다. view_item과 purchase는 item_id 체계가 달라 ID 공유 여부로는 검증할 수 없습니다.

## 검토했으나 적용하지 않은 매핑 (신뢰도: 중간)

| purchase 쪽 이름 | 조회/장바구니 쪽 이름 | 공유 item_id | 비고 |
|---|---|---|---|
| Google Unisex Eco Tee Black | Google Eco Tee Black | 0건 | purchase ID 7개(9195549~9195555), browse ID 2개(9195556, GGOEGXXX1189) |
| Unisex Google Pocket Tee Grey | Google Pocket Tee Grey | 0건 | purchase ID 6개(9195878~9195883), browse ID 2개(9195856, GGOEGXXX1175) |

- 공유 ID가 없다고 해서 다른 상품이라는 뜻은 아닙니다 (이벤트 간 ID 체계가 달라 원래 겹치지 않음).
- Eco Tee Black은 browse의 숫자 ID(9195556)가 purchase ID 범위 바로 다음 값이라 같은 상품군일 가능성이 있으나, 정황일 뿐 확정 근거는 아닙니다. Pocket Tee Grey는 browse 숫자 ID(9195856)가 purchase 범위와 떨어져 있습니다.

## 매핑하지 않은 이름

- purchase에만 있음: Google Summer19 Crew Grey, Youth Jumbo Print Tee White, Unisex Google Jumbo Print Tee White (조회/장바구니 쪽에 대응할 이름이 보이지 않음)
- 조회/장바구니에만 있고 장바구니 유저 500명 이상: Google Land & Sea Unisex Tee, Google Cloud  Unisex Zip Hoodie, Google Black Tee, Google Unisex Pride Eco-Tee Black (purchase 쪽에 대응할 이름이 보이지 않음)

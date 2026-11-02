# 지표 정의

분석에 쓰는 지표의 정의와 집계 규칙, 알려진 한계를 정리한 문서입니다. 이 데이터셋은 난독화(obfuscated)된 샘플이라 절대값은 실제 Google Merchandise Store와 다를 수 있으며, 아래 수치는 모두 `_TABLE_SUFFIX BETWEEN '20201101' AND '20210131'` 기준입니다.

**교집합 정의:** 퍼널의 각 단계 유저 수는 해당 단계와 앞선 모든 단계의 이벤트를 하나라도 경험한 유저(상품 퍼널은 유저×상품 단위)의 수이며, 이벤트 발생 순서와 세션은 반영하지 않는다.

## 1. 구매 유저 수: 4,419 / 2,915 / 4,400

같은 "구매 유저"라도 쿼리마다 모수가 다릅니다. 세 수치는 서로 모순되는 것이 아니라 필터 조건이 다릅니다.

| 수치 | 정의 | 사용처 |
|---|---|---|
| **4,419명** | `purchase` 이벤트가 1건이라도 있는 유저 (이벤트 존재 여부만 확인, 퍼널 앞 단계 이력은 따지지 않음) | 기존 독립 집계 퍼널, README 데이터 섹션 |
| **2,915명** | `view_item` → `add_to_cart` → `begin_checkout` → `purchase`를 **모두 경험한** 유저 (이벤트 경험의 교집합, 시간 순서는 미반영) | 퍼널(`sql/03_conversion_funnel.sql`), 대시보드 KPI, 전체 구매 전환율 |
| **4,400명** | `purchase` 이벤트 중 `ecommerce.transaction_id IS NOT NULL`인 건이 있는 유저 | 매출 집중도(Pareto), 빈도×금액 세그먼트 (`sql/04_customer_segments.sql`) |

- 4,419와 4,400의 차이(19명)는 `transaction_id` 필터에서 생깁니다. 두 쿼리의 필터 조건이 다르다는 정의상의 차이이며, 19명의 원인(transaction_id 누락 purchase)을 개별로 검증하지는 않았습니다.
- 2,915는 4,419보다 작습니다. 퍼널 앞 단계 이벤트(view_item, add_to_cart, begin_checkout)가 기록되지 않은 구매자가 많기 때문입니다. GA4의 세션 끊김, 기기 교체 등으로 이벤트가 누락되었을 가능성이 있어 실제 전환율은 본 분석보다 다소 높을 수 있습니다.
- 전체 구매 전환율 1.08% = 2,915 / 270,154 (전체 방문자).

## 2. 상품 단위: item_name 기준, variant 합산

`item_id`는 이벤트마다 형식이 다릅니다 (`sql/05b_item_id_check.sql`).

| 이벤트 | GGOE 접두사 | 숫자만 | 그 외 |
|---|---|---|---|
| view_item | 92.7% | 0.0003% | 7.3% |
| add_to_cart | 89.2% | 4.6% | 6.2% |
| purchase | 0% | 97.2% | 2.8% |

- view_item ∩ purchase의 distinct `item_id`는 5개뿐이라 `item_id`로 조회와 구매를 조인할 수 없습니다.
- 구매 쪽 숫자 ID는 한 상품이 5~7개로 갈라지는 패턴이 있습니다 (예: `Super G Unisex Joggers`는 view_item 1개 ID, purchase 숫자 ID 6개). 사이즈·색상 같은 옵션(variant) 단위 ID로 보이나, 이는 패턴에 근거한 추정입니다.
- **규칙: 상품 단위 분석은 `item_name`을 키로 하고, 같은 `item_name`에 속하는 모든 variant(item_id)를 합산한다.**
- 근거 (`sql/05c_item_name_check.sql`): distinct `item_name` 430개 중 세 이벤트 모두에 등장하는 이름이 386개입니다. `item_id` 1,375개 중 `item_name`이 2개인 ID는 6개(0.44%)로, 키 충돌은 미미합니다.
- 반대 방향(서로 다른 상품이 같은 `item_name`을 쓰는 경우)은 검증하지 않았습니다.

## 3. 상품 매출 집계 규칙 (item_revenue)

- **상품별 매출은 `SUM(item.item_revenue)`로 집계한다.**
- `UNNEST(items)` 후 `ecommerce.purchase_revenue`를 합산하면 이벤트 매출이 item 행마다 중복되어 부풀려진다. purchase 5,692건이 item 16,003행으로 펼쳐지며, 단순 합산 시 1,641,077로 실제(362,165)의 **4.53배**가 됩니다.
- 정합성: `SUM(item_revenue)` 362,110 vs `SUM(ecommerce.purchase_revenue)` 362,165 (비율 0.9998, 차이 55). 차이의 원인은 확인하지 않았습니다.
- 이벤트 단위 매출(유저별 총매출 등)은 `ecommerce.purchase_revenue`를 UNNEST 없이 집계한다.
- 일부 유저는 `purchase_revenue`가 NULL이라 합계가 NULL이 된다 (4,400명 중 353명). 금액대 세그먼트에서는 `COALESCE(revenue, 0)`으로 처리해 Low로 분류한다 (NULL이 `ELSE 'VIP'`로 빠지는 것을 방지).

## 3-1. 카테고리(item_category) 집계 규칙

- purchase 이벤트의 `item_category`는 `Apparel`, `New`, `Shop by Brand`처럼 평평한 분류이고, view_item/add_to_cart는 `Home/Apparel/`, `Lifestyle/Drinkware/`처럼 경로형(끝이 `/`)이다. 두 분류는 문자열이 겹치지 않아 `item_category`로 직접 조인하면 구매 유저가 0으로 나온다.
- **규칙: 카테고리 분석은 view_item/add_to_cart의 경로형 `item_category`를 `item_name`에 매핑해 사용한다.** 한 상품이 여러 카테고리에 속하면 각각에 집계하므로 카테고리 간 합계는 의미가 없다.
- 카테고리 퍼널은 유저×카테고리 단위로 판정(카테고리 내 어떤 상품이든 조회→장바구니→구매)하므로, 같은 상품 기준인 상품 퍼널보다 전환율이 높게 나온다. 두 퍼널의 전환율을 직접 비교하지 않는다.

## 3-2. item_name 표기 불일치와 보정 규모

`item_name`도 이벤트 간 표기가 다른 경우가 있어 purchase와 조회/장바구니가 연결되지 않는 상품이 있습니다 (`sql/06b_join_gap_check.sql`, `06c_unmatched_names.sql`).

| 구분 | item_revenue | 전체(362,110) 대비 | 설명 |
|---|---|---|---|
| 이름으로 연결되지 않던 purchase 매출 (상한) | 15,082 | **4.17%** | purchase에만 있고 조회/장바구니에 없는 item_name 8개의 매출 합 |
| 수동 매핑으로 보정한 매출 | 9,811 | **2.7%** | 3건 매핑 적용 (`docs/item_name_mapping.md`) |
| 보정 후에도 연결되지 않는 매출 | 5,271 | 약 1.5% | 미적용 "중간" 2건(4,118, 약 1.1%)과 대응 이름이 보이지 않는 3건 |

- 4.17%는 "purchase 쪽에서 이름으로 연결되지 않는 매출"의 상한이며, 조회/장바구니에만 있는 이름(구매 쪽에 대응 이름이 없는 상품)의 영향은 매출로 환산하지 않았다.
- 매핑하지 않은 상품은 상품 퍼널에서 구매가 0이거나 과소 집계될 수 있으므로 "구매 부진"으로 해석하지 않는다.
- 상품 매출(Pareto)은 매핑 3건을 합산한 `item_name` 기준이며 총합 362,110이 일치하는지 쿼리 안에서 검증한다 (`sql/07_item_revenue_pareto.sql`).

## 3-3. 교집합 정의 (분석 단위별)

- **유저 퍼널**: 유저가 `view_item`, `add_to_cart`, `begin_checkout`, `purchase`를 모두 경험.
- **상품 퍼널**: 유저가 **같은 `item_name`** 을 조회 → 장바구니 → 구매까지 모두 경험 (유저×상품 단위, 매핑 3건 적용, 조회 100명 이상 + 장바구니 500명 이상 상품만).
- **카테고리 퍼널**: 유저가 **카테고리 안의 어떤 상품이든** 조회 → 장바구니 → 구매 (유저×리프 카테고리 단위). 상품 퍼널보다 전환율이 높게 나오므로 직접 비교하지 않는다.
- 모든 퍼널은 이벤트 발생 순서와 세션을 반영하지 않는다.

## 4. 한계: view_item의 items 누락 (37.3%)

| 이벤트 | 전체 이벤트 | items 배열이 빈 이벤트 | 비율 |
|---|---|---|---|
| view_item | 386,068 | 144,192 | **37.3%** |
| add_to_cart | 58,543 | 0 | 0% |
| purchase | 5,692 | 2 | 0.04% |

- 유저 단위 퍼널은 이벤트 존재 여부만 보므로 이 누락의 영향을 받지 않는다.
- 상품 단위 분석에서는 view_item 쪽만 크게 비어 있어 상품별 조회 유저 수가 **과소 집계**된다. 그 결과 상품별 조회→장바구니, 조회→구매 전환율은 **실제보다 높게** 나올 수 있다.
- view_item의 distinct `item_id`(427)가 add_to_cart/purchase(약 800)의 절반 수준인 것도 같은 맥락이다.
- 상품 단위 해석에서는 전환율의 절대 수준보다 상품 간 상대 비교를 우선한다.

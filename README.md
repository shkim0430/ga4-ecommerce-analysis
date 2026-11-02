# GA4 이커머스 분석 포트폴리오

🔗 **라이브 대시보드**: [https://ga4-ecommerce-shkim0430.streamlit.app/](https://ga4-ecommerce-shkim0430.streamlit.app/)
📁 **저장소**: [github.com/shkim0430/ga4-ecommerce-analysis](https://github.com/shkim0430/ga4-ecommerce-analysis)

---

## 프로젝트 소개

GA4 + BigQuery 공개 데이터셋으로 Google Merchandise Store의 이커머스 데이터를 분석한 포트폴리오
프로젝트입니다. 신규/재구매 고객, 구매 전환 퍼널, 채널별 성과, 고객 세그먼트 분석을 통해 매출 개선
우선순위를 도출하는 것을 목표로 합니다.

결론적으로, 이 사이트의 매출 개선 레버리지는 (1) 장바구니 → 체크아웃 이탈 방지, (2) 1회 중가
구매자의 재구매 유도, (3) 전체 유입 전환율 개선 순으로 크며, VIP 리텐션 전략의 우선순위는
상대적으로 낮습니다.

## 데이터

- 소스: `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
- 기간: 2020-11-01 ~ 2021-01-31 (약 3개월)
- 규모: 총 방문자 270,154명 / 구매 이벤트 발생 유저 4,419명 (view→cart→checkout 전 단계 경험
  유저 기준으로는 2,915명) / 이벤트 17종
- 이 데이터셋은 난독화(obfuscated)된 샘플이므로 절대값(매출, 유저 수 등)은 실제 Google
  Merchandise Store 데이터와 다를 수 있습니다. 추세와 상대 비교 중심으로 해석해 주세요.

## 분석 스코프

1. 구매 전환 퍼널 (view_item → add_to_cart → begin_checkout → purchase)
2. 채널(source/medium)별 유입 규모와 성과
3. 월간/주간 코호트 재구매율
4. 매출 집중도 (Pareto 분석)
5. 구매 빈도 × 금액대 세그먼트 매트릭스
6. 상품 단위 전환과 매출 기여

## 핵심 인사이트

**가장 큰 매출 손실 지점은 장바구니 → 체크아웃 구간**
상품을 조회하고 장바구니에 담은 유저 12,539명 중 54.9%가 체크아웃으로 넘어가지 않습니다
(체크아웃 진입 5,656명). 체크아웃 이후 구매 완료율은 51.5%로 상대적으로 양호해, 매출 개선
레버리지는 결제 페이지보다 **장바구니 이탈 방지(저장 알림, 재고 긴급성 노출, 쿠폰 자동 적용
등)에 더 큽니다**.
→ [outputs/figures/01_funnel.png](outputs/figures/01_funnel.png)

**매출의 42%는 "1회 중가 구매자" 하나의 세그먼트에서 발생**
1,623명의 1회 Mid($50~$200) 구매자가 전체 매출의 42.1%를 담당합니다. 이 세그먼트가 사이트의
백본이며, 재구매 유도 대상이자 리텐션 파이프라인의 진입점입니다.
→ [outputs/figures/06_segment_matrix.png](outputs/figures/06_segment_matrix.png)

**매출은 헤비 유저가 아닌 대중 구매자에 의존**
상위 20% 유저가 매출의 56.7%를 차지해, 전형적인 20/80 법칙의 80%와는 거리가 있습니다. 즉
VIP 리텐션 전략보다 전체 구매자 수를 늘리는 전략의 레버리지가 더 큽니다.
→ [outputs/figures/05_pareto.png](outputs/figures/05_pareto.png)

**자체 도메인 리퍼럴 채널의 전환율이 가장 높음**
shop.googlemerchandisestore.com 리퍼럴 채널의 CVR은 2.21%로 다른 유입 채널(1.5% 내외) 대비
0.7%p 높습니다. 이 채널은 GA4에서 결제·로그인 페이지 이동 중 세션이 끊긴 재방문자가 잡히는
경우가 많아, 신규 유입보다 재방문 유저의 구매 의도가 강함을 시사합니다. 다만 이 채널의 절대
규모는 전체 유저의 5% 수준이라, 신규 유입의 전환율 자체를 개선하는 것이 우선 과제입니다.
→ [outputs/figures/04_channel_performance.png](outputs/figures/04_channel_performance.png)

**재구매율은 후반 코호트로 갈수록 개선**
첫 주(W1) 재구매율이 2020-11-02 코호트 2.6%에서 2021-01-18 코호트 3.5%로 상승했습니다.
사이트의 신규→재구매 전환 능력이 시간이 갈수록 나아지고 있음을 시사합니다.
→ [outputs/figures/03_cohort_weekly.png](outputs/figures/03_cohort_weekly.png)

## 실행 방법

```powershell
# 1. gcloud 인증
gcloud auth application-default login

# 2. Python 환경
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt

# 3. 데이터 추출
python src/fetch_data.py

# 4. 시각화 생성
python src/visualize.py
```

## 폴더 구조

```
ga4-ecommerce/
├── sql/                          # BigQuery SQL 분석 스크립트
│   ├── 00_explore.sql            # 테이블 구조 탐색 (날짜 범위, 이벤트 종류, 방문자, 구매 매출)
│   ├── 01_cohort_repurchase.sql  # 월간/주간 코호트 재구매율
│   ├── 02_channel_performance.sql # 채널(source/medium)별 유입과 구매 성과
│   ├── 03_conversion_funnel.sql  # 조회 → 장바구니 → 체크아웃 → 구매 퍼널 (교집합 기준)
│   ├── 04_customer_segments.sql  # 매출 집중도(Pareto)와 빈도×금액 세그먼트
│   ├── 05_item_explore.sql       # items 배열 탐색 (빈 배열 비율, distinct item_id, 카테고리)
│   ├── 05b_item_id_check.sql     # 이벤트별 item_id 형식 분포와 ID 교집합
│   ├── 05c_item_name_check.sql   # item_name 커버리지, item_id 키 충돌, 매출 정합성
│   ├── 06_item_funnel.sql        # 상품·카테고리 단위 조회 → 장바구니 → 구매 퍼널
│   ├── 06b_join_gap_check.sql    # 구매 0건 상품의 item_name 조인 누락 점검
│   ├── 06c_unmatched_names.sql   # 한쪽 이벤트에만 있는 item_name 목록
│   ├── 06d_mapping_verify.sql    # 매핑 후보의 item_id 공유 여부 검증
│   └── 07_item_revenue_pareto.sql # 상품별 매출·수량 순위, 매출 Pareto
├── src/                          # 데이터 추출, 시각화, 대시보드 코드
│   ├── bq_client.py              # BigQuery 클라이언트 래퍼 (ADC 인증)
│   ├── fetch_data.py             # sql/ 실행 → outputs/*.csv 저장
│   ├── visualize.py              # outputs/*.csv → outputs/figures/*.png
│   └── dashboard.py              # outputs/*.csv 기반 Streamlit 대시보드
├── notebooks/                    # 탐색적 분석용 노트북
├── outputs/                      # 쿼리 결과 CSV, 시각화 PNG
│   └── figures/
├── docs/                         # 문서
│   ├── metric_definitions.md     # 지표 정의, 집계 규칙, 데이터 한계
│   └── item_name_mapping.md      # item_name 수동 매핑 기록
├── requirements.txt
├── CLAUDE.md
└── README.md
```

## 기술 스택

BigQuery / Python 3.14 / pandas / google-cloud-bigquery / matplotlib / seaborn

## 한계 및 개선점

- 데이터가 3개월치라 코호트 분석의 관측 기간이 제한적입니다.
- 난독화된 샘플이므로 절대값은 참고용으로만 활용해야 합니다.
- 향후 계획: 주간 KPI 자동 리포트, LLM 기반 Text-to-SQL 기능
- 퍼널 분석은 이벤트 경험의 교집합을 기준으로 계산하며, 이벤트 발생의 시간 순서는 반영하지
  않습니다. GA4의 세션 끊김·기기 교체 등으로 일부 단계 이벤트가 누락될 수 있어, 실제 전환율은
  본 분석보다 다소 높을 수 있습니다.
- 상품 퍼널은 같은 `item_name`을 조회·장바구니·구매까지 모두 경험한 유저(유저×상품), 카테고리
  퍼널은 "카테고리 안의 어떤 상품이든" 경험한 유저(유저×카테고리) 기준입니다. 두 전환율은
  직접 비교할 수 없고, 상품·카테고리 분석은 상대 비교 용도로만 활용해야 합니다.
- `view_item` 이벤트의 37.3%는 items 배열이 비어 있어 상품별 조회 유저가 과소 집계되고, 조회
  기준 전환율은 실제보다 높게 나올 수 있습니다.
- `item_category` 형식이 이벤트마다 다릅니다 (purchase는 `Apparel`처럼 평평한 분류, 조회/장바구니는
  `Home/Apparel/` 같은 경로형). 카테고리 분석은 `item_name`을 통해 조회/장바구니 쪽 경로형 분류에
  연결했고, 한 상품이 여러 카테고리에 속하면 각각에 집계합니다.
- `item_name` 표기도 일부 불일치합니다 (예: `Longsleeve` ↔ `Long Sleeve Tee`). purchase 매출 중
  이름으로 연결되지 않던 비중은 최대 4.17%였고, 수동 매핑 3건(매출의 2.7%)으로 보정했습니다. 보정 후에도
  약 1.5%가 연결되지 않으며, 매핑하지 않은 상품은 구매가 과소 집계될 수 있습니다
  (`docs/item_name_mapping.md`, `docs/metric_definitions.md`).

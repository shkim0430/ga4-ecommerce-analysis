# GA4 이커머스 분석 포트폴리오

🔗 **라이브 대시보드**: TBD (배포 후 업데이트 예정)
📁 **저장소**: [github.com/shkim0430/ga4-ecommerce-analysis](https://github.com/shkim0430/ga4-ecommerce-analysis)

---

## 프로젝트 소개

GA4 + BigQuery 공개 데이터셋으로 Google Merchandise Store의 이커머스 데이터를 분석한 포트폴리오
프로젝트입니다. 신규/재구매 고객, 구매 전환 퍼널, 채널별 성과, 고객 세그먼트 분석을 통해 매출 개선
우선순위를 도출하는 것을 목표로 합니다.

결론적으로, 이 사이트의 매출 개선 레버리지는 (1) 체크아웃 이탈률 개선, (2) 1회 중가 구매자의
재구매 유도, (3) 전체 유입 전환율 개선 순으로 크며, VIP 리텐션 전략의 우선순위는 상대적으로
낮습니다.

## 데이터

- 소스: `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
- 기간: 2020-11-01 ~ 2021-01-31 (약 3개월)
- 규모: 총 방문자 270,154명 / 구매 유저 4,419명 / 이벤트 17종
- 이 데이터셋은 난독화(obfuscated)된 샘플이므로 절대값(매출, 유저 수 등)은 실제 Google
  Merchandise Store 데이터와 다를 수 있습니다. 추세와 상대 비교 중심으로 해석해 주세요.

## 분석 스코프

1. 구매 전환 퍼널 (view_item → add_to_cart → begin_checkout → purchase)
2. 채널(source/medium)별 유입 규모와 성과
3. 월간/주간 코호트 재구매율
4. 매출 집중도 (Pareto 분석)
5. 구매 빈도 × 금액대 세그먼트 매트릭스

## 핵심 인사이트

**가장 큰 매출 손실 지점은 체크아웃 이탈**
상품을 장바구니에 담고 체크아웃까지 진행한 유저의 54.5%가 결제 없이 이탈합니다. 이는 업계
평균(30~40%) 대비 심각한 수준으로, 배송비 사전 노출·게스트 체크아웃 등 결제 페이지 최적화의
임팩트가 가장 큽니다.
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
│   ├── 00_explore.sql
│   ├── 01_cohort_repurchase.sql
│   ├── 02_channel_performance.sql
│   ├── 03_conversion_funnel.sql
│   └── 04_customer_segments.sql
├── src/                          # 데이터 추출 및 시각화 코드
│   ├── bq_client.py              # BigQuery 클라이언트 래퍼 (ADC 인증)
│   ├── fetch_data.py             # sql/ 실행 → outputs/*.csv 저장
│   └── visualize.py              # outputs/*.csv → outputs/figures/*.png
├── notebooks/                    # 탐색적 분석용 노트북
├── outputs/                      # 쿼리 결과 CSV, 시각화 PNG
│   └── figures/
├── docs/                         # 문서
├── requirements.txt
├── CLAUDE.md
└── README.md
```

## 기술 스택

BigQuery / Python 3.14 / pandas / google-cloud-bigquery / matplotlib / seaborn

## 한계 및 개선점

- 데이터가 3개월치라 코호트 분석의 관측 기간이 제한적입니다.
- 난독화된 샘플이므로 절대값은 참고용으로만 활용해야 합니다.
- 향후 계획: Streamlit 대시보드, 주간 KPI 자동 리포트, LLM 기반 Text-to-SQL 기능

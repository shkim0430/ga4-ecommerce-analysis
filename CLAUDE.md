# GA4 이커머스 분석 포트폴리오

## 프로젝트 목적

이커머스 데이터 분석 포트폴리오 프로젝트. GA4 + BigQuery 공개 데이터셋
(`bigquery-public-data.ga4_obfuscated_sample_ecommerce`)으로 Google Merchandise Store의
데이터를 분석해, 구매 전환·채널 성과·코호트 재구매·고객 세그먼트·상품 단위 관점의 인사이트와
매출 개선 우선순위를 도출한다.

최종 결과물 3가지:
1. BigQuery SQL 분석 스크립트 (`sql/`)
2. Streamlit 대시보드 (`src/`)
3. 주간 KPI 리포트 (`src/weekly_report.py`, 엑셀)

## 데이터

- 기간: 2020-11 ~ 2021-01 (약 3개월)
- 테이블: `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*` (일자별 샤딩, `_TABLE_SUFFIX` = `YYYYMMDD`)
- 이 데이터셋은 난독화(obfuscated)된 샘플이므로 일부 값(예: 매출액, 사용자 수 등 절대값)은 실제
  Google Merchandise Store 데이터와 다를 수 있음. 분석 결과나 리포트에 수치를 제시할 때는 이 점을
  명시할 것.

### 데이터 주의사항

- **add_to_cart 추적 누락**: 2020-11-02~11-15에는 add_to_cart 이벤트가 0건이다 (11/16~11/20에만 기록되고 11/21~22는 다시 0건). 이 기간의 장바구니 관련 지표는 신뢰할 수 없으므로 퍼널은 2020-11-16 이후로 다시 계산한 값을 병기한다.
- **1월 말 매출 NULL**: 2021-01-26 이후 purchase의 `purchase_revenue`와 `item_revenue`가 대부분 NULL이다 (1/31은 19건 전부). 마지막 주(2021-01-25)의 매출은 과소 집계이므로 추세로 해석하지 않는다.
- 그 밖의 이상 구간(transaction_id 없는 purchase, 이벤트 간 item_id·item_name·item_category 불일치, view_item items 37.3% 누락)과 집계 규칙은 `docs/metric_definitions.md`를 따른다.

## 분석 스코프

1. 신규/재구매 고객 구분과 코호트 리텐션
2. 상품 조회 → 장바구니 → 구매 퍼널
3. 채널(source/medium)별 유입과 구매 성과
4. 코호트별 재구매율
5. 고객 세그먼트별 매출 기여도
6. 상품 단위 전환과 매출 기여 (상품·카테고리 퍼널, 상품 매출 Pareto)
7. 주간 KPI 리포트 (완전한 13주, 과거 데이터 대상)

## 환경

- OS: Windows
- Python: 3.14, `venv` 사용 (프로젝트 루트의 `.venv`)
- GCP 프로젝트 ID: `ga4-ecommerce-508803`
- 인증: gcloud ADC(Application Default Credentials)로 처리. **서비스 계정 키를 코드에서 절대 사용하지 않는다.**
- **BigQuery 모드: Sandbox** (결제 미연결). 결과 테이블 생성/저장 불가, 뷰(VIEW) 생성 불가. 모든 분석은 SELECT 쿼리만으로 수행하고, 재사용할 결과는 CTE로 처리하거나 로컬 파일(CSV/Parquet)로 내려받아 사용한다.

## 폴더 구조

- `sql/` — BigQuery SQL 분석 스크립트
- `src/` — 데이터 추출, 시각화, Streamlit 대시보드, 주간 리포트 생성 코드
- `notebooks/` — 탐색적 분석용 노트북
- `outputs/` — 쿼리 결과 CSV, 시각화(`figures/`), 주간 리포트(`reports/`)
- `docs/` — 문서

## SQL 컨벤션

- CTE(Common Table Expression) 기반으로 작성한다.
- 각 SQL 파일 상단에 이 쿼리가 답하려는 질문을 한 줄 주석으로 명시한다.
  ```sql
  -- Q: 채널(source/medium)별 신규 고객 수와 구매 전환율은?
  ```
- BigQuery 스캔량 절약을 위해 `_TABLE_SUFFIX` 파티션 필터를 항상 사용한다.
- `SELECT *` 금지. 필요한 컬럼만 명시적으로 SELECT한다 (BigQuery는 컬럼 단위 과금).
- 쿼리 실행 전 에디터 우측 상단의 "이 쿼리 실행 시 X GB 처리" 예상치를 확인한다. 예상 밖으로 크면 파티션 필터 범위를 좁힌다. CLI에서는 `bq query --dry_run`으로 확인한다.
- **상품 매출은 `item.item_revenue`로만 집계한다.** `UNNEST(items)` 후 `ecommerce.purchase_revenue`를 합산하면 item 행마다 이벤트 매출이 중복되어 4.53배로 부풀려지므로 금지한다. 이벤트 단위 매출은 UNNEST 없이 `ecommerce.purchase_revenue`로 집계한다.

## 작업 순서 원칙

- 쿼리를 실행하면 결과의 상위 몇 줄을 반드시 눈으로 확인한 뒤 다음 단계로 진행한다.
- 쿼리 검증 없이 대시보드/리포트 코드를 먼저 작성하지 않는다. 순서: SQL 작성 → 실행 및 결과 검증 → 대시보드/리포트 코드 작성.

## 금지사항

- 서비스 계정 키 JSON 파일을 절대 커밋하지 않는다.
- 쿼리 검증 없이 대시보드/리포트 코드를 먼저 작성하지 않는다.

## Definition of Done

프로젝트가 "완료"되었다고 볼 수 있는 최소 산출물:
- [x] `sql/` 아래 분석 스코프 7개 각각에 대한 검증된 쿼리 (00~08b, 실행 전 dry-run, 합계는 독립 쿼리로 대조)
- [x] Streamlit 대시보드 6개 화면: Executive Summary / 구매 전환 퍼널 / 코호트 재구매율 / 채널 성과 / 고객 세그먼트 / 상품 분석 (AppTest로 예외 없음 확인)
- [x] 주간 KPI 리포트 (BigQuery → Python → 엑셀, `src/weekly_report.py`): 과거 13주를 `--week`/`--all`로 수동 생성. 스케줄 실행과 실시간 모니터링은 없음
- [x] `README.md`에 프로젝트 결과 요약과 실행 방법
- [ ] 포트폴리오 발표용 슬라이드 또는 노션 페이지 (선택, `docs/portfolio_summary.md`는 요약 문서이며 슬라이드/노션이 아님)
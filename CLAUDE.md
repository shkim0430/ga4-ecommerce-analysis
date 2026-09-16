# GA4 이커머스 분석 포트폴리오

## 프로젝트 목적

KT알파 T커머스 데이터 분석 직무 지원용 포트폴리오 프로젝트. GA4 + BigQuery 공개 데이터셋
(`bigquery-public-data.ga4_obfuscated_sample_ecommerce`)으로 Google Merchandise Store의
이커머스 데이터를 분석한다.

최종 결과물 3가지:
1. BigQuery SQL 분석 스크립트 (`sql/`)
2. Streamlit 대시보드 (`src/`)
3. 주간 KPI 자동 리포트

## 데이터

- 기간: 2020-11 ~ 2021-01 (약 3개월)
- 테이블: `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*` (일자별 샤딩, `_TABLE_SUFFIX` = `YYYYMMDD`)
- 이 데이터셋은 난독화(obfuscated)된 샘플이므로 일부 값(예: 매출액, 사용자 수 등 절대값)은 실제
  Google Merchandise Store 데이터와 다를 수 있음. 분석 결과나 리포트에 수치를 제시할 때는 이 점을
  명시할 것.

## 분석 스코프

1. 신규/재구매 고객 구분과 코호트 리텐션
2. 상품 조회 → 장바구니 → 구매 퍼널
3. 채널(source/medium)별 유입과 구매 성과
4. 코호트별 재구매율
5. 고객 세그먼트별 매출 기여도

## 환경

- OS: Windows
- Python: 3.14, `venv` 사용 (프로젝트 루트의 `.venv`)
- GCP 프로젝트 ID: `ga4-ecommerce-508803`
- 인증: gcloud ADC(Application Default Credentials)로 처리. **서비스 계정 키를 코드에서 절대 사용하지 않는다.**

## 폴더 구조

- `sql/` — BigQuery SQL 분석 스크립트
- `src/` — Streamlit 대시보드, 리포트 생성 등 애플리케이션 코드
- `notebooks/` — 탐색적 분석용 노트북
- `outputs/` — 쿼리 결과, 리포트 산출물
- `docs/` — 문서

## SQL 컨벤션

- CTE(Common Table Expression) 기반으로 작성한다.
- 각 SQL 파일 상단에 이 쿼리가 답하려는 질문을 한 줄 주석으로 명시한다.
  ```sql
  -- Q: 채널(source/medium)별 신규 고객 수와 구매 전환율은?
  ```
- BigQuery 스캔량 절약을 위해 `_TABLE_SUFFIX` 파티션 필터를 항상 사용한다.

## 작업 순서 원칙

- 쿼리를 실행하면 결과의 상위 몇 줄을 반드시 눈으로 확인한 뒤 다음 단계로 진행한다.
- 쿼리 검증 없이 대시보드/리포트 코드를 먼저 작성하지 않는다. 순서: SQL 작성 → 실행 및 결과 검증 → 대시보드/리포트 코드 작성.

## 금지사항

- 서비스 계정 키 JSON 파일을 절대 커밋하지 않는다.
- 쿼리 검증 없이 대시보드/리포트 코드를 먼저 작성하지 않는다.

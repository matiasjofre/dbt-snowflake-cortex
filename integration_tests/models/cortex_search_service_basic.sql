-- Copyright 2026 dbt-snowflake-cortex contributors
-- SPDX-License-Identifier: Apache-2.0

{{
  config(
    enabled=var('dbt_snowflake_cortex_enable_cortex_search_integration_tests', false),
    materialized='cortex_search_service',
    meta={
      'dbt_snowflake_cortex': {
        'search_column': 'body',
        'primary_key': ['document_id'],
        'attributes': ['department', 'region'],
        'warehouse': target.warehouse,
        'target_lag': '1 hour',
        'embedding_model': 'snowflake-arctic-embed-l-v2.0',
        'refresh_mode': 'INCREMENTAL',
        'initialize': 'ON_SCHEDULE',
        'full_index_build_interval_days': 7,
        'request_logging': true,
        'auto_suspend': 1800,
        'comment': 'Integration test Cortex Search service for policy documents.'
      }
    }
  )
}}

select
  document_id,
  title,
  body,
  department,
  region
from {{ ref('cortex_search_documents') }}

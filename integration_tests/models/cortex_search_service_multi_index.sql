-- Copyright 2026 dbt-snowflake-cortex contributors
-- SPDX-License-Identifier: Apache-2.0

{{
  config(
    enabled=var('dbt_snowflake_cortex_enable_cortex_search_integration_tests', false),
    materialized='cortex_search_service',
    meta={
      'dbt_snowflake_cortex': {
        'text_indexes': ['title', 'body'],
        'vector_indexes': ["body (model='snowflake-arctic-embed-m-v1.5')"],
        'primary_key': ['document_id'],
        'attributes': ['department', 'region'],
        'warehouse': target.warehouse,
        'target_lag': '1 hour',
        'refresh_mode': 'INCREMENTAL',
        'initialize': 'ON_SCHEDULE',
        'request_logging': false,
        'auto_suspend': 1800,
        'comment': 'Integration test multi-index Cortex Search service.'
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

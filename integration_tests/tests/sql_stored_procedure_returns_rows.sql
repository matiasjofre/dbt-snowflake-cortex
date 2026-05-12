-- Copyright 2026 dbt-snowflake-cortex contributors
-- SPDX-License-Identifier: Apache-2.0

{{
  config(
    enabled=var('dbt_snowflake_cortex_enable_stored_procedure_integration_tests', false),
    materialized='test'
  )
}}

select 'SQL stored procedure did not return expected revenue rows' as error_message
where not exists (
  select 1
  from {{ ref('sql_stored_procedure_results') }}
  where id = 1
    and revenue = 100
)

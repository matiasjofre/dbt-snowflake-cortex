-- Copyright 2026 dbt-snowflake-cortex contributors
-- SPDX-License-Identifier: Apache-2.0

{{
  config(
    enabled=var('dbt_snowflake_cortex_enable_stored_procedure_integration_tests', false),
    materialized='test'
  )
}}

select 'Python stored procedure did not return expected greeting' as error_message
where not exists (
  select 1
  from {{ ref('python_stored_procedure_results') }}
  where greeting = 'hello dbt'
)

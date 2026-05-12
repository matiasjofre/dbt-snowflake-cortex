-- Copyright 2026 dbt-snowflake-cortex contributors
-- SPDX-License-Identifier: Apache-2.0

{{
  config(
    enabled=var('dbt_snowflake_cortex_enable_stored_procedure_integration_tests', false),
    materialized='table'
  )
}}

select *
from table({{ ref('sql_stored_procedure_basic') }}(1))

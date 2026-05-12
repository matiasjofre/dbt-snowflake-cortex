-- Copyright 2026 dbt-snowflake-cortex contributors
-- SPDX-License-Identifier: Apache-2.0

{{
  config(
    enabled=var('dbt_snowflake_cortex_enable_stored_procedure_integration_tests', false),
    materialized='stored_procedure',
    meta={
      'dbt_snowflake_cortex': {
        'arguments': [
          {'name': 'MIN_ID', 'type': 'NUMBER', 'default': '0'}
        ],
        'returns': 'TABLE (ID NUMBER, REVENUE NUMBER)',
        'execute_as': 'CALLER',
        'comment': 'Integration test SQL stored procedure.'
      }
    }
  )
}}

DECLARE
  res RESULTSET;
BEGIN
  res := (
    select
      id,
      revenue
    from {{ ref('base_table') }}
    where id >= :MIN_ID
    order by id
  );
  RETURN TABLE(res);
END

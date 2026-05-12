-- Copyright 2026 dbt-snowflake-cortex contributors
-- SPDX-License-Identifier: Apache-2.0

{{
  config(
    enabled=(
      var('dbt_snowflake_cortex_enable_agent_tool_integration_tests', false)
      and var('dbt_snowflake_cortex_enable_cortex_search_integration_tests', false)
      and var('dbt_snowflake_cortex_enable_stored_procedure_integration_tests', false)
    ),
    materialized='test'
  )
}}

select 'Cortex Agent DDL is missing expected dbt-managed tool resources' as error_message
where not (
  position('semantic_view_basic' in lower(get_ddl('CORTEX_AGENT', '{{ ref('cortex_agent_with_tools') }}'))) > 0
  and position('cortex_search_service_basic' in lower(get_ddl('CORTEX_AGENT', '{{ ref('cortex_agent_with_tools') }}'))) > 0
  and position('sql_stored_procedure_basic' in lower(get_ddl('CORTEX_AGENT', '{{ ref('cortex_agent_with_tools') }}'))) > 0
)

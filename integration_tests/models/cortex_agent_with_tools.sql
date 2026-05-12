-- Copyright 2026 dbt-snowflake-cortex contributors
-- SPDX-License-Identifier: Apache-2.0

{{
  config(
    enabled=(
      var('dbt_snowflake_cortex_enable_agent_tool_integration_tests', false)
      and var('dbt_snowflake_cortex_enable_cortex_search_integration_tests', false)
      and var('dbt_snowflake_cortex_enable_stored_procedure_integration_tests', false)
    ),
    materialized='cortex_agent',
    static_analysis='off',
    meta={
      'dbt_snowflake_cortex': {
        'comment': 'Integration test Cortex Agent using dbt-managed semantic, search, and procedure resources.',
        'profile': {
          'display_name': 'Integration Test Cortex Agent',
          'avatar': 'integration-test.png',
          'color': 'green'
        }
      }
    }
  )
}}

models:
  orchestration: claude-4-sonnet

orchestration:
  budget:
    seconds: 30
    tokens: 16000

instructions:
  response: "Answer briefly and name the tool you used."
  orchestration: "Use Analyst for revenue questions, Search for policy questions, and RevenueProcedure for raw table lookups."
  sample_questions:
    - question: "What is total revenue?"
    - question: "What is the return policy for gold members?"
    - question: "Show revenue rows with an id greater than zero."

tools:
  - tool_spec:
      type: "cortex_analyst_text_to_sql"
      name: "Analyst"
      description: "Answers questions using the integration semantic view."

  - tool_spec:
      type: "cortex_search"
      name: "Search"
      description: "Searches integration policy documents."

  - tool_spec:
      type: "generic"
      name: "RevenueProcedure"
      description: "Calls a SQL stored procedure that returns revenue rows."
      input_schema:
        type: "object"
        properties:
          min_id:
            type: "number"
            description: "Minimum id to return."
        required:
          - min_id

tool_resources:
  Analyst:
    semantic_view: "{{ ref('semantic_view_basic') }}"

  Search:
    name: "{{ ref('cortex_search_service_basic') }}"
    max_results: "5"
    title_column: "title"
    id_column: "document_id"

  RevenueProcedure:
    type: "procedure"
    identifier: "{{ ref('sql_stored_procedure_basic') }}"
    execution_environment:
      type: "warehouse"
      warehouse: "{{ target.warehouse }}"
      query_timeout: 60

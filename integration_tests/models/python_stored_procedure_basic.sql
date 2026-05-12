-- Copyright 2026 dbt-snowflake-cortex contributors
-- SPDX-License-Identifier: Apache-2.0

{{
  config(
    enabled=var('dbt_snowflake_cortex_enable_stored_procedure_integration_tests', false),
    materialized='stored_procedure',
    static_analysis='off',
    meta={
      'dbt_snowflake_cortex': {
        'procedure_language': 'PYTHON',
        'arguments': ['NAME STRING'],
        'returns': 'TABLE (GREETING STRING)',
        'runtime_version': '3.10',
        'packages': ['snowflake-snowpark-python'],
        'handler': 'main',
        'execute_as': 'CALLER',
        'comment': 'Integration test Python stored procedure.'
      }
    }
  )
}}

def main(session, name):
    return session.create_dataframe(
        [[f"hello {name}"]],
        schema=["GREETING"],
    )

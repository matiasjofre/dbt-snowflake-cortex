-- Copyright 2026 dbt-snowflake-cortex contributors
-- SPDX-License-Identifier: Apache-2.0
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
-- http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

{{
  config(
    materialized='mcp_server',
    comment='Integration test MCP server with Analyst and SQL execution tools.'
  )
}}

tools:
  - name: "test-analyst"
    type: "CORTEX_ANALYST_MESSAGE"
    identifier: "{{ ref('semantic_view_basic') }}"
    description: "Queries the semantic_view_basic model created by this dbt project."
    title: "Test Analyst"

  - name: "test-sql-exec"
    type: "SYSTEM_EXECUTE_SQL"
    title: "SQL Execution"
    description: "Execute SQL queries against the connected Snowflake database."

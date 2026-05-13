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
    enabled=var('dbt_snowflake_cortex_enable_mcp_server_integration_tests', false),
    materialized='mcp_server_specification_test',
    meta={
      'dbt_snowflake_cortex': {
        'mcp_server_relation': ref('mcp_server_basic') | string,
        'expected_text': 'test-analyst'
      }
    }
  )
}}

-- depends_on: {{ ref('mcp_server_basic') }}

-- The custom materialization runs DESCRIBE MCP SERVER and checks server_spec.
select 1 as ok

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

{% materialization mcp_server_specification_test, adapter='snowflake' -%}
  {%- set meta = config.get('meta', default={}) -%}
  {%- set package_meta = meta.get('dbt_snowflake_cortex', {}) if meta is mapping else {} -%}
  {%- set mcp_server_relation = package_meta.get('mcp_server_relation') -%}
  {%- set expected_text = package_meta.get('expected_text') -%}

  {%- if mcp_server_relation is none or mcp_server_relation == '' -%}
    {{ exceptions.raise_compiler_error("Missing required meta config `dbt_snowflake_cortex.mcp_server_relation`.") }}
  {%- endif -%}
  {%- if expected_text is none or expected_text == '' -%}
    {{ exceptions.raise_compiler_error("Missing required meta config `dbt_snowflake_cortex.expected_text`.") }}
  {%- endif -%}

  {%- set original_query_tag = set_query_tag() -%}

  {% call statement('describe_mcp_server', fetch_result=True) -%}
    describe mcp server {{ mcp_server_relation }}
  {%- endcall %}

  {%- set result = load_result('describe_mcp_server') -%}
  {%- set table = result['table'] -%}
  {%- set spec = '' -%}
  {%- if table is not none and table.rows | length > 0 -%}
    {%- set spec = table.rows[0]['server_spec'] | string | lower -%}
  {%- endif -%}

  {%- set failures = 0 if (expected_text | string | lower) in spec else 1 -%}

  {% call statement('main', fetch_result=True) -%}
    select
      {{ failures }} as failures,
      {{ dbt_snowflake_cortex.sql_bool(failures > 0) }} as should_warn,
      {{ dbt_snowflake_cortex.sql_bool(failures > 0) }} as should_error
  {%- endcall %}

  {%- do unset_query_tag(original_query_tag) -%}
  {%- do return({'relations': []}) -%}
{%- endmaterialization %}

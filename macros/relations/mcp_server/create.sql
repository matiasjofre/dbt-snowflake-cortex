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

{% macro mcp_server_body_is_raw(sql) -%}
  {%- set ns = namespace(first_line='') -%}
  {%- for line in (sql | trim).split('\n') -%}
    {%- set stripped = line | trim -%}
    {%- if ns.first_line == '' and stripped != '' and stripped[0:2] != '--' -%}
      {%- set ns.first_line = stripped | lower -%}
    {%- endif -%}
  {%- endfor -%}
  {%- set body = ns.first_line -%}
  {%- do return(
      body[0:7] == 'comment'
      or body[0:18] == 'from specification'
    ) -%}
{%- endmacro %}


{% macro snowflake__get_create_mcp_server_sql(relation, sql) -%}
{#-
--  Produce DDL that creates an MCP Server.
--
--  Args:
--  - relation: Union[SnowflakeRelation, str]
--      - SnowflakeRelation - required for relation.render()
--      - str - is already the rendered relation name
--  - sql: str - the code defining the MCP server body. By default this is the
--      YAML specification (tools array); set mcp_server_body_mode='raw' to pass
--      the full post-object-name DDL body through unchanged.
--  Returns:
--      A valid DDL statement which will result in a new MCP Server.
-#}

  {%- set or_replace = dbt_snowflake_cortex.get_config('or_replace', true) -%}
  {%- set if_not_exists = dbt_snowflake_cortex.get_config('if_not_exists', false) -%}
  {%- set body_mode = dbt_snowflake_cortex.get_config('mcp_server_body_mode', 'auto') -%}
  {%- set body = sql | trim -%}
  {%- set raw_body = body_mode == 'raw' or (body_mode == 'auto' and dbt_snowflake_cortex.mcp_server_body_is_raw(body)) -%}

  {%- if body_mode not in ['auto', 'raw', 'specification'] -%}
    {{ exceptions.raise_compiler_error("Config `mcp_server_body_mode` must be one of `auto`, `raw`, or `specification`.") }}
  {%- endif -%}

  create {{ dbt_snowflake_cortex.create_modifier(or_replace, if_not_exists) }} mcp server {{ dbt_snowflake_cortex.if_not_exists_clause(if_not_exists) }} {{ relation }}
  {%- if raw_body %}
  {{ body }}
  {%- else %}
  {{ dbt_snowflake_cortex.comment_clause(dbt_snowflake_cortex.object_comment(dbt_snowflake_cortex.get_config('comment', none))) }}
  FROM SPECIFICATION
  $$
  {{ body }}
  $$;
  {%- endif %}

{%- endmacro %}


{% macro snowflake__create_or_replace_mcp_server() %}
  {%- set identifier = model['alias'] -%}

  {%- set target_relation = api.Relation.create(
      identifier=identifier, schema=schema, database=database,
      type='external') -%}

  {{ run_hooks(pre_hooks) }}

  -- build mcp server
  {% call statement('main') -%}
    {{ dbt_snowflake_cortex.snowflake__get_create_mcp_server_sql(target_relation, sql) }}
  {%- endcall %}

  {{ run_hooks(post_hooks) }}

  {{ return({'relations': [target_relation]}) }}

{% endmacro %}

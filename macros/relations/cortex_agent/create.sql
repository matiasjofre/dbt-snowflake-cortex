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

{% macro snowflake__get_create_cortex_agent_sql(relation, sql) -%}
{#-
--  Produce DDL that creates a Cortex Agent.
--
--  Args:
--  - relation: Union[SnowflakeRelation, str]
--      - SnowflakeRelation - required for relation.render()
--      - str - is already the rendered relation name
--  - sql: str - the code defining the agent body
--  Returns:
--      A valid DDL statement which will result in a new Cortex Agent.
-#}

  create or replace agent {{ relation }}
  {{ sql }}

{%- endmacro %}


{% macro snowflake__create_or_replace_cortex_agent() %}
  {%- set identifier = model['alias'] -%}

  {%- set target_relation = api.Relation.create(
      identifier=identifier, schema=schema, database=database,
      type='external') -%}

  {{ run_hooks(pre_hooks) }}

  -- build agent
  {% call statement('main') -%}
    {{ dbt_snowflake_cortex.snowflake__get_create_cortex_agent_sql(target_relation, sql) }}
  {%- endcall %}

  {{ run_hooks(post_hooks) }}

  {{ return({'relations': [target_relation]}) }}

{% endmacro %}

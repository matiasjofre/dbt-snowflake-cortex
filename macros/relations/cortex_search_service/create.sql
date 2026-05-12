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

{% macro snowflake__get_create_cortex_search_service_sql(relation, sql) -%}
{#-
--  Produce DDL that creates a Cortex Search service.
--
--  Args:
--  - relation: Union[SnowflakeRelation, str]
--      - SnowflakeRelation - required for relation.render()
--      - str - is already the rendered relation name
--  - sql: str - the source query for the search service.
--  Returns:
--      A valid DDL statement which will result in a new Cortex Search service.
-#}

  {%- set or_replace = dbt_snowflake_cortex.get_config('or_replace', true) -%}
  {%- set if_not_exists = dbt_snowflake_cortex.get_config('if_not_exists', false) -%}
  {%- set search_column = dbt_snowflake_cortex.get_config('search_column', none) -%}
  {%- set text_indexes = dbt_snowflake_cortex.get_config('text_indexes', dbt_snowflake_cortex.get_config('text_indices', [])) -%}
  {%- set vector_indexes = dbt_snowflake_cortex.get_config('vector_indexes', dbt_snowflake_cortex.get_config('vector_indices', [])) -%}
  {%- set primary_key = dbt_snowflake_cortex.get_config('primary_key', []) -%}
  {%- set attributes = dbt_snowflake_cortex.get_config('attributes', []) -%}
  {%- set warehouse = dbt_snowflake_cortex.get_config('warehouse', target.warehouse) -%}
  {%- set target_lag = dbt_snowflake_cortex.get_config('target_lag', none) -%}
  {%- set embedding_model = dbt_snowflake_cortex.get_config('embedding_model', none) -%}
  {%- set refresh_mode = dbt_snowflake_cortex.get_config('refresh_mode', none) -%}
  {%- set initialize = dbt_snowflake_cortex.get_config('initialize', none) -%}
  {%- set full_index_build_interval_days = dbt_snowflake_cortex.get_config('full_index_build_interval_days', none) -%}
  {%- set request_logging = dbt_snowflake_cortex.get_config('request_logging', none) -%}
  {%- set auto_suspend = dbt_snowflake_cortex.get_config('auto_suspend', none) -%}
  {%- set comment = dbt_snowflake_cortex.object_comment(dbt_snowflake_cortex.get_config('comment', none)) -%}
  {%- set source_query = sql | trim -%}

  {%- set has_search_column = search_column is not none and search_column != '' -%}
  {%- set has_text_indexes = (text_indexes is string and text_indexes != '') or (text_indexes is sequence and text_indexes is not string and text_indexes | length > 0) -%}
  {%- set has_vector_indexes = (vector_indexes is string and vector_indexes != '') or (vector_indexes is sequence and vector_indexes is not string and vector_indexes | length > 0) -%}

  {%- if source_query == '' -%}
    {{ exceptions.raise_compiler_error("A `cortex_search_service` model must contain the source query after the config block.") }}
  {%- endif -%}
  {%- if warehouse is none or warehouse == '' -%}
    {{ exceptions.raise_compiler_error("Missing required config `warehouse`, and no target warehouse was available.") }}
  {%- endif -%}
  {%- if target_lag is none or target_lag == '' -%}
    {{ exceptions.raise_compiler_error("Missing required config `target_lag`.") }}
  {%- endif -%}
  {%- if has_search_column and (has_text_indexes or has_vector_indexes) -%}
    {{ exceptions.raise_compiler_error("Use either `search_column` for single-index Cortex Search or `text_indexes`/`vector_indexes` for multi-index Cortex Search, not both.") }}
  {%- endif -%}
  {%- if not has_search_column and not (has_text_indexes or has_vector_indexes) -%}
    {{ exceptions.raise_compiler_error("Missing Cortex Search index config. Pass `search_column` or `text_indexes`/`vector_indexes`.") }}
  {%- endif -%}
  {%- if not has_search_column and not has_vector_indexes -%}
    {{ exceptions.raise_compiler_error("Multi-index Cortex Search requires at least one `vector_indexes` entry.") }}
  {%- endif -%}
  {%- if not has_search_column and embedding_model is not none and embedding_model != '' -%}
    {{ exceptions.raise_compiler_error("Config `embedding_model` applies only to single-index Cortex Search. For multi-index search, include model options in `vector_indexes`.") }}
  {%- endif -%}
  {%- if not has_search_column and if_not_exists -%}
    {{ exceptions.raise_compiler_error("Snowflake's multi-index Cortex Search syntax does not support `IF NOT EXISTS`; leave `if_not_exists` unset.") }}
  {%- endif -%}

  create {{ dbt_snowflake_cortex.create_modifier(or_replace, if_not_exists) }} cortex search service {{ dbt_snowflake_cortex.if_not_exists_clause(if_not_exists) }} {{ relation }}
  {%- if has_search_column %}
    ON {{ search_column }}
  {%- else %}
    {%- if has_text_indexes %}
    TEXT INDEXES {{ dbt_snowflake_cortex.render_identifier_list(text_indexes, 'text_indexes') }}
    {%- endif %}
    VECTOR INDEXES {{ dbt_snowflake_cortex.render_identifier_list(vector_indexes, 'vector_indexes') }}
  {%- endif %}
  {%- if primary_key is not none and primary_key != [] and primary_key != '' %}
    PRIMARY KEY ({{ dbt_snowflake_cortex.render_identifier_list(primary_key, 'primary_key') }})
  {%- endif %}
  {%- if attributes is not none and attributes != [] and attributes != '' %}
    ATTRIBUTES {{ dbt_snowflake_cortex.render_identifier_list(attributes, 'attributes') }}
  {%- endif %}
    WAREHOUSE = {{ warehouse }}
    TARGET_LAG = {{ dbt_snowflake_cortex.sql_string(target_lag) }}
  {%- if embedding_model is not none and embedding_model != '' %}
    EMBEDDING_MODEL = {{ dbt_snowflake_cortex.sql_string(embedding_model) }}
  {%- endif %}
  {%- if refresh_mode is not none and refresh_mode != '' %}
    REFRESH_MODE = {{ refresh_mode }}
  {%- endif %}
  {%- if initialize is not none and initialize != '' %}
    INITIALIZE = {{ initialize }}
  {%- endif %}
  {%- if full_index_build_interval_days is not none %}
    FULL_INDEX_BUILD_INTERVAL_DAYS = {{ full_index_build_interval_days }}
  {%- endif %}
  {%- if request_logging is not none %}
    REQUEST_LOGGING = {{ dbt_snowflake_cortex.sql_bool(request_logging) }}
  {%- endif %}
  {%- if auto_suspend is not none %}
    AUTO_SUSPEND = {{ auto_suspend }}
  {%- endif %}
  {{ dbt_snowflake_cortex.comment_clause(comment) }}
  AS
  {{ source_query }}

{%- endmacro %}


{% macro snowflake__create_or_replace_cortex_search_service() %}
  {%- set identifier = model['alias'] -%}

  {%- set target_relation = api.Relation.create(
      identifier=identifier, schema=schema, database=database,
      type='external') -%}

  {{ run_hooks(pre_hooks) }}

  -- build search service
  {% call statement('main') -%}
    {{ dbt_snowflake_cortex.snowflake__get_create_cortex_search_service_sql(target_relation, sql) }}
  {%- endcall %}

  {{ run_hooks(post_hooks) }}

  {{ return({'relations': [target_relation]}) }}

{% endmacro %}

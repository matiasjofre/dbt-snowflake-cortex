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

{% macro snowflake__get_create_stored_procedure_sql(relation, sql, compiled_code=none) -%}
{#-
--  Produce DDL that creates a SQL or Python stored procedure.
--
--  Args:
--  - relation: Union[SnowflakeRelation, str]
--      - SnowflakeRelation - required for relation.render()
--      - str - is already the rendered relation name
--  - sql: str - Snowflake Scripting body for SQL procedures.
--  - compiled_code: str - compiled Python model code for Python procedures.
--  Returns:
--      A valid DDL statement which will result in a new stored procedure.
-#}

  {%- set model_language = model.get('language', 'sql') | lower -%}
  {%- set language = dbt_snowflake_cortex.get_config('procedure_language', model_language) | lower -%}
  {%- set arguments = dbt_snowflake_cortex.get_config('arguments', []) -%}
  {%- set returns = dbt_snowflake_cortex.get_config('returns', none) -%}
  {%- set copy_grants = dbt_snowflake_cortex.get_config('copy_grants', false) -%}
  {%- set secure = dbt_snowflake_cortex.get_config('secure', false) -%}
  {%- set temporary = dbt_snowflake_cortex.get_config('temporary', false) -%}
  {%- set null_input_behavior = dbt_snowflake_cortex.get_config('null_input_behavior', none) -%}
  {%- set volatility = dbt_snowflake_cortex.get_config('volatility', none) -%}
  {%- set execute_as = dbt_snowflake_cortex.get_config('execute_as', none) -%}
  {%- set comment = dbt_snowflake_cortex.object_comment(dbt_snowflake_cortex.get_config('comment', none)) -%}

  {%- set runtime_version = dbt_snowflake_cortex.get_config('runtime_version', dbt_snowflake_cortex.get_config('python_version', '3.10')) -%}
  {%- set packages = dbt_snowflake_cortex.get_config('packages', ['snowflake-snowpark-python']) -%}
  {%- set imports = dbt_snowflake_cortex.get_config('imports', []) -%}
  {%- set external_access_integrations = dbt_snowflake_cortex.get_config('external_access_integrations', []) -%}
  {%- set secrets = dbt_snowflake_cortex.get_config('secrets', {}) -%}
  {%- set artifact_repository = dbt_snowflake_cortex.get_config('artifact_repository', none) -%}
  {%- set default_python_handler = '_dbt_snowflake_cortex_main' if model_language == 'python' else 'main' -%}
  {%- set python_handler = dbt_snowflake_cortex.get_config('handler', default_python_handler) -%}

  {%- if language not in ['sql', 'python'] -%}
    {{ exceptions.raise_compiler_error("The `stored_procedure` materialization currently supports SQL and Python models only.") }}
  {%- endif -%}
  {%- if returns is none or returns == '' -%}
    {{ exceptions.raise_compiler_error("Missing required config `returns`.") }}
  {%- endif -%}
  {%- if language == 'sql' and (temporary or secure) -%}
    {{ exceptions.raise_compiler_error("Snowflake Scripting stored procedures do not support `temporary` or `secure` in CREATE PROCEDURE syntax. Use a Python procedure or remove those configs.") }}
  {%- endif -%}

  create or replace{% if temporary %} temporary{% endif %}{% if secure %} secure{% endif %} procedure {{ relation }}({{ dbt_snowflake_cortex.procedure_arguments(arguments) }})
  {%- if copy_grants %}
  COPY GRANTS
  {%- endif %}
  RETURNS {{ returns }}
  LANGUAGE {{ language | upper }}
  {%- if language == 'python' %}
  RUNTIME_VERSION = {{ dbt_snowflake_cortex.sql_string(runtime_version) }}
    {%- if artifact_repository is not none and artifact_repository != '' %}
  ARTIFACT_REPOSITORY = {{ artifact_repository }}
    {%- endif %}
    {%- if packages is not none and packages != [] and packages != '' %}
  PACKAGES = ({{ dbt_snowflake_cortex.render_sql_string_list(packages, 'packages') }})
    {%- endif %}
    {%- if imports is not none and imports != [] and imports != '' %}
  IMPORTS = ({{ dbt_snowflake_cortex.render_sql_string_list(imports, 'imports') }})
    {%- endif %}
  HANDLER = {{ dbt_snowflake_cortex.sql_string(python_handler) }}
    {%- if external_access_integrations is not none and external_access_integrations != [] and external_access_integrations != '' %}
  EXTERNAL_ACCESS_INTEGRATIONS = ({{ dbt_snowflake_cortex.render_identifier_list(external_access_integrations, 'external_access_integrations') }})
    {%- endif %}
  {{ dbt_snowflake_cortex.secrets_clause(secrets) }}
  {%- endif %}
  {%- if null_input_behavior is not none and null_input_behavior != '' %}
  {{ null_input_behavior }}
  {%- endif %}
  {%- if volatility is not none and volatility != '' %}
  {{ volatility }}
  {%- endif %}
  {{ dbt_snowflake_cortex.comment_clause(comment) }}
  {%- if execute_as is not none and execute_as != '' %}
  EXECUTE AS {{ execute_as }}
  {%- endif %}
  AS
$$
{%- if language == 'python' and model_language == 'python' %}
{{ compiled_code }}


def _dbt_snowflake_cortex_main(session, *args):
    dbt = dbtObj(session.table)
    result = model(dbt, session)
    if callable(result):
        return result(*args)
    return result
{%- elif language == 'python' %}
{{ sql | trim }}
{%- else %}
{{ sql | trim }}
{%- endif %}
$$;

{%- endmacro %}


{% macro snowflake__create_or_replace_stored_procedure() %}
  {%- set identifier = model['alias'] -%}

  {%- set target_relation = api.Relation.create(
      identifier=identifier, schema=schema, database=database,
      type='external') -%}

  {{ run_hooks(pre_hooks) }}

  -- build stored procedure
  {% call statement('main') -%}
    {{ dbt_snowflake_cortex.snowflake__get_create_stored_procedure_sql(target_relation, sql, compiled_code | default(none)) }}
  {%- endcall %}

  {{ run_hooks(post_hooks) }}

  {{ return({'relations': [target_relation]}) }}

{% endmacro %}

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

{% macro sql_string(value) -%}
  '{{ (value | string).replace("'", "''") }}'
{%- endmacro %}


{% macro get_config(name, default=none) -%}
  {%- set meta = config.get('meta', default={}) -%}
  {%- if meta is mapping -%}
    {%- set package_meta = meta.get('dbt_snowflake_cortex', {}) -%}
    {%- if package_meta is mapping and name in package_meta -%}
      {%- do return(package_meta[name]) -%}
    {%- endif -%}
  {%- endif -%}
  {%- do return(config.get(name, default=default)) -%}
{%- endmacro %}


{% macro sql_bool(value) -%}
  {%- if value -%}TRUE{%- else -%}FALSE{%- endif -%}
{%- endmacro %}


{% macro object_comment(configured_comment=none) -%}
  {%- if configured_comment is not none -%}
    {%- do return(configured_comment) -%}
  {%- endif -%}
  {%- do return(model.get('description')) -%}
{%- endmacro %}


{% macro comment_clause(comment) -%}
  {%- if comment is not none and comment != '' -%}
    COMMENT = {{ dbt_snowflake_cortex.sql_string(comment) }}
  {%- endif -%}
{%- endmacro %}


{% macro profile_clause(profile) -%}
  {%- if profile is not none and profile != '' -%}
    {%- if profile is mapping -%}
      PROFILE = {{ dbt_snowflake_cortex.sql_string(profile | tojson) }}
    {%- else -%}
      PROFILE = {{ dbt_snowflake_cortex.sql_string(profile) }}
    {%- endif -%}
  {%- endif -%}
{%- endmacro %}


{% macro create_modifier(or_replace=true, if_not_exists=false) -%}
  {%- if or_replace and if_not_exists -%}
    {{ exceptions.raise_compiler_error("`or_replace` and `if_not_exists` are mutually exclusive.") }}
  {%- endif -%}
  {%- if or_replace -%}
    OR REPLACE
  {%- endif -%}
{%- endmacro %}


{% macro if_not_exists_clause(if_not_exists=false) -%}
  {%- if if_not_exists -%}
    IF NOT EXISTS
  {%- endif -%}
{%- endmacro %}


{% macro render_identifier_list(values, config_name) -%}
  {%- if values is none -%}
    {{ exceptions.raise_compiler_error("Missing required config `" ~ config_name ~ "`.") }}
  {%- elif values is string -%}
    {{ values }}
  {%- elif values is sequence and values | length > 0 -%}
    {%- for value in values -%}
      {{ value }}{{ ", " if not loop.last }}
    {%- endfor -%}
  {%- else -%}
    {{ exceptions.raise_compiler_error("Config `" ~ config_name ~ "` must be a string or a non-empty list.") }}
  {%- endif -%}
{%- endmacro %}


{% macro render_optional_identifier_list(values, config_name) -%}
  {%- if values is none -%}
  {%- elif values is string and values != '' -%}
    {{ values }}
  {%- elif values is sequence and values is not string and values | length > 0 -%}
    {%- for value in values -%}
      {{ value }}{{ ", " if not loop.last }}
    {%- endfor -%}
  {%- elif values != [] and values != '' -%}
    {{ exceptions.raise_compiler_error("Config `" ~ config_name ~ "` must be a string or a list.") }}
  {%- endif -%}
{%- endmacro %}


{% macro render_sql_string_list(values, config_name) -%}
  {%- if values is none -%}
  {%- elif values is string -%}
    {{ dbt_snowflake_cortex.sql_string(values) }}
  {%- elif values is sequence and values is not string -%}
    {%- for value in values -%}
      {{ dbt_snowflake_cortex.sql_string(value) }}{{ ", " if not loop.last }}
    {%- endfor -%}
  {%- else -%}
    {{ exceptions.raise_compiler_error("Config `" ~ config_name ~ "` must be a string or a list.") }}
  {%- endif -%}
{%- endmacro %}


{% macro procedure_arguments(arguments) -%}
  {%- if arguments is none -%}
  {%- elif arguments is string -%}
    {{ arguments }}
  {%- elif arguments is sequence and arguments is not string -%}
    {%- for argument in arguments -%}
      {%- if argument is mapping -%}
        {{ argument.get('name') }}{% if argument.get('mode') %} {{ argument.get('mode') }}{% endif %} {{ argument.get('data_type', argument.get('type')) }}{% if argument.get('default') is not none %} DEFAULT {{ argument.get('default') }}{% endif %}
      {%- else -%}
        {{ argument }}
      {%- endif -%}
      {{ ", " if not loop.last }}
    {%- endfor -%}
  {%- else -%}
    {{ exceptions.raise_compiler_error("Config `arguments` must be a string or a list.") }}
  {%- endif -%}
{%- endmacro %}


{% macro secrets_clause(secrets) -%}
  {%- if secrets is mapping and secrets | length > 0 -%}
    SECRETS = (
      {%- for variable_name, secret_name in secrets.items() -%}
        {{ dbt_snowflake_cortex.sql_string(variable_name) }} = {{ secret_name }}{{ ", " if not loop.last }}
      {%- endfor -%}
    )
  {%- elif secrets is not none and secrets != {} -%}
    {{ exceptions.raise_compiler_error("Config `secrets` must be a mapping of secret variable name to Snowflake secret identifier.") }}
  {%- endif -%}
{%- endmacro %}

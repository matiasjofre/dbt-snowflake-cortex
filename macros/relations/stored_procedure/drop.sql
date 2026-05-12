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

{% macro snowflake__get_drop_stored_procedure_sql(relation, argument_types=none) %}
    {%- if argument_types is none or argument_types == [] or argument_types == '' -%}
        drop procedure if exists {{ relation }}
    {%- else -%}
        drop procedure if exists {{ relation }}({{ dbt_snowflake_cortex.render_identifier_list(argument_types, 'argument_types') }})
    {%- endif -%}
{% endmacro %}

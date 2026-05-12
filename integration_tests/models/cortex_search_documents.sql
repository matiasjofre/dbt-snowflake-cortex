-- Copyright 2026 dbt-snowflake-cortex contributors
-- SPDX-License-Identifier: Apache-2.0

{{
  config(
    enabled=var('dbt_snowflake_cortex_enable_cortex_search_integration_tests', false),
    materialized='table'
  )
}}

select
  'doc-return-policy' as document_id,
  'Return policy' as title,
  'Gold members can return online orders within 30 days.' as body,
  'Retail Operations' as department,
  'North America' as region
union all
select
  'doc-shipping-policy' as document_id,
  'Shipping policy' as title,
  'Standard shipping orders leave the warehouse within two business days.' as body,
  'Retail Operations' as department,
  'North America' as region

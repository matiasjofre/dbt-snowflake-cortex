-- Copyright 2026 dbt-snowflake-cortex contributors
-- SPDX-License-Identifier: Apache-2.0

{% macro generate_sample_ddl() %}
  {%- set semantic_view_ddl -%}
create or replace semantic view DEV_DB.ANALYTICS.SV_RETAIL_ORDERS
TABLES (
  orders AS DEV_DB.ANALYTICS.FCT_ORDERS PRIMARY KEY (order_id),
  customers AS DEV_DB.ANALYTICS.DIM_CUSTOMERS PRIMARY KEY (customer_id)
)
RELATIONSHIPS (
  orders_to_customers AS orders(customer_id) REFERENCES customers(customer_id)
)
DIMENSIONS (
  orders.order_date AS orders.order_date,
  customers.customer_name AS customers.customer_name
)
METRICS (
  orders.order_count AS COUNT(*),
  orders.total_revenue AS SUM(orders.gross_revenue)
)
COMMENT = 'Retail orders semantic view.';
  {%- endset -%}

  {%- set search_service_ddl -%}
create or replace cortex search service DEV_DB.ANALYTICS.RETAIL_POLICY_SEARCH
  ON body
  PRIMARY KEY (document_id)
  ATTRIBUTES department, region
  WAREHOUSE = ANALYTICS_WH
  TARGET_LAG = '1 hour'
  EMBEDDING_MODEL = 'snowflake-arctic-embed-l-v2.0'
  REFRESH_MODE = INCREMENTAL
  INITIALIZE = ON_SCHEDULE
  FULL_INDEX_BUILD_INTERVAL_DAYS = 7
  REQUEST_LOGGING = TRUE
  AUTO_SUSPEND = 1800
  COMMENT = 'Search service for retail policy documents.'
AS
select document_id, title, body, department, region
from DEV_DB.ANALYTICS.RETAIL_POLICY_DOCUMENTS;
  {%- endset -%}

  {%- set stored_procedure_ddl -%}
create or replace procedure DEV_DB.ANALYTICS.GET_REVENUE_ROWS(MIN_ID NUMBER DEFAULT 0)
  RETURNS TABLE (ID NUMBER, REVENUE NUMBER)
  LANGUAGE SQL
  COMMENT = 'Returns retail revenue rows for Cortex Agent procedure tools.'
  EXECUTE AS CALLER
AS
$$
DECLARE
  res RESULTSET;
BEGIN
  res := (
    select id, revenue
    from DEV_DB.ANALYTICS.BASE_TABLE
    where id >= :MIN_ID
  );
  RETURN TABLE(res);
END
$$;
  {%- endset -%}

  {%- set agent_ddl -%}
create or replace agent DEV_DB.ANALYTICS.RETAIL_OPERATIONS_AGENT
  COMMENT = 'Retail operations assistant backed by dbt-managed Cortex objects.'
  PROFILE = '{"display_name":"Retail Operations","avatar":"shopping-cart.png","color":"green"}'
  FROM SPECIFICATION
$$
models:
  orchestration: claude-4-sonnet
instructions:
  response: "Answer concisely and name the tool used."
  orchestration: "Use Analyst for metrics, Search for policies, and RevenueProcedure for controlled row lookups."
tools:
  - tool_spec:
      type: "cortex_analyst_text_to_sql"
      name: "Analyst"
      description: "Answers analytics questions using the retail semantic view."
  - tool_spec:
      type: "cortex_search"
      name: "Search"
      description: "Searches retail policy documents."
  - tool_spec:
      type: "generic"
      name: "RevenueProcedure"
      description: "Calls a stored procedure that returns revenue rows."
      input_schema:
        type: "object"
        properties:
          min_id:
            type: "number"
            description: "Minimum id to return."
        required:
          - min_id
tool_resources:
  Analyst:
    semantic_view: "DEV_DB.ANALYTICS.SV_RETAIL_ORDERS"
  Search:
    name: "DEV_DB.ANALYTICS.RETAIL_POLICY_SEARCH"
    max_results: "5"
    title_column: "title"
    id_column: "document_id"
  RevenueProcedure:
    type: "procedure"
    identifier: "DEV_DB.ANALYTICS.GET_REVENUE_ROWS"
    execution_environment:
      type: "warehouse"
      warehouse: "ANALYTICS_WH"
      query_timeout: 60
$$;
  {%- endset -%}

  {%- set mcp_server_ddl -%}
create or replace mcp server DEV_DB.ANALYTICS.RETAIL_OPERATIONS_MCP
  from specification
$$
tools:
  - name: "retail-orders-analyst"
    type: "CORTEX_ANALYST_MESSAGE"
    identifier: "DEV_DB.ANALYTICS.SV_RETAIL_ORDERS"
    description: "Answers retail order, revenue, customer, and channel questions."
    title: "Retail Orders Analyst"
  - name: "policy-search"
    type: "CORTEX_SEARCH_SERVICE_QUERY"
    identifier: "DEV_DB.ANALYTICS.RETAIL_POLICY_SEARCH"
    description: "Searches retail operating procedures and return policies."
    title: "Retail Policy Search"
  - name: "sql-exec"
    type: "SYSTEM_EXECUTE_SQL"
    description: "Executes SQL against the connected Snowflake database."
    title: "SQL Execution"
$$;

comment on mcp server DEV_DB.ANALYTICS.RETAIL_OPERATIONS_MCP is 'Retail MCP server backed by dbt-managed Cortex objects.';
  {%- endset -%}

  {{ log("\n-- semantic view\n" ~ semantic_view_ddl, info=true) }}
  {{ log("\n-- cortex search service\n" ~ search_service_ddl, info=true) }}
  {{ log("\n-- stored procedure\n" ~ stored_procedure_ddl, info=true) }}
  {{ log("\n-- cortex agent\n" ~ agent_ddl, info=true) }}
  {{ log("\n-- mcp server\n" ~ mcp_server_ddl, info=true) }}
{% endmacro %}

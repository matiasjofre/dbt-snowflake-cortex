## dbt-snowflake-cortex

dbt materializations for managing Snowflake Cortex objects as code.

This package currently supports:

- `semantic_view`: create Snowflake Semantic Views from dbt models.
- `cortex_agent`: create Snowflake Cortex Agents from dbt models.
- `cortex_search_service`: create Snowflake Cortex Search services from dbt models.
- `mcp_server`: create Snowflake-managed MCP Servers from dbt models.
- `stored_procedure`: create Snowflake SQL and Python stored procedures from dbt models.

The package is Snowflake-only. It keeps Snowflake's DDL syntax as the source of
truth and uses dbt configs only for object-level clauses that are awkward to
repeat in every model.

### Attribution

This package is a fork and extension of
[Snowflake-Labs/dbt_semantic_view](https://github.com/Snowflake-Labs/dbt_semantic_view),
which is licensed under the Apache License 2.0.

The original Semantic View materialization is preserved and extended here. This
fork renames the package to `dbt_snowflake_cortex` and adds support for managing
additional Snowflake Cortex objects.

### Compatibility

- Warehouse: Snowflake
- dbt package name: `dbt_snowflake_cortex`
- dbt compatibility: dbt 1.x

This package does not parse or reimplement Snowflake's Cortex object grammars.
When Snowflake adds supported syntax to Cortex object DDL, the package can use
that syntax directly in the model body.
Custom materialization options are placed under `meta.dbt_snowflake_cortex` so
the package works with dbt engines that validate model config keys strictly.

Snowflake references:

- [CREATE SEMANTIC VIEW](https://docs.snowflake.com/en/sql-reference/sql/create-semantic-view)
- [CREATE AGENT](https://docs.snowflake.com/en/sql-reference/sql/create-agent)
- [CREATE CORTEX SEARCH SERVICE](https://docs.snowflake.com/en/sql-reference/sql/create-cortex-search)
- [CREATE MCP SERVER](https://docs.snowflake.com/en/sql-reference/sql/create-mcp-server)
- [CREATE PROCEDURE](https://docs.snowflake.com/en/sql-reference/sql/create-procedure)

### Installation

Install this package instead of `Snowflake-Labs/dbt_semantic_view`. Do not
install both packages in the same dbt project because both define a
`semantic_view` materialization.

Until the package is published to dbt Hub, install it from Git:

```yaml
packages:
  - git: "https://github.com/<org>/dbt-snowflake-cortex.git"
    revision: v1.1.0
```

For local development, the integration test project installs the package from
the parent directory:

```yaml
packages:
  - local: ../
```

### Semantic Views

Create a model with `materialized='semantic_view'`. The model body should start
after the object name; the materialization adds `CREATE OR REPLACE SEMANTIC VIEW
<target_relation>`.

For example, a retail analytics semantic view could live at
`models/semantic_views/sv_retail_orders.sql`. The referenced models and Cortex
Search service below are illustrative; replace them with objects from your
project.

```sql
{{ config(materialized='semantic_view', static_analysis='off') }}

TABLES (
  orders AS {{ ref('fct_orders') }}
    PRIMARY KEY (order_id)
    UNIQUE (order_number)
    WITH SYNONYMS = ('purchase', 'sale', 'transaction')
    COMMENT = 'One row per customer order.'
    TAG (domain = 'retail', owner = 'analytics'),

  customers AS {{ ref('dim_customers') }}
    PRIMARY KEY (customer_id)
    WITH SYNONYMS = ('buyer', 'shopper')
    COMMENT = 'Customer profile and lifecycle attributes.'
    TAG (domain = 'retail', owner = 'analytics'),

  price_periods AS {{ ref('dim_product_price_periods') }}
    PRIMARY KEY (price_period_id)
    CONSTRAINT price_period_validity
      DISTINCT RANGE BETWEEN valid_from AND valid_to EXCLUSIVE
    COMMENT = 'Product price validity windows.'
)

RELATIONSHIPS (
  customer_to_orders AS orders(customer_id)
    REFERENCES customers(customer_id),

  order_price_period AS orders(order_date)
    REFERENCES price_periods(BETWEEN valid_from AND valid_to EXCLUSIVE)
)

FACTS (
  PUBLIC orders.gross_revenue AS orders.gross_revenue
    WITH SYNONYMS = ('sales', 'gmv')
    TAG (sensitivity = 'internal')
    COMMENT = 'Gross order revenue before refunds.',

  PRIVATE orders.margin_amount AS orders.margin_amount
    COMMENT = 'Order margin. Private so users cannot query it directly.',

  PUBLIC orders.is_discounted LABELS = ( FILTER )
    AS orders.discount_amount > 0
    COMMENT = 'Boolean filter for discounted orders.'
)

DIMENSIONS (
  PUBLIC orders.order_date AS orders.order_date
    COMMENT = 'Date the order was placed.',

  customers.customer_name AS customers.customer_name
    WITH SYNONYMS = ('customer', 'account')
    COMMENT = 'Customer display name.'
    WITH CORTEX SEARCH SERVICE customer_name_search_service USING customer_name,

  orders.sales_channel AS orders.sales_channel
    TAG (semantic_role = 'segment')
    COMMENT = 'Channel where the order was placed.'
)

METRICS (
  PUBLIC orders.order_count AS COUNT(*)
    COMMENT = 'Number of orders.',

  PUBLIC orders.total_revenue USING (customer_to_orders)
    AS SUM(orders.gross_revenue)
    WITH SYNONYMS = ('sales', 'revenue')
    TAG (certified = 'true')
    COMMENT = 'Total gross revenue.',

  PRIVATE orders.total_margin AS SUM(orders.margin_amount)
    COMMENT = 'Total margin. Available for derived metrics only.',

  PUBLIC orders.average_order_value
    AS SUM(orders.gross_revenue) / NULLIF(COUNT(*), 0)
    COMMENT = 'Average gross revenue per order.',

  PUBLIC orders.latest_customer_count
    NON ADDITIVE BY (orders.order_date DESC NULLS LAST)
    AS COUNT(DISTINCT orders.customer_id)
    COMMENT = 'Semi-additive customer count for snapshot-style reporting.',

  PUBLIC orders.revenue_7_day_moving_average AS
    AVG(orders.total_revenue) OVER (
      PARTITION BY EXCLUDING orders.order_date
      ORDER BY orders.order_date
      ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    )
    COMMENT = 'Seven-day moving average revenue.'
)

COMMENT = 'Retail orders semantic view for revenue, customer, and channel analytics.'

AI_SQL_GENERATION
'- Use total_revenue for revenue, sales, and GMV questions.
- When the user asks for trends, group by orders.order_date and sort ascending.
- When the user asks about customers by name, filter customers.customer_name ILIKE the provided name.
- Use sales_channel for online, store, marketplace, and partner channel breakdowns.'

AI_QUESTION_CATEGORIZATION
'- Use this semantic view for order counts, revenue, customer purchasing behavior, and sales channel performance.
- Do not use this semantic view for inventory, fulfillment, marketing spend, or support ticket questions.'

AI_VERIFIED_QUERIES (
  revenue_last_30_days AS (
    QUESTION 'What was revenue in the last 30 days?'
    VERIFIED_AT 1735689600
    ONBOARDING_QUESTION true
    VERIFIED_BY '( analyst = analytics@example.com )'
    SQL 'SELECT * FROM SEMANTIC_VIEW(sv_retail_orders METRICS total_revenue WHERE order_date >= CURRENT_DATE - 30)'
  )
)

TAG (domain = 'retail', lifecycle = 'production')
COPY GRANTS
```

To preserve grants when replacing a semantic view, either include `COPY GRANTS`
in the model body or configure it in YAML:

```yaml
models:
  - name: sv_retail_orders
    config:
      copy_grants: true
```

### Cortex Search Services

Create a model with `materialized='cortex_search_service'`. The model body is
the source query after the `AS` keyword; the materialization adds
`CREATE OR REPLACE CORTEX SEARCH SERVICE <target_relation>` and the configured
service clauses.

Use `ref()` in the source query so dbt builds the indexed data before the search
service.

```sql
{{
  config(
    materialized='cortex_search_service',
    meta={
      'dbt_snowflake_cortex': {
        'search_column': 'body',
        'primary_key': ['document_id'],
        'attributes': ['department', 'region'],
        'warehouse': target.warehouse,
        'target_lag': '1 hour',
        'embedding_model': 'snowflake-arctic-embed-l-v2.0',
        'refresh_mode': 'INCREMENTAL',
        'initialize': 'ON_SCHEDULE',
        'full_index_build_interval_days': 7,
        'request_logging': true,
        'auto_suspend': 1800,
        'comment': 'Search service for retail policy documents.'
      }
    }
  )
}}

select
  document_id,
  title,
  body,
  department,
  region
from {{ ref('retail_policy_documents') }}
```

For multi-index Cortex Search, pass Snowflake's index specifications directly:

```sql
{{
  config(
    materialized='cortex_search_service',
    meta={
      'dbt_snowflake_cortex': {
        'text_indexes': ['title', 'body'],
        'vector_indexes': ["body (model='snowflake-arctic-embed-m-v1.5')"],
        'primary_key': ['document_id'],
        'attributes': ['department', 'region'],
        'warehouse': target.warehouse,
        'target_lag': '1 hour'
      }
    }
  )
}}

select * from {{ ref('retail_policy_documents') }}
```

### Stored Procedures

Create SQL stored procedures with `materialized='stored_procedure'`. The model
body is the Snowflake Scripting procedure body.

```sql
{{
  config(
    materialized='stored_procedure',
    meta={
      'dbt_snowflake_cortex': {
        'arguments': [
          {'name': 'MIN_ID', 'type': 'NUMBER', 'default': '0'}
        ],
        'returns': 'TABLE (ID NUMBER, REVENUE NUMBER)',
        'execute_as': 'CALLER',
        'comment': 'Returns retail revenue rows.'
      }
    }
  )
}}

DECLARE
  res RESULTSET;
BEGIN
  res := (
    select id, revenue
    from {{ ref('fct_orders') }}
    where id >= :MIN_ID
  );
  RETURN TABLE(res);
END
```

Python procedures can also be managed from SQL model files by setting
`procedure_language` to `PYTHON`. This keeps the package compatible with dbt
engines that do not allow custom materializations on Python model files.

```sql
{{
  config(
    materialized='stored_procedure',
    static_analysis='off',
    meta={
      'dbt_snowflake_cortex': {
        'procedure_language': 'PYTHON',
        'arguments': ['NAME STRING'],
        'returns': 'TABLE (GREETING STRING)',
        'runtime_version': '3.10',
        'packages': ['snowflake-snowpark-python'],
        'handler': 'main',
        'execute_as': 'CALLER'
      }
    }
  )
}}

def main(session, name):
    return session.create_dataframe(
        [[f"hello {name}"]],
        schema=["GREETING"],
    )
```

### Cortex Agents

Create a model with `materialized='cortex_agent'`. By default, the model body is
the YAML specification object; the materialization adds
`CREATE OR REPLACE AGENT <target_relation>`, optional `COMMENT`, optional
`PROFILE`, and `FROM SPECIFICATION $$ ... $$`.

Use `ref()` for semantic views, Cortex Search services, or other dbt-managed
objects so dbt can build dependencies in the right order.

For example, a Cortex Agent that uses the semantic view above could live at
`models/cortex_agents/retail_operations_agent.sql`.

```sql
{{
  config(
    materialized='cortex_agent',
    static_analysis='off',
    meta={
      'dbt_snowflake_cortex': {
        'comment': 'Retail operations assistant backed by dbt-managed Cortex objects.',
        'profile': {
          'display_name': 'Retail Operations',
          'avatar': 'shopping-cart.png',
          'color': 'green'
        }
      }
    }
  )
}}

models:
  orchestration: claude-4-sonnet

orchestration:
  budget:
    seconds: 30
    tokens: 16000

instructions:
  response: "Answer in concise business language. Mention the metric and dimension names used when helpful."
  orchestration: "Use retail_orders_analyst for order, revenue, customer, and sales channel questions. Use policy_search for operating policy or return policy questions."
  sample_questions:
    - question: "How many orders did we have last month?"
    - question: "Which sales channel has the most revenue this quarter?"
    - question: "What is our return policy for online orders?"

tools:
  - tool_spec:
      type: "cortex_analyst_text_to_sql"
      name: "retail_orders_analyst"
      description: "Converts natural language retail analytics questions to SQL using the retail orders semantic view."

  - tool_spec:
      type: "cortex_search"
      name: "policy_search"
      description: "Searches retail operating procedures, return policies, and fulfillment guidance."

  - tool_spec:
      type: "generic"
      name: "revenue_rows"
      description: "Calls a governed stored procedure that returns revenue rows."
      input_schema:
        type: "object"
        properties:
          min_id:
            type: "number"
            description: "Minimum id to return."
        required:
          - min_id

tool_resources:
  retail_orders_analyst:
    semantic_view: "{{ ref('sv_retail_orders') }}"

  policy_search:
    name: "{{ ref('retail_policy_search_service') }}"
    max_results: "5"
    filter:
      "@eq":
        department: "Retail Operations"
    title_column: "title"
    id_column: "document_id"

  revenue_rows:
    type: "procedure"
    identifier: "{{ ref('get_revenue_rows') }}"
    execution_environment:
      type: "warehouse"
      warehouse: "{{ target.warehouse }}"
      query_timeout: 60
```

To use the older pass-through style, set
`meta.dbt_snowflake_cortex.agent_body_mode: raw` or start the model body with
`COMMENT`, `PROFILE`, or `FROM SPECIFICATION`; the package will then append the
body directly after `CREATE OR REPLACE AGENT <target_relation>`.

The important dependency edges are the `ref()` calls inside `tool_resources`.
dbt will compile them to fully qualified names and build the semantic view,
search service, and stored procedure before the agent.

### MCP Servers

Create a model with `materialized='mcp_server'`. By default, the model body is
the YAML specification object; the materialization adds
`CREATE OR REPLACE MCP SERVER <target_relation> FROM SPECIFICATION $$ ... $$`.

Use `ref()` for semantic views, Cortex Search services, Cortex Agents, UDFs, or
stored procedures so dbt can build dependencies in the right order.

```sql
{{
  config(
    materialized='mcp_server',
    static_analysis='off',
    meta={
      'dbt_snowflake_cortex': {
        'comment': 'Retail MCP server backed by dbt-managed Cortex objects.'
      }
    }
  )
}}

tools:
  - name: "retail-orders-analyst"
    type: "CORTEX_ANALYST_MESSAGE"
    identifier: "{{ ref('sv_retail_orders') }}"
    description: "Answers retail order, revenue, customer, and channel questions."
    title: "Retail Orders Analyst"

  - name: "policy-search"
    type: "CORTEX_SEARCH_SERVICE_QUERY"
    identifier: "{{ ref('retail_policy_search_service') }}"
    description: "Searches retail operating procedures and return policies."
    title: "Retail Policy Search"

  - name: "sql-exec"
    type: "SYSTEM_EXECUTE_SQL"
    description: "Executes SQL against the connected Snowflake database."
    title: "SQL Execution"
```

To use the pass-through style, set
`meta.dbt_snowflake_cortex.mcp_server_body_mode: raw` or start the model body
with `FROM SPECIFICATION`; the package will then append the body directly after
`CREATE OR REPLACE MCP SERVER <target_relation>`.

Snowflake's `CREATE MCP SERVER` syntax does not include an inline `COMMENT`
clause. When `meta.dbt_snowflake_cortex.comment` or a model description is set,
the materialization applies it after creation with `COMMENT ON MCP SERVER`.

### Documentation Persistence

dbt-driven documentation persistence for Cortex object comments is not currently
implemented by this package. Inline Snowflake comments and
`meta.dbt_snowflake_cortex.comment` are supported by each materialization.

For Semantic Views, use inline `COMMENT` syntax in the semantic view definition.
For Cortex Agents, Cortex Search services, stored procedures, and MCP Servers,
use the package `comment` config.

### Development

Python 3.9+ is recommended.

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -U pip
pip install dbt-snowflake
```

Configure Snowflake credentials for the integration profile:

```bash
export SNOWFLAKE_TEST_ACCOUNT=<account>
export SNOWFLAKE_TEST_USER=<user>
export SNOWFLAKE_TEST_PASSWORD=<password>
export SNOWFLAKE_TEST_AUTHENTICATOR=<authenticator>
export SNOWFLAKE_TEST_ROLE=<role>
export SNOWFLAKE_TEST_DATABASE=<database>
export SNOWFLAKE_TEST_WAREHOUSE=<warehouse>
export SNOWFLAKE_TEST_SCHEMA=<schema>
```

Run the integration project:

```bash
cd integration_tests/
dbt deps --target snowflake
dbt build --target snowflake
```

Search service, stored procedure, and MCP Server fixtures are opt-in because
they require additional privileges and may create Cortex serving/indexing or MCP
resources:

```bash
dbt build --target snowflake \
  --vars '{
    "dbt_snowflake_cortex_enable_cortex_search_integration_tests": true,
    "dbt_snowflake_cortex_enable_stored_procedure_integration_tests": true,
    "dbt_snowflake_cortex_enable_agent_tool_integration_tests": true,
    "dbt_snowflake_cortex_enable_mcp_server_integration_tests": true
  }'
```

The role used for integration tests needs the privileges required by the objects
under test, including `CREATE SEMANTIC VIEW`, `CREATE AGENT`,
`CREATE CORTEX SEARCH SERVICE`, `CREATE MCP SERVER`, `CREATE PROCEDURE`,
warehouse `USAGE`, Cortex database roles for embedding/search, and access to
referenced objects.

To inspect representative DDL without creating Snowflake objects:

```bash
dbt run-operation generate_sample_ddl --target snowflake
```

### License

Apache License 2.0. See `LICENSE` for details.

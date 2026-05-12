## dbt-snowflake-cortex

dbt materializations for managing Snowflake Cortex objects as code.

This package currently supports:

- `semantic_view`: create Snowflake Semantic Views from dbt models.
- `cortex_agent`: create Snowflake Cortex Agents from dbt models.

The package is Snowflake-only. It intentionally keeps the model body as a SQL
passthrough so Snowflake remains the source of truth for object validation and
new Cortex syntax.

### Attribution

This package is a fork and extension of
[Snowflake-Labs/dbt_semantic_view](https://github.com/Snowflake-Labs/dbt_semantic_view),
which is licensed under the Apache License 2.0.

The original Semantic View materialization is preserved and extended here. This
fork renames the package to `dbt_snowflake_cortex` and adds support for managing
additional Snowflake Cortex objects, starting with Cortex Agents.

### Compatibility

- Warehouse: Snowflake
- dbt package name: `dbt_snowflake_cortex`
- dbt compatibility: dbt 1.x

This package does not parse or reimplement Snowflake's Cortex object grammars.
When Snowflake adds supported syntax to `CREATE SEMANTIC VIEW` or
`CREATE AGENT`, the package can use that syntax directly in the model body.

Snowflake references:

- [CREATE SEMANTIC VIEW](https://docs.snowflake.com/en/sql-reference/sql/create-semantic-view)
- [CREATE AGENT](https://docs.snowflake.com/en/sql-reference/sql/create-agent)

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

### Cortex Agents

Create a model with `materialized='cortex_agent'`. The model body should start
after the object name; the materialization adds `CREATE OR REPLACE AGENT
<target_relation>`.

Use `ref()` for semantic views, Cortex Search services, or other dbt-managed
objects so dbt can build dependencies in the right order.

For example, a Cortex Agent that uses the semantic view above could live at
`models/cortex_agents/retail_operations_agent.sql`.

```sql
{{ config(materialized='cortex_agent', static_analysis='off') }}

COMMENT = 'Retail operations assistant backed by dbt-managed Cortex objects.'
PROFILE = '{"display_name": "Retail Operations", "avatar": "shopping-cart.png", "color": "green"}'
FROM SPECIFICATION
$$
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

tool_resources:
  retail_orders_analyst:
    semantic_view: "{{ ref('sv_retail_orders') }}"

  policy_search:
    name: "{{ target.database }}.{{ target.schema }}.retail_policy_search_service"
    max_results: "5"
    filter:
      "@eq":
        department: "Retail Operations"
    title_column: "title"
    id_column: "document_id"
$$
```

The package uses a passthrough strategy, so newer Snowflake-supported `CREATE
AGENT` clauses can also be used directly in the model body as long as the
compiled SQL is valid in Snowflake.

The important dependency edge is the `ref()` inside the agent specification:
`semantic_view: "{{ ref('sv_retail_orders') }}"`. dbt will compile that reference to
the fully qualified semantic view name and build the semantic view before the
agent.

### Documentation Persistence

dbt-driven documentation persistence for Semantic Views and Cortex Agents is not
currently implemented by this package. Inline Snowflake comments are supported
because they are part of the SQL body sent to Snowflake.

For Semantic Views, use inline `COMMENT` syntax in the semantic view definition.
For Cortex Agents, use the `COMMENT` clause and agent specification metadata.

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

The role used for integration tests needs the privileges required by the objects
under test, including `CREATE SEMANTIC VIEW` and `CREATE AGENT` on the target
schema, plus access to referenced objects.

### License

Apache License 2.0. See `LICENSE` for details.

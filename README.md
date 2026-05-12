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
    revision: v0.1.0
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

```sql
{{ config(materialized='semantic_view') }}

TABLES (
  orders AS {{ ref('orders') }}
    PRIMARY KEY (order_id)
    COMMENT = 'Order-level fact table.'
)

DIMENSIONS (
  orders.order_date AS order_date
    COMMENT = 'Date the order was placed.'
)

METRICS (
  orders.order_count AS COUNT(*)
    COMMENT = 'Number of orders.'
)

COMMENT = 'Order analytics semantic view.'
```

To preserve grants when replacing a semantic view, either include `COPY GRANTS`
in the model body or configure it in YAML:

```yaml
models:
  - name: sv_orders
    config:
      copy_grants: true
```

### Cortex Agents

Create a model with `materialized='cortex_agent'`. The model body should start
after the object name; the materialization adds `CREATE OR REPLACE AGENT
<target_relation>`.

Use `ref()` for semantic views, Cortex Search services, or other dbt-managed
objects so dbt can build dependencies in the right order.

```sql
{{ config(materialized='cortex_agent', static_analysis='off') }}

COMMENT = 'Orders assistant backed by a dbt-managed semantic view.'
PROFILE = '{"display_name": "Orders Assistant", "color": "blue"}'
FROM SPECIFICATION
$$
models:
  orchestration: claude-4-sonnet

instructions:
  response: "Answer concisely and cite the metric names you used."
  orchestration: "Route order analytics questions to orders_analyst."
  sample_questions:
    - question: "How many orders did we have last month?"

tools:
  - tool_spec:
      type: "cortex_analyst_text_to_sql"
      name: "orders_analyst"
      description: "Converts natural language order questions to SQL."

tool_resources:
  orders_analyst:
    semantic_view: "{{ ref('sv_orders') }}"
$$
```

The package uses a passthrough strategy, so newer Snowflake-supported `CREATE
AGENT` clauses can also be used directly in the model body as long as the
compiled SQL is valid in Snowflake.

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

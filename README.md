# Assignment 1 — Sunrise Supermarket Sales Analysis

**Student:** Fumba Huriro
**Student ID:** 25401
**Programme:** BSc Information Management, Adventist University of Central Africa (AUCA)
**Course:** Database Development with PL/SQL
**Submission date:** September 2026
**DBMS used:** PostgreSQL 17 (psql command-line shell)

---

## 1. Business Scenario

Sunrise Supermarket is a retail store operating in Rwanda, serving customers
across Kigali, Huye, Musanze and Rubavu. The store sells fast-moving consumer
goods across four categories: Beverages, Groceries, Household and Personal Care.

Management wants to move from gut feeling to evidence when answering everyday
commercial questions:

- Who are our most valuable customers, and how much are they actually worth?
- Which customers are registered but have never bought anything?
- How is revenue accumulating over the month?
- How often does each customer come back, and how long is the gap between visits?

This project builds a small relational database for the supermarket and answers
those questions using SQL joins, a common table expression (CTE) and window
functions.

> **Note on the DBMS:** the assignment permits Oracle, PostgreSQL, MySQL,
> SQL Server or another SQL tool. PostgreSQL was used. All queries are
> standard ANSI SQL and the window functions used (`RANK`, `ROW_NUMBER`,
> `LAG`, windowed `SUM` and `COUNT`) behave identically in Oracle.

---

## 2. Database Design

### Entity Relationship (logical)

```
customers (1) ──< orders (1) ──< order_items >── (1) products
```

- One customer can place many orders.
- One order can contain many order items.
- One product can appear in many order items.
- `order_items` is the junction table that resolves the many-to-many
  relationship between `orders` and `products`, and it carries the
  `quantity` attribute.

### Tables

| Table | Purpose | Key columns |
|---|---|---|
| `customers` | Registered shoppers | `customer_id` (PK), `customer_name`, `email`, `city` |
| `products` | Items on the shelves | `product_id` (PK), `product_name`, `category`, `price` |
| `orders` | One shopping transaction | `order_id` (PK), `customer_id` (FK), `order_date` |
| `order_items` | Line items within an order | `order_item_id` (PK), `order_id` (FK), `product_id` (FK), `quantity` |

### Data volume

| Table | Rows | Requirement |
|---|---|---|
| `customers` | 5 | met |
| `products` | 8 across 4 categories | met |
| `orders` | 15 | met |
| `order_items` | 30 | exceeds the minimum of 25 |

**Deliberate design choice:** customer 5 (Patrick Habimana) is registered but
has placed **no orders**. This is not an oversight — it is what makes the
LEFT JOIN in Query 3 demonstrate something real rather than returning the
same result as an INNER JOIN.

Revenue is never stored. It is always derived as
`quantity x price` by joining `order_items` to `products`. This avoids
redundant data and keeps the schema normalised: if a price is corrected,
every report corrects itself.

---

## 3. Repository Contents

```
assignment_1_sunrise_supermarket/
├── README.md                          # this file
├── sunrise_supermarket.sql            # full script: DDL, inserts, all 8 queries
└── screenshots/
    ├── 01_inner_join_orders_customers.png
    ├── 02_join_order_items_products.png
    ├── 03_left_join_customers_orders.png
    ├── 04_cte_above_average_spend.png
    ├── 05_rank_customers.png
    ├── 06_number_customer_orders.png
    ├── 07_running_revenue.png
    └── 08_days_between_orders.png
```

---

## 4. How to Reproduce

1. Install PostgreSQL and open **SQL Shell (psql)**.
2. Accept the defaults for Server, Database, Port and Username by pressing
   Enter, then enter the `postgres` password.
3. Improve readability of the output:
   ```sql
   \pset pager off
   ```
4. Run the script:
   ```sql
   \i sunrise_supermarket.sql
   ```
   Or paste the DDL, the inserts and then each query in turn.
5. Verify the data loaded:
   ```sql
   SELECT COUNT(*) FROM customers;    -- 5
   SELECT COUNT(*) FROM products;     -- 8
   SELECT COUNT(*) FROM orders;       -- 15
   SELECT COUNT(*) FROM order_items;  -- 30
   ```

---

## 5. The Queries

### Query 1 — INNER JOIN: every order with its customer

**Question:** which customer placed each order, and from which city?

```sql
SELECT o.order_id, c.customer_name, c.city, o.order_date
FROM orders o
INNER JOIN customers c ON o.customer_id = c.customer_id
ORDER BY o.order_date;
```

**Technique:** `INNER JOIN` on the foreign key `orders.customer_id`.

**Business interpretation:** the raw `orders` table stores only a numeric
customer ID, which is meaningless to a store manager. The join turns it into
a readable transaction log showing who bought and where they are based.
Because it is an INNER JOIN, only orders with a matching customer appear —
15 rows, one per order.

*Screenshot: `01_inner_join_orders_customers.png`*

---

### Query 2 — INNER JOIN: order lines with product detail

**Question:** what exactly was in each order, and at what price?

```sql
SELECT oi.order_item_id, oi.order_id, p.product_name,
       p.category, p.price, oi.quantity
FROM order_items oi
INNER JOIN products p ON oi.product_id = p.product_id
ORDER BY oi.order_id, oi.order_item_id;
```

**Technique:** `INNER JOIN` across the junction table to the product catalogue.

**Business interpretation:** this is the basket-level view. It exposes what
is actually selling and in what quantities, which is the input to restocking
decisions. It also shows category mix per basket — useful for spotting that
Groceries carry the high unit prices while Beverages drive volume.

*Screenshot: `02_join_order_items_products.png`*

---

### Query 3 — LEFT JOIN: all customers, including non-buyers

**Question:** are there registered customers who have never bought anything?

```sql
SELECT c.customer_id, c.customer_name, c.city, o.order_id, o.order_date
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
ORDER BY c.customer_id, o.order_date;
```

**Technique:** `LEFT JOIN` preserves every row from `customers` even when no
matching order exists, filling the order columns with `NULL`.

**Business interpretation:** Patrick Habimana appears with `NULL` order
details. He signed up but never purchased. Commercially this is the most
actionable row in the whole result set: it identifies a dormant account for
a re-engagement campaign. An INNER JOIN would have hidden him completely,
and the store would never know he existed as a lost opportunity.

*Screenshot: `03_left_join_customers_orders.png`*

---

### Query 4 — CTE: customers spending above average

**Question:** which customers spend more than the average customer?

```sql
WITH customer_totals AS (
    SELECT c.customer_id, c.customer_name,
           SUM(oi.quantity * p.price) AS total_spend
    FROM customers c
    JOIN orders o       ON c.customer_id = o.customer_id
    JOIN order_items oi ON o.order_id    = oi.order_id
    JOIN products p     ON oi.product_id = p.product_id
    GROUP BY c.customer_id, c.customer_name
)
SELECT customer_id, customer_name, total_spend
FROM customer_totals
WHERE total_spend > (SELECT AVG(total_spend) FROM customer_totals)
ORDER BY total_spend DESC;
```

**Technique:** a common table expression (`WITH`) computes each customer's
total spend once, and the outer query references it **twice** — once to list
the customers and once inside a subquery to compute the average.

**Why a CTE and not a subquery?** Without the CTE the same four-table
aggregation would have to be written out twice, which is longer, slower to
read and easy to get out of sync when edited. The CTE names the intermediate
result and makes the logic read like the business question: "work out what
each customer spent, then keep the ones above the average."

**Business interpretation:** these are the customers carrying the store's
revenue. They are the natural target for a loyalty programme, because
retaining one of them is worth more than acquiring several average shoppers.

*Screenshot: `04_cte_above_average_spend.png`*

---

### Query 5 — Window function: `RANK()` customers by spend

**Question:** who is number one, number two, number three?

```sql
WITH customer_totals AS (
    SELECT c.customer_id, c.customer_name,
           SUM(oi.quantity * p.price) AS total_spend
    FROM customers c
    JOIN orders o       ON c.customer_id = o.customer_id
    JOIN order_items oi ON o.order_id    = oi.order_id
    JOIN products p     ON oi.product_id = p.product_id
    GROUP BY c.customer_id, c.customer_name
)
SELECT customer_id, customer_name, total_spend,
       RANK() OVER (ORDER BY total_spend DESC) AS spending_rank
FROM customer_totals
ORDER BY spending_rank;
```

**Technique:** `RANK() OVER (ORDER BY total_spend DESC)`.

**Why a window function?** A plain `GROUP BY` can produce the totals but
cannot number them relative to each other without extra self-joins. The
window function assigns a position to each row while still returning every
row — the aggregate and the detail coexist.

**Note on `RANK` vs `DENSE_RANK`:** `RANK` leaves gaps after ties
(1, 2, 2, 4). That is the correct behaviour for a leaderboard, where two
customers tied for second means nobody is third.

**Business interpretation:** gives management a defensible ordering for
tiered rewards instead of an impression of who "feels" like a big spender.

*Screenshot: `05_rank_customers.png`*

---

### Query 6 — Window function: `ROW_NUMBER()` per customer

**Question:** for each customer, was this their first, second or third visit?

```sql
SELECT o.customer_id, c.customer_name, o.order_id, o.order_date,
       ROW_NUMBER() OVER (
           PARTITION BY o.customer_id
           ORDER BY o.order_date
       ) AS order_number
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
ORDER BY o.customer_id, o.order_date;
```

**Technique:** `ROW_NUMBER()` with `PARTITION BY`. The partition restarts the
counter for every customer, so each person's orders are numbered 1, 2, 3
from their own first purchase rather than continuously across the table.

**Business interpretation:** this converts a flat transaction list into a
customer journey. It makes it possible to isolate first purchases (where
`order_number = 1`) to measure acquisition, or to study what a customer
typically buys on their second visit versus their first.

*Screenshot: `06_number_customer_orders.png`*

---

### Query 7 — Window function: running total of revenue

**Question:** how is revenue accumulating through the month?

```sql
WITH daily_revenue AS (
    SELECT o.order_date, SUM(oi.quantity * p.price) AS daily_revenue
    FROM orders o
    JOIN order_items oi ON o.order_id    = oi.order_id
    JOIN products p     ON oi.product_id = p.product_id
    GROUP BY o.order_date
)
SELECT order_date, daily_revenue,
       SUM(daily_revenue) OVER (
           ORDER BY order_date
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ) AS running_total
FROM daily_revenue
ORDER BY order_date;
```

**Technique:** an aggregate used as a window function. The frame clause
`ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` sums every row from the
start of the period up to the current date, producing a cumulative figure
rather than one grand total.

**Business interpretation:** the daily column shows volatility; the running
total shows progress. A manager tracking a monthly revenue target reads the
running total to answer "are we on pace?" — a question a simple daily
breakdown cannot answer at a glance.

*Screenshot: `07_running_revenue.png`*

---

### Query 8 — Window function: `LAG()` for days between orders

**Question:** how long does each returning customer take to come back?

```sql
WITH customer_orders AS (
    SELECT o.customer_id, c.customer_name, o.order_id, o.order_date,
           COUNT(*) OVER (PARTITION BY o.customer_id) AS total_orders,
           LAG(o.order_date) OVER (
               PARTITION BY o.customer_id
               ORDER BY o.order_date
           ) AS previous_order_date
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
)
SELECT customer_id, customer_name, order_id, order_date,
       previous_order_date,
       order_date - previous_order_date AS days_since_previous_order
FROM customer_orders
WHERE total_orders > 1
ORDER BY customer_id, order_date;
```

**Technique:** two window functions in one CTE. `LAG()` reaches back to the
previous row **within the same customer's partition** to fetch their last
order date, and a windowed `COUNT(*)` counts each customer's orders without
collapsing the rows, so the outer query can filter to repeat customers only.

**Reading the result:** the first order of every customer shows `NULL` for
`previous_order_date`, because there is no earlier row to look back to. This
is expected, not an error. In PostgreSQL, subtracting two `DATE` values
returns an integer number of days.

**Business interpretation:** this is the purchase-frequency metric. A
customer whose gap suddenly widens from 3 days to 10 is drifting away, and
the store can intervene before losing them. Averaging the gap per customer
gives a baseline "expected return window" for each shopper.

*Screenshot: `08_days_between_orders.png`*

---

## 6. Challenges and Resolutions

**Challenge 1 — SQL*Plus was not installed.**
The initial plan was to use Oracle. Running `sqlplus` in PowerShell returned
`'sqlplus' is not recognized as the name of a cmdlet...`. I diagnosed this
properly instead of guessing: `where.exe sqlplus` returned
"Could not find files for the given pattern(s)", and recursive searches of
`C:\app`, `C:\oracle` and `C:\Program Files\Oracle` found no `sqlplus.exe`.

**Resolution:** confirmed the executable genuinely was not on the machine
rather than merely missing from `PATH`. Since the assignment permits any
SQL DBMS, I checked what was already installed with `where.exe psql`,
`where.exe mysql` and `where.exe sqlite3`, found PostgreSQL, and adapted the
solution to it. Installing a full Oracle database would have cost hours for
no additional marks.

**Challenge 2 — misreading the psql connection prompts.**
On first launching SQL Shell (psql) I typed commands into the connection
prompts (`Server`, `Database`, `Port`, `Username`) instead of accepting the
bracketed defaults.

**Resolution:** the values in square brackets are defaults; pressing Enter
accepts each one. Only the password must be typed, and it is not echoed to
the screen. Understanding that the shell was asking connection questions —
not waiting for SQL — was the fix.

**Challenge 3 — porting Oracle syntax to PostgreSQL.**
The Oracle draft used `NUMBER`, `VARCHAR2` and `DATE '2026-09-01'` literals.

**Resolution:** translated to the PostgreSQL equivalents `INT`,
`NUMERIC(10,2)`, `VARCHAR` and standard `'2026-09-01'` date strings. The
eight analytical queries needed almost no change, which confirmed that
joins, CTEs and window functions are ANSI standard rather than
vendor-specific — a useful thing to learn in itself.

**Challenge 4 — unreadable output in the shell.**
Wide result sets were broken across lines and the pager interrupted output
part-way, making screenshots unusable.

**Resolution:** disabled the pager with `\pset pager off` so full results
print in one block and both the query and its output are captured in a
single screenshot.

---

## 7. What I Learned

- A junction table (`order_items`) with its own attribute (`quantity`) is the
  correct way to model many-to-many relationships; storing revenue directly
  would have duplicated derivable data.
- `LEFT JOIN` is not a weaker `INNER JOIN` — the `NULL` rows it preserves are
  often the commercially interesting ones.
- CTEs matter most when an intermediate result is needed more than once, as
  in Query 4 where the totals feed both the output and the average.
- Window functions occupy the space that `GROUP BY` cannot reach: they
  compute across a set of rows while still returning each individual row.
- `PARTITION BY` is what makes a window function answer per-customer rather
  than whole-table questions.

---

## 8. References

- PostgreSQL 17 Documentation — Window Functions:
  https://www.postgresql.org/docs/current/tutorial-window.html
- PostgreSQL 17 Documentation — WITH Queries (CTEs):
  https://www.postgresql.org/docs/current/queries-with.html

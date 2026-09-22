-- ============================================================
-- Assignment 1 - Sunrise Supermarket Sales Analysis
-- Student ID: 25401
-- DBMS: PostgreSQL
-- ============================================================

-- ------------------------------------------------------------
-- SECTION 1: SCHEMA
-- ------------------------------------------------------------
DROP TABLE IF EXISTS order_items, orders, products, customers;

CREATE TABLE customers (
    customer_id   INT PRIMARY KEY,
    customer_name VARCHAR(100),
    email         VARCHAR(100),
    city          VARCHAR(50)
);

CREATE TABLE products (
    product_id   INT PRIMARY KEY,
    product_name VARCHAR(100),
    category     VARCHAR(50),
    price        NUMERIC(10,2)
);

CREATE TABLE orders (
    order_id    INT PRIMARY KEY,
    customer_id INT REFERENCES customers(customer_id),
    order_date  DATE
);

CREATE TABLE order_items (
    order_item_id INT PRIMARY KEY,
    order_id      INT REFERENCES orders(order_id),
    product_id    INT REFERENCES products(product_id),
    quantity      INT
);

-- ------------------------------------------------------------
-- SECTION 2: SAMPLE DATA
-- Customer 5 (Patrick Habimana) intentionally has no orders,
-- so the LEFT JOIN in Query 3 demonstrates unmatched rows.
-- ------------------------------------------------------------
INSERT INTO customers VALUES
(1,'Jean Claude','jean@example.com','Kigali'),
(2,'Alice Mukamana','alice@example.com','Huye'),
(3,'Eric Niyonzima','eric@example.com','Musanze'),
(4,'Diane Uwase','diane@example.com','Rubavu'),
(5,'Patrick Habimana','patrick@example.com','Kigali');

INSERT INTO products VALUES
(1,'Milk 1L','Beverages',1200),
(2,'Orange Juice','Beverages',2500),
(3,'Mineral Water','Beverages',800),
(4,'Rice 5kg','Groceries',7500),
(5,'Sugar 2kg','Groceries',3000),
(6,'Cooking Oil 2L','Groceries',6500),
(7,'Laundry Soap','Household',1800),
(8,'Toothpaste','Personal Care',2200);

INSERT INTO orders VALUES
(1,1,'2026-09-01'),(2,2,'2026-09-02'),(3,3,'2026-09-03'),
(4,1,'2026-09-05'),(5,4,'2026-09-06'),(6,2,'2026-09-08'),
(7,3,'2026-09-09'),(8,1,'2026-09-11'),(9,4,'2026-09-12'),
(10,2,'2026-09-14'),(11,3,'2026-09-15'),(12,1,'2026-09-17'),
(13,4,'2026-09-18'),(14,2,'2026-09-19'),(15,3,'2026-09-20');

INSERT INTO order_items VALUES
(1,1,1,2),(2,1,4,1),(3,2,2,2),(4,2,5,1),(5,3,3,5),(6,3,7,2),
(7,4,6,2),(8,4,8,2),(9,5,4,2),(10,5,5,2),(11,6,1,3),(12,6,6,1),
(13,7,2,2),(14,7,7,3),(15,8,4,1),(16,8,6,2),(17,9,3,4),(18,9,8,1),
(19,10,5,3),(20,10,7,2),(21,11,4,2),(22,11,2,1),(23,12,6,3),(24,12,1,2),
(25,13,8,2),(26,13,5,3),(27,14,4,1),(28,14,6,1),(29,15,2,3),(30,15,7,2);

-- Verification: expect 5, 8, 15, 30
SELECT COUNT(*) AS customers_count   FROM customers;
SELECT COUNT(*) AS products_count    FROM products;
SELECT COUNT(*) AS orders_count      FROM orders;
SELECT COUNT(*) AS order_items_count FROM order_items;

-- ------------------------------------------------------------
-- QUERY 1 - INNER JOIN: every order with its customer
-- ------------------------------------------------------------
SELECT o.order_id, c.customer_name, c.city, o.order_date
FROM orders o
INNER JOIN customers c ON o.customer_id = c.customer_id
ORDER BY o.order_date;

-- ------------------------------------------------------------
-- QUERY 2 - INNER JOIN: order lines with product detail
-- ------------------------------------------------------------
SELECT oi.order_item_id, oi.order_id, p.product_name,
       p.category, p.price, oi.quantity
FROM order_items oi
INNER JOIN products p ON oi.product_id = p.product_id
ORDER BY oi.order_id, oi.order_item_id;

-- ------------------------------------------------------------
-- QUERY 3 - LEFT JOIN: all customers, including non-buyers
-- Patrick Habimana returns NULL order columns.
-- ------------------------------------------------------------
SELECT c.customer_id, c.customer_name, c.city, o.order_id, o.order_date
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
ORDER BY c.customer_id, o.order_date;

-- ------------------------------------------------------------
-- QUERY 4 - CTE: customers spending above the average
-- ------------------------------------------------------------
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

-- ------------------------------------------------------------
-- QUERY 5 - WINDOW FUNCTION: RANK customers by total spend
-- ------------------------------------------------------------
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

-- ------------------------------------------------------------
-- QUERY 6 - WINDOW FUNCTION: ROW_NUMBER per customer
-- ------------------------------------------------------------
SELECT o.customer_id, c.customer_name, o.order_id, o.order_date,
       ROW_NUMBER() OVER (
           PARTITION BY o.customer_id
           ORDER BY o.order_date
       ) AS order_number
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
ORDER BY o.customer_id, o.order_date;

-- ------------------------------------------------------------
-- QUERY 7 - WINDOW FUNCTION: running total of revenue
-- ------------------------------------------------------------
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

-- ------------------------------------------------------------
-- QUERY 8 - WINDOW FUNCTION: LAG, days between orders
-- Only customers with more than one order are returned.
-- ------------------------------------------------------------
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

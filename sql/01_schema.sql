-- NOTE:
-- Workflow used in this project:
-- 1. Raw dataset imported into staging_ecommerce
-- 2. Data cleaned and inserted into normalized tables below
-- 3. Analysis performed on structured relational model

PRAGMA foreign_keys = ON;

DROP TABLE IF EXISTS returns;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS customers;

-- =========================
-- CUSTOMERS TABLE
-- =========================
CREATE TABLE customers (
    customer_id TEXT PRIMARY KEY,
    customer_age INTEGER,
    customer_gender TEXT
);

-- =========================
-- PRODUCTS TABLE
-- =========================
CREATE TABLE products (
    product_id TEXT PRIMARY KEY,
    category TEXT NOT NULL,
    price REAL NOT NULL,
    discount REAL NOT NULL CHECK (discount >= 0 AND discount <= 1)
);

-- =========================
-- ORDERS TABLE (FACT TABLE)
-- =========================
CREATE TABLE orders (
    order_id TEXT PRIMARY KEY,
    customer_id TEXT NOT NULL,
    product_id TEXT NOT NULL,
    order_date DATE NOT NULL,
    delivered_date DATE,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    payment_method TEXT,
    region TEXT,
    total_amount REAL NOT NULL,
    shipping_cost REAL,
    profit_margin REAL,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- =========================
-- RETURNS TABLE
-- =========================
CREATE TABLE returns (
    return_id INTEGER PRIMARY KEY AUTOINCREMENT,
    order_id TEXT NOT NULL UNIQUE,
    request_date DATE,
    return_reason TEXT,
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
);

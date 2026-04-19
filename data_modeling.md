### This section documents the transformation of raw e-commerce data into a structured relational model used for analysis.

## 1. Raw Data Staging

The original dataset was imported as a single denormalized table (staging_ecommerce) containing all transactional, customer, product, and return information.

Why staging?
Preserve raw data integrity
Enable controlled transformations
Avoid modifying source data

## 2. Data Normalization 

The dataset was decomposed into multiple relational tables to eliminate redundancy and improve query performance.

Tables Created:
customers → customer-level attributes
products → product and category information
orders → transactional data
returns → return-related records
Why this structure?
Reduces duplication (no repeated customer/product data)
Improves scalability
Enables cleaner joins and analysis
Follows relational database design principles

## 3. Entity Relationship Design (ERD)

The database was structured using a star-like relational model centered around the orders table.

Relationships:
orders.customer_id → customers.customer_id
orders.product_id → products.product_id
returns.order_id → orders.order_id

## 4. Why These Relationships Matter

This structure allows:

Accurate calculation of revenue and return loss
Linking returns back to original transactions
Aggregation at customer, product, and category levels
Flexible filtering across dimensions

## 5. What This Enables

By restructuring the data, the model supports:

Multi-level analysis (customer, product, category)
Detection of high-risk entities
Efficient computation of KPIs (revenue, return rate, loss)
Scalable analytical queries

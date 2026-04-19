# Entity Relationship Diagram (ERD)

![ERD](./ERD.png)

## Overview
This Entity Relationship Diagram (ERD) represents the relational data model used for the **E-commerce Revenue Leakage Analysis** project.

The schema is designed based on the raw Kaggle e-commerce dataset to support accurate calculation of revenue loss, return rates, category performance, and high-risk product identification.

## Data Model Structure
The model consists of four main tables:

- **customers** — Customer demographic information
- **products** — Product master data including category and pricing
- **orders** — Core transaction records (one product per order)
- **returns** — Return transactions linked to orders

The schema is centered around the **orders** table, which connects customers, products, and returns.

## Key Relationships
- One **customer** can place many **orders** (1:N)
- One **product** can appear in many **orders** (1:N)
- One **order** can have at most one **return** (1:0..1)
- Returns are linked directly to orders for accurate revenue leakage tracking

**Note:** The dataset structure indicates each order contains a single product (no separate order_items table was needed).

## Design Rationale
- **Simplicity & Fidelity**: The model closely mirrors the actual structure of the provided dataset.
- **Analytical Efficiency**: Enables straightforward SQL joins for calculating:
  - Total revenue and net revenue
  - Return loss by product, category, and customer
  - Return rates (by revenue and by order count)
  - High-risk products and categories (Electronics & Fashion)
- **Performance**: Direct foreign key relationships support efficient aggregations and window functions used in the analysis.

## Tools Used to Generate ERD
- **dbdiagram.io** — For designing and visualizing the ERD

## Analytical Impact
This data model directly enabled key findings in the project, including:
- Identification that Electronics drives the highest absolute return loss
- Discovery that Fashion has the highest return rate
- Pareto analysis showing that a small number of products account for a large portion of losses
- High-risk product flagging (100% return rate)

The clean relational structure made complex revenue leakage calculations efficient and reproducible.

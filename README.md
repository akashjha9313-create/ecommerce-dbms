# E-Commerce Order, Inventory & Transaction Management System

A normalized (3NF) relational database and RESTful backend API built with **MySQL** and **Node.js (Express)** to manage multi-vendor e-commerce operations, automated inventory tracking, atomic checkout transactions, and order cancellation workflows.

---

## 1. Tech Stack & Architecture
* **Database:** MySQL 8+ (InnoDB Engine for ACID compliance & Foreign Key constraints)
* **Backend:** Node.js, Express.js, `mysql2/promise` (Connection Pooling)
* **API Testing:** Thunder Client / Postman

---

## 2. Entity-Relationship (ER) Architecture

```text
+---------------+       1:N       +---------------+       N:1       +---------------+
|    Sellers    |---------------->|   Products    |<----------------|  Categories   |
+---------------+                 +---------------+                 +---------------+
                                     |         |
                                 1:N |         | 1:N
                                     v         v
+---------------+       1:N       +---------------+                 +---------------+
|     Users     |---------------->|     Cart      |                 |  Order_Items  |
+---------------+                 +---------------+                 +---------------+
        |                                                                   ^
        | 1:N                                                               | 1:N
        v                                                                   |
+---------------+       1:1       +---------------+                         |
|    Orders     |---------------->|   Payments    |-------------------------+
+---------------+                 +---------------+
/Users/akashkumar/Documents/ecommerce-dbms/.gitignore
cat << 'EOF' > README.md
# E-Commerce Order, Inventory & Transaction Management System

A normalized (3NF) relational database and RESTful backend API built with **MySQL** and **Node.js (Express)** to manage multi-vendor e-commerce operations, automated inventory tracking, atomic checkout transactions, and order cancellation workflows.

## 1. Tech Stack & Architecture
* **Database:** MySQL 8+ (InnoDB Engine for ACID compliance & Foreign Key constraints)
* **Backend:** Node.js, Express.js, `mysql2/promise` (Connection Pooling)
* **API Testing:** Thunder Client / Postman

## 2. Database Schema & Normalization (3NF)
The database (`ecommerce_db`) consists of **8 normalized tables**:

| Table Name | Primary Key | Foreign Keys | Purpose & Constraints |
| :--- | :--- | :--- | :--- |
| **`Users`** | `user_id` | — | Stores customer profile (`UNIQUE` email) |
| **`Sellers`** | `seller_id` | — | Stores vendor/store details (`UNIQUE` GST number) |
| **`Categories`** | `category_id` | — | Product classification lookup table |
| **`Products`** | `product_id` | `seller_id`, `category_id` | Catalog items (`CHECK price > 0`, `stock_qty >= 0`) |
| **`Cart`** | `cart_id` | `user_id`, `product_id` | Active shopping cart (`UNIQUE(user_id, product_id)`) |
| **`Orders`** | `order_id` | `user_id` | Order header (`ENUM` status, discount & total amount) |
| **`Order_Items`** | `order_item_id` | `order_id`, `product_id` | Resolves M:N relationship between Orders and Products |
| **`Payments`** | `payment_id` | `order_id` (`UNIQUE`) | 1:1 payment ledger (`UNIQUE` transaction reference) |

## 3. Advanced DBMS Features Implemented
* **Triggers:**
  1. `trg_deduct_stock_after_order` (`AFTER INSERT ON Order_Items`) — Auto-decrements product stock on order placement.
  2. `trg_restore_stock_on_cancel` (`AFTER UPDATE ON Orders`) — Restores stock & marks payment as `'Refunded'` on cancellation.
* **Stored Procedures & ACID Transactions:**
  1. `sp_checkout_cart(user_id, discount, payment_method, txn_ref)` — Atomic checkout with stock validation, temporary table staging, and rollback handler.
  2. `sp_seller_sales_report()` — Aggregates total orders, units sold, and net revenue per seller.

## 4. Setup & Run
1. `mysql -u root -p < schema.sql`
2. Configure `.env` (`DB_HOST`, `DB_USER`, `DB_PASSWORD`, `DB_NAME=ecommerce_db`, `PORT=5001`)
3. `npm install && node server.js`

## 5. REST API Endpoints
* `GET /api/products` — Fetch all products with category & seller names (`INNER JOIN`)
* `POST /api/cart` — Add/increment item in customer cart (`ON DUPLICATE KEY UPDATE`)
* `POST /api/checkout` — Convert cart into confirmed order & payment (`sp_checkout_cart`)
* `PUT /api/orders/:id/cancel` — Cancel order & restore stock (`AFTER UPDATE` Trigger)
* `GET /api/reports/sellers` — Seller-wise revenue analytics (`sp_seller_sales_report`)

require('dotenv').config();
const express = require('express');
const mysql = require('mysql2/promise');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

// MySQL Connection Pool
const pool = mysql.createPool({
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    waitForConnections: true,
    connectionLimit: 10
});

// 1. Get all products with category & seller info (JOIN query)
app.get('/api/products', async (req, res) => {
    try {
        const [rows] = await pool.query(`
            SELECT p.product_id, p.product_name, p.price, p.stock_qty, 
                   c.category_name, s.store_name 
            FROM Products p
            JOIN Categories c ON p.category_id = c.category_id
            JOIN Sellers s ON p.seller_id = s.seller_id
        `);
        res.json(rows);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// 2. Add item to user's cart
app.post('/api/cart', async (req, res) => {
    const { user_id, product_id, quantity } = req.body;
    try {
        await pool.query(
            `INSERT INTO Cart (user_id, product_id, quantity) 
             VALUES (?, ?, ?) 
             ON DUPLICATE KEY UPDATE quantity = quantity + VALUES(quantity)`,
            [user_id, product_id, quantity]
        );
        res.json({ message: 'Item added to cart successfully!' });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// 3. Checkout Cart (Calls Stored Procedure with ACID Transaction + Trigger)
app.post('/api/checkout', async (req, res) => {
    const { user_id, discount, payment_method, txn_ref } = req.body;
    try {
        await pool.query('CALL sp_checkout_cart(?, ?, ?, ?)', [
            user_id,
            discount || 0,
            payment_method,
            txn_ref
        ]);
        res.json({ message: 'Order placed, payment recorded & stock deducted automatically!' });
    } catch (err) {
        res.status(400).json({ error: err.message });
    }
});

// 4. Cancel Order (Fires Restore Stock & Refund Trigger)
app.put('/api/orders/:id/cancel', async (req, res) => {
    try {
        const [result] = await pool.query(
            "UPDATE Orders SET order_status = 'Cancelled' WHERE order_id = ?",
            [req.params.id]
        );
        if (result.affectedRows === 0) return res.status(404).json({ error: 'Order not found' });
        res.json({ message: 'Order cancelled, stock restored & payment refunded!' });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// 5. Seller Sales Report (Calls Reporting Stored Procedure)
app.get('/api/reports/sellers', async (req, res) => {
    try {
        const [rows] = await pool.query('CALL sp_seller_sales_report()');
        res.json(rows[0]);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.listen(process.env.PORT, () => {
    console.log(`Server running on http://localhost:${process.env.PORT}`);
});
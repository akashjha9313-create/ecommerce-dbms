-- ==========================================
-- STEP 1: CREATE DATABASE
-- ==========================================
DROP DATABASE IF EXISTS ecommerce_db;
CREATE DATABASE ecommerce_db;
USE ecommerce_db;

-- ==========================================
-- STEP 2: CREATE TABLES (3NF NORMALIZED)
-- ==========================================

CREATE TABLE Users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(15) NOT NULL,
    address TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE Sellers (
    seller_id INT AUTO_INCREMENT PRIMARY KEY,
    store_name VARCHAR(100) NOT NULL,
    gst_number VARCHAR(20) UNIQUE NOT NULL,
    contact_email VARCHAR(100) NOT NULL
);

CREATE TABLE Categories (
    category_id INT AUTO_INCREMENT PRIMARY KEY,
    category_name VARCHAR(50) UNIQUE NOT NULL,
    description VARCHAR(255)
);

CREATE TABLE Products (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    seller_id INT NOT NULL,
    category_id INT NOT NULL,
    product_name VARCHAR(150) NOT NULL,
    price DECIMAL(10, 2) NOT NULL CHECK (price > 0),
    stock_qty INT NOT NULL CHECK (stock_qty >= 0),
    FOREIGN KEY (seller_id) REFERENCES Sellers(seller_id) ON DELETE CASCADE,
    FOREIGN KEY (category_id) REFERENCES Categories(category_id) ON DELETE RESTRICT
);

CREATE TABLE Cart (
    cart_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    UNIQUE(user_id, product_id),
    FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES Products(product_id) ON DELETE CASCADE
);

CREATE TABLE Orders (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    discount_amount DECIMAL(10, 2) DEFAULT 0.00 CHECK (discount_amount >= 0),
    total_amount DECIMAL(10, 2) NOT NULL CHECK (total_amount >= 0),
    order_status ENUM('Pending', 'Confirmed', 'Shipped', 'Delivered', 'Cancelled') DEFAULT 'Confirmed',
    FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE RESTRICT
);

CREATE TABLE Order_Items (
    order_item_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(10, 2) NOT NULL CHECK (unit_price > 0),
    FOREIGN KEY (order_id) REFERENCES Orders(order_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES Products(product_id) ON DELETE RESTRICT
);

CREATE TABLE Payments (
    payment_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT UNIQUE NOT NULL,
    payment_method ENUM('UPI', 'Credit Card', 'Debit Card', 'NetBanking', 'COD') NOT NULL,
    payment_status ENUM('Pending', 'Completed', 'Failed', 'Refunded') DEFAULT 'Completed',
    transaction_ref VARCHAR(50) UNIQUE NOT NULL,
    paid_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (order_id) REFERENCES Orders(order_id) ON DELETE CASCADE
);

-- ==========================================
-- STEP 3: INSERT REALISTIC SAMPLE DATA
-- ==========================================

INSERT INTO Users (full_name, email, phone, address) VALUES
('Aarav Sharma', 'aarav@example.com', '9876543210', 'Sector 62, Noida, UP'),
('Priya Verma', 'priya@example.com', '9876543211', 'Saket, New Delhi'),
('Rohan Mehta', 'rohan@example.com', '9876543212', 'Sohna Road, Gurugram'),
('Ananya Singh', 'ananya@example.com', '9876543213', 'Indirapuram, Ghaziabad');

INSERT INTO Sellers (store_name, gst_number, contact_email) VALUES
('TechZone India', '07AABCT1234A1Z5', 'support@techzone.in'),
('UrbanStyle Fashion', '09AABCU5678B1Z2', 'sales@urbanstyle.in'),
('HomeEssentials Hub', '06AABCH9012C1Z8', 'care@homehub.in');

INSERT INTO Categories (category_name, description) VALUES
('Electronics', 'Smartphones, laptops, and accessories'),
('Apparel', 'Men and women clothing'),
('Home & Kitchen', 'Appliances and daily utilities');

INSERT INTO Products (seller_id, category_id, product_name, price, stock_qty) VALUES
(1, 1, 'Wireless Gaming Mouse', 1499.00, 25),
(1, 1, 'Mechanical RGB Keyboard', 3499.00, 15),
(1, 1, 'USB-C Fast Charger 65W', 1299.00, 4),
(2, 2, 'Cotton Oversized Hoodie', 1199.00, 30),
(3, 3, 'Electric Kettle 1.5L', 899.00, 12);

INSERT INTO Cart (user_id, product_id, quantity) VALUES
(1, 1, 2),
(1, 3, 1),
(2, 4, 2);

-- ==========================================
-- STEP 4: TRIGGERS & STORED PROCEDURES
-- ==========================================

DELIMITER //
CREATE TRIGGER trg_deduct_stock_after_order
AFTER INSERT ON Order_Items
FOR EACH ROW
BEGIN
    UPDATE Products
    SET stock_qty = stock_qty - NEW.quantity
    WHERE product_id = NEW.product_id;
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER trg_restore_stock_on_cancel
AFTER UPDATE ON Orders
FOR EACH ROW
BEGIN
    IF OLD.order_status <> 'Cancelled' AND NEW.order_status = 'Cancelled' THEN
        UPDATE Products p
        JOIN Order_Items oi ON p.product_id = oi.product_id
        SET p.stock_qty = p.stock_qty + oi.quantity
        WHERE oi.order_id = NEW.order_id;

        UPDATE Payments
        SET payment_status = 'Refunded'
        WHERE order_id = NEW.order_id AND payment_status = 'Completed';
    END IF;
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_checkout_cart(
    IN p_user_id INT,
    IN p_discount DECIMAL(10,2),
    IN p_payment_method VARCHAR(20),
    IN p_txn_ref VARCHAR(50)
)
BEGIN
    DECLARE v_subtotal DECIMAL(10,2) DEFAULT 0;
    DECLARE v_final_total DECIMAL(10,2) DEFAULT 0;
    DECLARE v_new_order_id INT;
    DECLARE v_insufficient_stock INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Transaction Failed! Order Rolled Back.';
    END;

    START TRANSACTION;

    SELECT COUNT(*) INTO v_insufficient_stock
    FROM Cart c
    JOIN Products p ON c.product_id = p.product_id
    WHERE c.user_id = p_user_id AND c.quantity > p.stock_qty;

    IF v_insufficient_stock > 0 THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient Stock for one or more items!';
    END IF;

    SELECT SUM(c.quantity * p.price) INTO v_subtotal
    FROM Cart c
    JOIN Products p ON c.product_id = p.product_id
    WHERE c.user_id = p_user_id;

    IF v_subtotal IS NULL OR v_subtotal = 0 THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cart is empty!';
    END IF;

    SET v_final_total = GREATEST(v_subtotal - p_discount, 0);

    INSERT INTO Orders (user_id, discount_amount, total_amount, order_status)
    VALUES (p_user_id, p_discount, v_final_total, 'Confirmed');
    SET v_new_order_id = LAST_INSERT_ID();

    INSERT INTO Order_Items (order_id, product_id, quantity, unit_price)
    SELECT v_new_order_id, c.product_id, c.quantity, p.price
    FROM Cart c
    JOIN Products p ON c.product_id = p.product_id
    WHERE c.user_id = p_user_id;

    INSERT INTO Payments (order_id, payment_method, payment_status, transaction_ref)
    VALUES (v_new_order_id, p_payment_method, 'Completed', p_txn_ref);

    DELETE FROM Cart WHERE user_id = p_user_id;

    COMMIT;
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_seller_sales_report()
BEGIN
    SELECT 
        s.seller_id,
        s.store_name,
        COUNT(DISTINCT oi.order_id) AS total_orders,
        COALESCE(SUM(oi.quantity), 0) AS units_sold,
        COALESCE(SUM(oi.quantity * oi.unit_price), 0.00) AS total_revenue
    FROM Sellers s
    LEFT JOIN Products p ON s.seller_id = p.seller_id
    LEFT JOIN Order_Items oi ON p.product_id = oi.product_id
    LEFT JOIN Orders o ON oi.order_id = o.order_id AND o.order_status <>
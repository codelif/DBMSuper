DROP DATABASE IF EXISTS dbms;

CREATE DATABASE dbms;

USE dbms;


CREATE TABLE IF NOT EXISTS Customers (
  username       VARCHAR(64)  NOT NULL,
  password_hash  VARCHAR(255) NOT NULL,
  full_name      VARCHAR(255) NOT NULL,
  email          VARCHAR(255) NOT NULL,
  phone          VARCHAR(32),
  address        TEXT,
  created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (username),
  UNIQUE KEY uq_customers_email (email)
);

CREATE TABLE IF NOT EXISTS Sellers (
  username       VARCHAR(64)  NOT NULL,
  password_hash  VARCHAR(255) NOT NULL,
  display_name   VARCHAR(255) NOT NULL,
  email          VARCHAR(255) NOT NULL,
  phone          VARCHAR(32),
  address        TEXT,
  created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (username),
  UNIQUE KEY uq_sellers_email (email)
);

CREATE TABLE IF NOT EXISTS Products (
  product_id       INT UNSIGNED NOT NULL AUTO_INCREMENT,
  seller_username  VARCHAR(64)  NOT NULL,
  name             VARCHAR(255) NOT NULL,
  rating           TINYINT,
  price            INT UNSIGNED NOT NULL,
  quantity         INT UNSIGNED NOT NULL,
  description      TEXT,
  created_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (product_id),

  FOREIGN KEY (seller_username)
    REFERENCES Sellers(username)
    ON DELETE CASCADE,

  CHECK (price >= 0),
  CHECK (quantity >= 0),
  CHECK (rating IS NULL OR rating BETWEEN 1 AND 5),

  UNIQUE KEY uq_products_seller_name (seller_username, name)
);

CREATE TABLE IF NOT EXISTS Reviews (
  product_id         INT UNSIGNED NOT NULL,
  customer_username  VARCHAR(64)  NOT NULL,
  rating             TINYINT      NOT NULL,
  review             TEXT,
  created_at         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (product_id, customer_username),

  FOREIGN KEY (product_id)
    REFERENCES Products(product_id)
    ON DELETE CASCADE,

  FOREIGN KEY (customer_username)
    REFERENCES Customers(username)
    ON DELETE CASCADE,

  CHECK (rating BETWEEN 1 AND 5)
);

CREATE TABLE IF NOT EXISTS CartItems (
  product_id         INT UNSIGNED NOT NULL,
  customer_username  VARCHAR(64)  NOT NULL,
  quantity           INT UNSIGNED NOT NULL,

  PRIMARY KEY (product_id, customer_username),

  FOREIGN KEY (product_id)
    REFERENCES Products(product_id)
    ON DELETE CASCADE,

  FOREIGN KEY (customer_username)
    REFERENCES Customers(username)
    ON DELETE CASCADE,

  CHECK (quantity >= 0)
);

CREATE TABLE IF NOT EXISTS Orders (
  product_id         INT UNSIGNED NOT NULL,
  customer_username  VARCHAR(64)  NOT NULL,
  quantity           INT UNSIGNED NOT NULL,
  created_at         DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (product_id, customer_username, created_at),

  FOREIGN KEY (product_id)
    REFERENCES Products(product_id)
    ON DELETE RESTRICT,

  FOREIGN KEY (customer_username)
    REFERENCES Customers(username)
    ON DELETE RESTRICT,

  CHECK (quantity >= 0)
);

-- =========================
-- Customers
-- =========================
INSERT INTO Customers (username, password_hash, full_name, email, phone, address) VALUES
  ('alice', 'hash_a1', 'Alice Johnson', 'alice@example.com', '123-456-7890', '123 Maple St'),
  ('bob',   'hash_b1', 'Bob Martinez',  'bob@example.com',   '555-111-2222', '44 Oak Lane'),
  ('carol', 'hash_c1', 'Carol Smith',   'carol@example.com', '555-222-3333', '78 Hill Rd'),
  ('dave',  'hash_d1', 'Dave Lee',      'dave@example.com',  '555-333-4444', '90 River Dr'),
  ('erin',  'hash_e1', 'Erin Brown',    'erin@example.com',  '555-444-5555', '11 Pine Ave'),
  ('frank', 'hash_f1', 'Frank Green',   'frank@example.com', '555-555-6666', '22 Cedar St'),
  ('grace', 'hash_g1', 'Grace Kim',     'grace@example.com', '555-666-7777', '33 Birch Rd'),
  ('heidi', 'hash_h1', 'Heidi Clark',   'heidi@example.com', '555-777-8888', '44 Walnut St'),
  ('ivan',  'hash_i1', 'Ivan Petrov',   'ivan@example.com',  '555-888-9999', '55 Elm St'),
  ('judy',  'hash_j1', 'Judy Lopez',    'judy@example.com',  '555-999-0000', '66 Spruce Ln');

-- =========================
-- Sellers
-- =========================
INSERT INTO Sellers (username, password_hash, display_name, email, phone, address) VALUES
  ('shopmax',   'hash_s1', 'ShopMax',   'shopmax@example.com',   '800-555-0001', '12 Commerce Ave'),
  ('techhub',   'hash_s2', 'TechHub',   'techhub@example.com',   '800-555-0002', '90 Silicon Blvd'),
  ('fashionco', 'hash_s3', 'FashionCo', 'fashion@example.com',   NULL,           '7 Trendy St'),
  ('booknest',  'hash_s4', 'BookNest',  'booknest@example.com',  '800-555-0004', '5 Library Way'),
  ('homelife',  'hash_s5', 'HomeLife',  'homelife@example.com',  '800-555-0005', '8 Comfort Cir');

-- =========================
-- Products (AUTO_INCREMENT product_id will be 1..15)
-- =========================
INSERT INTO Products (seller_username, name, rating, price, quantity, description) VALUES
  ('shopmax',   'Wireless Mouse',      5, 1999, 1000, 'Ergonomic wireless mouse'),
  ('shopmax',   'Laptop Bag',          4, 2999,  800, 'Waterproof laptop bag'),
  ('techhub',   'Mechanical Keyboard', 5, 8999,  600, 'RGB mechanical keyboard'),
  ('techhub',   'USB-C Cable',         4,  999, 1500, '1m braided USB-C cable'),
  ('fashionco', 'Denim Jacket',        5, 4999,  400, 'Classic blue denim jacket'),
  ('fashionco', 'Sneakers',            4, 5999,  700, 'Comfortable white sneakers'),
  ('booknest',  'Sci-Fi Novel',        5, 1499,  500, 'Bestselling science fiction novel'),
  ('booknest',  'Cookbook',            4, 1999,  500, 'Everyday recipes cookbook'),
  ('homelife',  'Ceramic Mug',         4,  799, 1200, 'Dishwasher-safe ceramic mug'),
  ('homelife',  'Desk Lamp',           5, 2599,  300, 'LED desk lamp with dimmer'),
  ('techhub',   'Gaming Headset',      4, 6999,  450, 'Surround sound gaming headset'),
  ('shopmax',   'External SSD',        5,12999,  350, '1TB USB-C external SSD'),
  ('homelife',  'Office Chair',        4,15999,  200, 'Ergonomic office chair'),
  ('fashionco', 'Leather Belt',        5, 2499,  300, 'Genuine leather belt'),
  ('booknest',  'Notebook Pack',       4,  999, 1000, 'Pack of 3 ruled notebooks');

-- product_id mapping after this:
--  1 Wireless Mouse
--  2 Laptop Bag
--  3 Mechanical Keyboard
--  4 USB-C Cable
--  5 Denim Jacket
--  6 Sneakers
--  7 Sci-Fi Novel
--  8 Cookbook
--  9 Ceramic Mug
-- 10 Desk Lamp
-- 11 Gaming Headset
-- 12 External SSD
-- 13 Office Chair
-- 14 Leather Belt
-- 15 Notebook Pack

-- =========================
-- Reviews
-- (checks rating 1–5 and PK (product_id, customer_username))
-- =========================
INSERT INTO Reviews (product_id, customer_username, rating, review) VALUES
  (1,  'alice', 5, 'Very comfortable and responsive mouse.'),
  (1,  'bob',   4, 'Good mouse, a bit small for my hand.'),
  (2,  'carol', 4, 'Sturdy bag with lots of pockets.'),
  (3,  'dave',  5, 'Best keyboard I have ever used.'),
  (3,  'erin',  5, 'Great feel and RGB lighting.'),
  (4,  'frank', 4, 'Cable works well, feels durable.'),
  (5,  'grace', 5, 'Jacket fits perfectly and looks great.'),
  (6,  'heidi', 4, 'Comfortable shoes for daily wear.'),
  (7,  'ivan',  5, 'Could not put this book down.'),
  (8,  'judy',  4, 'Nice recipes, easy to follow.'),
  (9,  'alice', 4, 'Mug looks nice and feels solid.'),
  (10, 'bob',   5, 'Lamp is bright with useful dimmer.'),
  (11, 'carol', 4, 'Good sound quality for gaming.'),
  (12, 'dave',  5, 'Fast and compact SSD.'),
  (13, 'erin',  4, 'Comfortable chair for long workdays.'),
  (14, 'frank', 5, 'High-quality leather and buckle.'),
  (15, 'grace', 4, 'Handy notebooks for school.'),
  (2,  'heidi', 3, 'Decent bag, but strap could be softer.'),
  (5,  'ivan',  5, 'Great style and material.'),
  (11, 'judy',  4, 'Mic is clear and comfortable to wear.');

-- =========================
-- CartItems
-- (quantity > 0 and PK (product_id, customer_username))
-- =========================
INSERT INTO CartItems (product_id, customer_username, quantity) VALUES
  (1,  'carol', 1),
  (2,  'alice', 2),
  (3,  'bob',   1),
  (4,  'erin',  3),
  (5,  'frank', 1),
  (6,  'grace', 2),
  (7,  'heidi', 1),
  (8,  'ivan',  4),
  (9,  'judy',  2),
  (10, 'alice', 1),
  (11, 'dave',  1),
  (12, 'carol', 1),
  (13, 'bob',   1),
  (14, 'erin',  2),
  (15, 'frank', 3);

-- =========================
-- Orders
-- (trigger checks stock; AFTER INSERT decrements Products.quantity)
-- PK (product_id, customer_username, created_at)
-- =========================
INSERT INTO Orders (product_id, customer_username, quantity) VALUES
  (1,  'alice', 1),
  (2,  'bob',   1),
  (3,  'carol', 2),
  (4,  'dave',  3),
  (5,  'erin',  1),
  (6,  'frank', 2),
  (7,  'grace', 1),
  (8,  'heidi', 1),
  (9,  'ivan',  4),
  (10, 'judy',  1),
  (11, 'alice', 1),
  (12, 'bob',   1),
  (13, 'carol', 1),
  (14, 'dave',  1),
  (15, 'erin',  5),
  (3,  'frank', 1),
  (5,  'grace', 2),
  (7,  'heidi', 1),
  (9,  'judy',  2),
  (12, 'ivan',  1);


-- =========================================================
-- STORED PROCEDURES (5)
-- =========================================================
DELIMITER //

CREATE PROCEDURE sp_create_customer(
    IN p_username      VARCHAR(64),
    IN p_password_hash VARCHAR(255),
    IN p_full_name     VARCHAR(255),
    IN p_email         VARCHAR(255),
    IN p_phone         VARCHAR(32),
    IN p_address       TEXT
)
BEGIN
    INSERT INTO Customers (username, password_hash, full_name, email, phone, address)
    VALUES (p_username, p_password_hash, p_full_name, p_email, p_phone, p_address);
END//
    
CREATE PROCEDURE sp_create_seller(
    IN p_username      VARCHAR(64),
    IN p_password_hash VARCHAR(255),
    IN p_display_name  VARCHAR(255),
    IN p_email         VARCHAR(255),
    IN p_phone         VARCHAR(32),
    IN p_address       TEXT
)
BEGIN
    INSERT INTO Sellers (username, password_hash, display_name, email, phone, address)
    VALUES (p_username, p_password_hash, p_display_name, p_email, p_phone, p_address);
END//

CREATE PROCEDURE sp_add_product(
    IN p_seller_username VARCHAR(64),
    IN p_name            VARCHAR(255),
    IN p_price           INT UNSIGNED,
    IN p_quantity        INT UNSIGNED,
    IN p_description     TEXT
)
BEGIN
    INSERT INTO Products (seller_username, name, rating, price, quantity, description)
    VALUES (p_seller_username, p_name, NULL, p_price, p_quantity, p_description);
END//

CREATE PROCEDURE sp_place_order(
    IN p_customer_username VARCHAR(64),
    IN p_product_id        INT UNSIGNED,
    IN p_quantity          INT UNSIGNED
)
BEGIN
    DECLARE v_stock INT;

    SELECT quantity
      INTO v_stock
      FROM Products
     WHERE product_id = p_product_id
     FOR UPDATE;

    IF v_stock IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Product not found';
    ELSEIF v_stock < p_quantity THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Insufficient stock';
    ELSE
        INSERT INTO Orders (product_id, customer_username, quantity)
        VALUES (p_product_id, p_customer_username, p_quantity);

        UPDATE Products
           SET quantity = quantity - p_quantity
         WHERE product_id = p_product_id;
    END IF;
END//

CREATE PROCEDURE sp_clear_cart(
    IN p_customer_username VARCHAR(64)
)
BEGIN
    DELETE FROM CartItems
     WHERE customer_username = p_customer_username;
END//

-- =========================================================
-- FUNCTIONS (5)
-- =========================================================

CREATE FUNCTION fn_product_avg_rating(p_product_id INT UNSIGNED)
RETURNS DECIMAL(3,2)
READS SQL DATA
BEGIN
    DECLARE v_avg DECIMAL(3,2);
    SELECT IFNULL(AVG(rating), 0) INTO v_avg
      FROM Reviews
     WHERE product_id = p_product_id;
    RETURN v_avg;
END//

CREATE FUNCTION fn_customer_total_spent(p_customer_username VARCHAR(64))
RETURNS BIGINT UNSIGNED
READS SQL DATA
BEGIN
    -- returns total in same units as Products.price (e.g. cents)
    DECLARE v_total BIGINT UNSIGNED;
    SELECT IFNULL(SUM(o.quantity * p.price), 0) INTO v_total
      FROM Orders o
      JOIN Products p ON p.product_id = o.product_id
     WHERE o.customer_username = p_customer_username;
    RETURN v_total;
END//

CREATE FUNCTION fn_customer_order_count(p_customer_username VARCHAR(64))
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_cnt INT;
    SELECT COUNT(*) INTO v_cnt
      FROM Orders
     WHERE customer_username = p_customer_username;
    RETURN v_cnt;
END//

CREATE FUNCTION fn_product_stock(p_product_id INT UNSIGNED)
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_stock INT;
    SELECT quantity INTO v_stock
      FROM Products
     WHERE product_id = p_product_id;
    RETURN IFNULL(v_stock, 0);
END//

CREATE FUNCTION fn_seller_total_revenue(p_seller_username VARCHAR(64))
RETURNS BIGINT UNSIGNED
READS SQL DATA
BEGIN
    DECLARE v_total BIGINT UNSIGNED;
    SELECT IFNULL(SUM(o.quantity * p.price), 0) INTO v_total
      FROM Orders o
      JOIN Products p   ON p.product_id = o.product_id
      JOIN Sellers  s   ON s.username   = p.seller_username
     WHERE s.username = p_seller_username;
    RETURN v_total;
END//

-- =========================================================
-- AUXILIARY TABLE FOR PRICE HISTORY (for one of the triggers)
-- =========================================================

CREATE TABLE IF NOT EXISTS ProductPriceHistory (
    id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    product_id  INT UNSIGNED NOT NULL,
    old_price   INT UNSIGNED NOT NULL,
    new_price   INT UNSIGNED NOT NULL,
    changed_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    FOREIGN KEY (product_id) REFERENCES Products(product_id) ON DELETE CASCADE
);

-- =========================================================
-- TRIGGERS (5)
-- =========================================================

-- Enforce rating bounds (1–5) on Reviews insert
CREATE TRIGGER trg_reviews_before_insert_rating
BEFORE INSERT ON Reviews
FOR EACH ROW
BEGIN
    IF NEW.rating < 1 OR NEW.rating > 5 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Rating must be between 1 and 5';
    END IF;
END//

-- Enforce quantity > 0 on CartItems insert
CREATE TRIGGER trg_cartitems_before_insert_quantity
BEFORE INSERT ON CartItems
FOR EACH ROW
BEGIN
    IF NEW.quantity <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cart item quantity must be greater than 0';
    END IF;
END//

-- Check stock before inserting an Order
CREATE TRIGGER trg_orders_before_insert_stock
BEFORE INSERT ON Orders
FOR EACH ROW
BEGIN
    DECLARE v_stock INT;
    SELECT quantity INTO v_stock
      FROM Products
     WHERE product_id = NEW.product_id;

    IF v_stock IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Product not found for order';
    ELSEIF v_stock < NEW.quantity THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Insufficient stock for order';
    END IF;
END//

-- Decrement stock after inserting an Order
CREATE TRIGGER trg_orders_after_insert_decrement_stock
AFTER INSERT ON Orders
FOR EACH ROW
BEGIN
    UPDATE Products
       SET quantity = quantity - NEW.quantity
     WHERE product_id = NEW.product_id;
END//

-- Log price changes on Products
CREATE TRIGGER trg_products_after_update_price
AFTER UPDATE ON Products
FOR EACH ROW
BEGIN
    IF NEW.price <> OLD.price THEN
        INSERT INTO ProductPriceHistory (product_id, old_price, new_price)
        VALUES (NEW.product_id, OLD.price, NEW.price);
    END IF;
END//

DELIMITER ;

-- =========================================================
-- DOCUMENTATION TABLE FOR PROCEDURES / FUNCTIONS / TRIGGERS
-- =========================================================

CREATE TABLE IF NOT EXISTS DbArtifacts (
    name        VARCHAR(128) NOT NULL,
    type        ENUM('PROCEDURE','FUNCTION','TRIGGER') NOT NULL,
    description TEXT NOT NULL,
    PRIMARY KEY (name, type)
);

INSERT INTO DbArtifacts (name, type, description) VALUES
-- Procedures
('sp_create_customer', 'PROCEDURE', 'Creates a new customer row in the Customers table.'),
('sp_create_seller',   'PROCEDURE', 'Creates a new seller row in the Sellers table.'),
('sp_add_product',     'PROCEDURE', 'Adds a new product for a given seller.'),
('sp_place_order',     'PROCEDURE', 'Places an order and decrements product stock with validation.'),
('sp_clear_cart',      'PROCEDURE', 'Removes all cart items for a specific customer.'),

-- Functions
('fn_product_avg_rating',     'FUNCTION', 'Returns the average rating for a given product.'),
('fn_customer_total_spent',   'FUNCTION', 'Returns total amount spent by a customer across all orders.'),
('fn_customer_order_count',   'FUNCTION', 'Returns the number of orders for a customer.'),
('fn_product_stock',          'FUNCTION', 'Returns current stock quantity for a product.'),
('fn_seller_total_revenue',   'FUNCTION', 'Returns total revenue for a seller based on orders.'),

-- Triggers
('trg_reviews_before_insert_rating',          'TRIGGER', 'Validates that inserted review ratings are between 1 and 5.'),
('trg_cartitems_before_insert_quantity',      'TRIGGER', 'Ensures inserted cart items have quantity greater than 0.'),
('trg_orders_before_insert_stock',            'TRIGGER', 'Checks stock before inserting an order and rejects if insufficient.'),
('trg_orders_after_insert_decrement_stock',   'TRIGGER', 'Decrements product stock after a new order is inserted.'),
('trg_products_after_update_price',           'TRIGGER', 'Logs product price changes into ProductPriceHistory.');

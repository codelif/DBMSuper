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

INSERT INTO Customers (username, password_hash, full_name, email, phone, address)
VALUES
  ('alice',  'hash_a1', 'Alice Johnson',  'alice@example.com',  '123-456-7890', '123 Maple St'),
  ('bob',    'hash_b1', 'Bob Martinez',   'bob@example.com',    '555-111-2222', '44 Oak Lane'),
  ('carol',  'hash_c1', 'Carol Smith',    'carol@example.com',  NULL,           '78 Hill Rd');

INSERT INTO Sellers (username, password_hash, display_name, email, phone, address)
VALUES
  ('shopmax',  'hash_s1', 'ShopMax',     'shopmax@example.com',  '800-555-0001', '12 Commerce Ave'),
  ('techhub',  'hash_s2', 'TechHub',     'techhub@example.com',  '800-555-0002', '90 Silicon Blvd'),
  ('fashionco','hash_s3', 'FashionCo',   'fashion@example.com',  NULL,           '7 Trendy St');


INSERT INTO Products (seller_username, name, rating, price, quantity, description)
VALUES
  ('shopmax',  'Wireless Mouse',      5, 1999, 100, 'Ergonomic wireless mouse'),
  ('shopmax',  'Laptop Bag',          4, 2999, 50,  'Waterproof laptop bag'),
  ('techhub',  'Mechanical Keyboard', 5, 8999, 30,  'RGB mechanical keyboard'),
  ('techhub',  'USB-C Cable',         4, 999,  200, '1m braided USB-C cable'),
  ('fashionco','Denim Jacket',        5, 4999, 25,  'Classic blue denim jacket'),
  ('fashionco','Sneakers',            3, 5999, 40,  'Comfortable white sneakers');

INSERT INTO Reviews (product_id, customer_username, rating, review)
VALUES
  (1, 'alice', 5, 'Great mouse, very comfortable'),
  (1, 'bob',   4, 'Works well but a bit small'),
  (3, 'carol', 5, 'Amazing keyboard, perfect for typing'),
  (5, 'alice', 4, 'Nice jacket, fits well'),
  (6, 'bob',   3, 'Good but not very durable');

INSERT INTO CartItems (product_id, customer_username, quantity)
VALUES
  (2, 'alice', 1),
  (4, 'bob',   3),
  (6, 'carol', 1);

INSERT INTO Orders (product_id, customer_username, quantity)
VALUES
  (1, 'alice', 1),
  (3, 'bob',   1),
  (5, 'carol', 1),
  (4, 'alice', 2);

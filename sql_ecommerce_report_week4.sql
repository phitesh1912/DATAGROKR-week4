-- =====================================================================
--  04 | SQL E-COMMERCE REPORT  (SQL - Week 4)
--  35+ queries: top products, customer spend, NULL handling, JOINs,
--  DDL constraints
--  Dialect: MySQL 8.0.19+ (CHECK constraints are enforced from 8.0.16)
-- =====================================================================

DROP DATABASE IF EXISTS ecommerce_db;
CREATE DATABASE ecommerce_db;
USE ecommerce_db;

-- =====================================================================
-- PART 1: DDL WITH CONSTRAINTS
--   PRIMARY KEY, FOREIGN KEY (+ ON DELETE rules), UNIQUE, NOT NULL,
--   DEFAULT, CHECK, self-referencing FKs
-- =====================================================================

CREATE TABLE categories (
    category_id        INT AUTO_INCREMENT PRIMARY KEY,
    category_name      VARCHAR(50) NOT NULL,
    parent_category_id INT NULL,                               -- NULL = top-level category
    CONSTRAINT uq_category_name UNIQUE (category_name),
    CONSTRAINT fk_category_parent FOREIGN KEY (parent_category_id)
        REFERENCES categories(category_id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE coupons (
    coupon_code      VARCHAR(15) PRIMARY KEY,
    discount_pct     DECIMAL(5,2) NOT NULL,
    min_order_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
    valid_from       DATE NOT NULL,
    valid_to         DATE NOT NULL,
    is_active        BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT chk_coupon_pct   CHECK (discount_pct > 0 AND discount_pct <= 70),
    CONSTRAINT chk_coupon_dates CHECK (valid_to >= valid_from)
) ENGINE=InnoDB;

CREATE TABLE customers (
    customer_id  INT AUTO_INCREMENT PRIMARY KEY,
    first_name   VARCHAR(40) NOT NULL,
    last_name    VARCHAR(40) NOT NULL,
    email        VARCHAR(100) NOT NULL,
    phone        VARCHAR(15) NULL,                            -- optional
    city         VARCHAR(40) NOT NULL,
    state        VARCHAR(40) NOT NULL,
    gender       CHAR(1) NULL,                                -- optional
    signup_date  DATE NOT NULL,
    referred_by  INT NULL,                                    -- NULL = organic signup
    CONSTRAINT uq_customers_email UNIQUE (email),
    CONSTRAINT chk_customers_email CHECK (email LIKE '%_@_%.__%'),
    CONSTRAINT chk_customers_gender CHECK (gender IN ('M','F','O')),
    CONSTRAINT fk_customers_referrer FOREIGN KEY (referred_by)
        REFERENCES customers(customer_id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE products (
    product_id   INT AUTO_INCREMENT PRIMARY KEY,
    product_name VARCHAR(80) NOT NULL,
    category_id  INT NOT NULL,
    brand        VARCHAR(40) NULL,                            -- NULL = unbranded
    price        DECIMAL(10,2) NOT NULL,
    cost         DECIMAL(10,2) NOT NULL,
    stock_qty    INT NOT NULL DEFAULT 0,
    created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_products_category FOREIGN KEY (category_id) REFERENCES categories(category_id),
    CONSTRAINT chk_products_price CHECK (price > 0),
    CONSTRAINT chk_products_cost  CHECK (cost >= 0),
    CONSTRAINT chk_products_margin CHECK (price >= cost),
    CONSTRAINT chk_products_stock CHECK (stock_qty >= 0)
) ENGINE=InnoDB;

CREATE TABLE orders (
    order_id       INT AUTO_INCREMENT PRIMARY KEY,
    customer_id    INT NOT NULL,
    order_date     DATE NOT NULL,
    status         VARCHAR(12) NOT NULL DEFAULT 'PLACED',
    coupon_code    VARCHAR(15) NULL,                          -- NULL = no coupon used
    shipping_fee   DECIMAL(8,2) NOT NULL DEFAULT 0,
    shipped_date   DATE NULL,                                 -- NULL until shipped
    delivered_date DATE NULL,                                 -- NULL until delivered
    CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    CONSTRAINT fk_orders_coupon   FOREIGN KEY (coupon_code) REFERENCES coupons(coupon_code),
    CONSTRAINT chk_orders_status  CHECK (status IN ('PLACED','PAID','SHIPPED','DELIVERED','CANCELLED','RETURNED')),
    CONSTRAINT chk_orders_fee     CHECK (shipping_fee >= 0),
    CONSTRAINT chk_orders_ship    CHECK (shipped_date IS NULL OR shipped_date >= order_date),
    CONSTRAINT chk_orders_deliv   CHECK (delivered_date IS NULL OR (shipped_date IS NOT NULL AND delivered_date >= shipped_date))
) ENGINE=InnoDB;

CREATE TABLE order_items (
    order_item_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id      INT NOT NULL,
    product_id    INT NOT NULL,
    quantity      INT NOT NULL,
    unit_price    DECIMAL(10,2) NOT NULL,
    discount_amt  DECIMAL(10,2) NOT NULL DEFAULT 0,
    CONSTRAINT fk_items_order   FOREIGN KEY (order_id)   REFERENCES orders(order_id) ON DELETE CASCADE,
    CONSTRAINT fk_items_product FOREIGN KEY (product_id) REFERENCES products(product_id),
    CONSTRAINT uq_items_order_product UNIQUE (order_id, product_id),
    CONSTRAINT chk_items_qty   CHECK (quantity > 0),
    CONSTRAINT chk_items_price CHECK (unit_price > 0),
    CONSTRAINT chk_items_disc  CHECK (discount_amt >= 0 AND discount_amt <= quantity * unit_price)
) ENGINE=InnoDB;

CREATE TABLE payments (
    payment_id     INT AUTO_INCREMENT PRIMARY KEY,
    order_id       INT NOT NULL,
    payment_date   DATE NOT NULL,
    method         VARCHAR(12) NOT NULL,
    payment_status VARCHAR(10) NOT NULL,
    txn_ref        VARCHAR(20) NULL,                          -- NULL for cash on delivery
    amount         DECIMAL(12,2) NOT NULL DEFAULT 0,
    CONSTRAINT uq_payments_order UNIQUE (order_id),           -- one payment per order
    CONSTRAINT fk_payments_order FOREIGN KEY (order_id) REFERENCES orders(order_id),
    CONSTRAINT chk_payments_method CHECK (method IN ('UPI','CARD','NETBANKING','COD','WALLET')),
    CONSTRAINT chk_payments_status CHECK (payment_status IN ('SUCCESS','FAILED','REFUNDED')),
    CONSTRAINT chk_payments_amount CHECK (amount >= 0)
) ENGINE=InnoDB;

CREATE TABLE reviews (
    review_id   INT AUTO_INCREMENT PRIMARY KEY,
    product_id  INT NOT NULL,
    customer_id INT NOT NULL,
    rating      TINYINT NOT NULL,
    review_text VARCHAR(200) NULL,                            -- rating without text is allowed
    review_date DATE NOT NULL,
    CONSTRAINT fk_reviews_product  FOREIGN KEY (product_id)  REFERENCES products(product_id),
    CONSTRAINT fk_reviews_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    CONSTRAINT uq_reviews_once UNIQUE (product_id, customer_id),
    CONSTRAINT chk_reviews_rating CHECK (rating BETWEEN 1 AND 5)
) ENGINE=InnoDB;

-- =====================================================================
-- PART 2: SAMPLE DATA
-- =====================================================================

-- ---- categories: 20 rows (5 parents + 15 children) ------------------
INSERT INTO categories (category_name, parent_category_id) VALUES
('Electronics',        NULL),   -- 1
('Home & Kitchen',     NULL),   -- 2
('Fashion',            NULL),   -- 3
('Books',              NULL),   -- 4
('Sports & Fitness',   NULL),   -- 5
('Mobiles',            1),      -- 6
('Laptops',            1),      -- 7
('Audio',              1),      -- 8
('Cameras',            1),      -- 9
('Appliances',         2),      -- 10
('Cookware',           2),      -- 11
('Furniture',          2),      -- 12
('Mens Clothing',      3),      -- 13
('Womens Clothing',    3),      -- 14
('Footwear',           3),      -- 15
('Fiction',            4),      -- 16
('Technology Books',   4),      -- 17
('Fitness Equipment',  5),      -- 18
('Outdoor',            5),      -- 19
('Yoga',               5);      -- 20

-- ---- coupons: 20 rows -----------------------------------------------
INSERT INTO coupons (coupon_code, discount_pct, min_order_amount, valid_from, valid_to, is_active) VALUES
('WELCOME10',   10,   500, '2026-01-01', '2026-12-31', TRUE),
('FESTIVE15',   15,  2000, '2026-09-15', '2026-11-15', TRUE),
('DIWALI20',    20,  3000, '2026-10-01', '2026-11-20', TRUE),
('NEWYEAR12',   12,  1000, '2026-01-01', '2026-01-15', FALSE),
('SUMMER08',     8,   500, '2026-04-15', '2026-06-15', FALSE),
('MONSOON10',   10,  1000, '2026-06-01', '2026-09-15', FALSE),
('FREESHIP5',    5,     0, '2026-01-01', '2026-12-31', TRUE),
('STUDENT10',   10,   500, '2026-01-01', '2026-12-31', TRUE),
('LOYAL7',       7,  1500, '2026-01-01', '2026-12-31', TRUE),
('FLASH25',     25,  5000, '2026-09-10', '2026-09-20', FALSE),
('BIGSAVE18',   18, 10000, '2026-03-01', '2026-12-31', TRUE),
('APP5',         5,     0, '2026-01-01', '2026-12-31', TRUE),
('REPUBLIC15',  15,  2000, '2026-01-20', '2026-01-31', FALSE),
('HOLI10',      10,   800, '2026-03-01', '2026-03-10', FALSE),
('ONAM12',      12,  1500, '2026-08-20', '2026-09-10', FALSE),
('BDAY15',      15,  1000, '2026-01-01', '2026-12-31', TRUE),
('COMBO9',       9,  2500, '2026-01-01', '2026-12-31', TRUE),
('CLEARANCE30', 30,  3000, '2026-08-01', '2026-08-31', FALSE),
('VIP20',       20,  8000, '2026-01-01', '2026-12-31', TRUE),
('REFER10',     10,   500, '2026-01-01', '2026-12-31', TRUE);

-- ---- customers: 24 rows (phone, gender, referred_by contain NULLs) ----
INSERT INTO customers (first_name, last_name, email, phone, city, state, gender, signup_date, referred_by) VALUES
('Aarav',    'Sharma',     'aarav.sharma@mail.com',     '9876500001', 'Bengaluru',          'Karnataka',     'M',  '2025-01-10', NULL),
('Diya',     'Patel',      'diya.patel@mail.com',       '9876500002', 'Ahmedabad',          'Gujarat',       'F',  '2025-02-14', 1),
('Rohan',    'Mehta',      'rohan.mehta@mail.com',      NULL,         'Mumbai',             'Maharashtra',   'M',  '2025-03-02', NULL),
('Ananya',   'Iyer',       'ananya.iyer@mail.com',      '9876500004', 'Chennai',            'Tamil Nadu',    'F',  '2025-03-21', 2),
('Vikram',   'Singh',      'vikram.singh@mail.com',     '9876500005', 'Delhi',              'Delhi',         'M',  '2025-04-05', NULL),
('Sneha',    'Reddy',      'sneha.reddy@mail.com',      '9876500006', 'Hyderabad',          'Telangana',     'F',  '2025-04-19', 4),
('Karthik',  'Nair',       'karthik.nair@mail.com',     NULL,         'Kochi',              'Kerala',        'M',  '2025-05-08', NULL),
('Priya',    'Das',        'priya.das@mail.com',        '9876500008', 'Kolkata',            'West Bengal',   'F',  '2025-05-27', 1),
('Arjun',    'Verma',      'arjun.verma@mail.com',      '9876500009', 'Lucknow',            'Uttar Pradesh', NULL, '2025-06-11', NULL),
('Meera',    'Joshi',      'meera.joshi@mail.com',      '9876500010', 'Pune',               'Maharashtra',   'F',  '2025-06-30', 3),
('Rahul',    'Gupta',      'rahul.gupta@mail.com',      '9876500011', 'Gurugram',           'Haryana',       'M',  '2025-07-15', NULL),
('Ishita',   'Banerjee',   'ishita.banerjee@mail.com',  '9876500012', 'Kolkata',            'West Bengal',   'F',  '2025-08-01', 8),
('Siddharth','Rao',        'siddharth.rao@mail.com',    '9876500013', 'Bengaluru',          'Karnataka',     'M',  '2025-08-23', 1),
('Neha',     'Kapoor',     'neha.kapoor@mail.com',      '9876500014', 'Delhi',              'Delhi',         'F',  '2025-09-09', 5),
('Aditya',   'Kulkarni',   'aditya.kulkarni@mail.com',  NULL,         'Pune',               'Maharashtra',   'M',  '2025-09-28', NULL),
('Kavya',    'Menon',      'kavya.menon@mail.com',      '9876500016', 'Kochi',              'Kerala',        'F',  '2025-10-12', 7),
('Manish',   'Agarwal',    'manish.agarwal@mail.com',   '9876500017', 'Jaipur',             'Rajasthan',     'M',  '2025-11-03', NULL),
('Pooja',    'Bhatt',      'pooja.bhatt@mail.com',      '9876500018', 'Surat',              'Gujarat',       'F',  '2025-11-20', 2),
('Harsh',    'Vora',       'harsh.vora@mail.com',       '9876500019', 'Surat',              'Gujarat',       'M',  '2025-12-06', 18),
('Tanya',    'Malhotra',   'tanya.malhotra@mail.com',   '9876500020', 'Chandigarh',         'Chandigarh',    'F',  '2026-01-14', NULL),
('Nikhil',   'Chatterjee', 'nikhil.chatterjee@mail.com',NULL,         'Bhubaneswar',        'Odisha',        'M',  '2026-02-02', NULL),
('Lakshmi',  'Pillai',     'lakshmi.pillai@mail.com',   '9876500022', 'Chennai',            'Tamil Nadu',    'F',  '2026-02-25', 4),
('Imran',    'Qureshi',    'imran.qureshi@mail.com',    '9876500023', 'Hyderabad',          'Telangana',     'M',  '2026-03-18', 6),
('Jaya',     'Nambiar',    'jaya.nambiar@mail.com',     '9876500024', 'Thiruvananthapuram', 'Kerala',        'F',  '2026-04-07', 16);

-- ---- products: 30 rows (brand contains NULLs, one out of stock) -------
INSERT INTO products (product_name, category_id, brand, price, cost, stock_qty) VALUES
('Nova X5 Smartphone',            6, 'Nova',      24999, 19500, 120),  -- 1
('Nova Lite Smartphone',          6, 'Nova',      11999,  9200, 200),  -- 2
('Pixelon Z Smartphone',          6, 'Pixelon',   34999, 28000,  80),  -- 3
('Zentech Air 13 Laptop',         7, 'Zentech',   54999, 45000,  40),  -- 4
('Zentech Pro 15 Laptop',         7, 'Zentech',   78999, 65000,  25),  -- 5
('CodeBook Student Laptop',       7, 'CodeBook',  32999, 27500,  60),  -- 6
('SoundWave ANC Headphones',      8, 'SoundWave',  5999,  3600, 150),  -- 7
('SoundWave Earbuds',             8, 'SoundWave',  2499,  1400, 300),  -- 8
('BassBox Bluetooth Speaker',     8, 'BassBox',    3499,  2100,  90),  -- 9
('LensPro Mirrorless Camera',     9, 'LensPro',   62999, 52000,  15),  -- 10
('Mixmaster 750W Mixer Grinder', 10, 'Mixmaster',  3999,  2600, 110),  -- 11
('AirChef Air Fryer',            10, 'AirChef',    6499,  4300,  75),  -- 12
('CoolBreeze Tower Fan',         10, NULL,         4299,  2900,  55),  -- 13
('HeatWell Induction Cooktop',   10, 'HeatWell',   2999,  1900,  70),  -- 14
('IronCraft Non-stick Pan Set',  11, 'IronCraft',  1999,  1100, 140),  -- 15
('SteelMate Pressure Cooker 5L', 11, 'SteelMate',  1799,  1050, 130),  -- 16
('ErgoSit Office Chair',         12, 'ErgoSit',   10999,  6500,  35),  -- 17
('DeskMate Study Desk',          12, 'DeskMate',   6499,  3800,  28),  -- 18
('UrbanWear Cotton Shirt',       13, 'UrbanWear',  1199,   450, 400),  -- 19
('UrbanWear Slim Chinos',        13, 'UrbanWear',  1799,   700, 260),  -- 20
('StyleHer Cotton Kurti',        14, 'StyleHer',    999,   380, 350),  -- 21
('StyleHer Denim Jacket',        14, 'StyleHer',   3299,  1300,  90),  -- 22
('RunFast Running Shoes',        15, 'RunFast',    3499,  1500, 180),  -- 23
('WalkEasy Sandals',             15, NULL,          799,   350,   0),  -- 24
('The Python Handbook',          17, 'PageTurner',  599,   280, 500),  -- 25
('SQL in 30 Days',               17, 'PageTurner',  499,   220, 450),  -- 26
('Midnight Mystery Novel',       16, 'PageTurner',  349,   150, 320),  -- 27
('FitCore Dumbbell Set 20kg',    18, 'FitCore',    2999,  1700,  85),  -- 28
('TrailMax Hiking Backpack 40L', 19, 'TrailMax',   2499,  1300,  95),  -- 29
('ZenFlow Yoga Mat',             20, 'ZenFlow',     899,   400, 220);  -- 30

-- ---- orders: 32 rows (coupon_code, shipped_date, delivered_date contain NULLs) ----
INSERT INTO orders (customer_id, order_date, status, coupon_code, shipping_fee, shipped_date, delivered_date) VALUES
( 1,'2026-04-03','DELIVERED','WELCOME10', 0,'2026-04-04','2026-04-08'),  -- 1
( 2,'2026-04-07','DELIVERED',NULL,       99,'2026-04-08','2026-04-12'),  -- 2
( 3,'2026-04-12','DELIVERED',NULL,        0,'2026-04-13','2026-04-17'),  -- 3
( 4,'2026-04-18','DELIVERED',NULL,       49,'2026-04-19','2026-04-23'),  -- 4
( 5,'2026-04-25','RETURNED', NULL,        0,'2026-04-26','2026-04-30'),  -- 5
( 6,'2026-05-02','DELIVERED','SUMMER08',  0,'2026-05-03','2026-05-07'),  -- 6
( 7,'2026-05-09','DELIVERED',NULL,       99,'2026-05-10','2026-05-15'),  -- 7
( 8,'2026-05-14','DELIVERED','STUDENT10',49,'2026-05-15','2026-05-19'),  -- 8
( 9,'2026-05-21','CANCELLED',NULL,        0,NULL,NULL),                  -- 9
(10,'2026-05-28','DELIVERED',NULL,        0,'2026-05-29','2026-06-02'),  -- 10
(11,'2026-06-03','DELIVERED',NULL,       99,'2026-06-04','2026-06-08'),  -- 11
(12,'2026-06-10','DELIVERED','MONSOON10',49,'2026-06-11','2026-06-16'),  -- 12
(13,'2026-06-16','DELIVERED',NULL,        0,'2026-06-17','2026-06-21'),  -- 13
(14,'2026-06-24','DELIVERED',NULL,       99,'2026-06-25','2026-06-29'),  -- 14
(15,'2026-07-01','DELIVERED','LOYAL7',    0,'2026-07-02','2026-07-06'),  -- 15
(16,'2026-07-08','DELIVERED',NULL,       49,'2026-07-09','2026-07-13'),  -- 16
(17,'2026-07-15','RETURNED', NULL,        0,'2026-07-16','2026-07-21'),  -- 17
(18,'2026-07-22','DELIVERED',NULL,       99,'2026-07-23','2026-07-27'),  -- 18
(19,'2026-07-29','DELIVERED','REFER10',   0,'2026-07-30','2026-08-03'),  -- 19
(20,'2026-08-04','DELIVERED',NULL,       49,'2026-08-05','2026-08-09'),  -- 20
( 1,'2026-08-11','DELIVERED','BDAY15',    0,'2026-08-12','2026-08-16'),  -- 21
( 2,'2026-08-17','DELIVERED',NULL,        0,'2026-08-18','2026-08-22'),  -- 22
( 3,'2026-08-25','DELIVERED','ONAM12',   99,'2026-08-26','2026-08-31'),  -- 23
( 4,'2026-09-01','DELIVERED',NULL,       49,'2026-09-02','2026-09-06'),  -- 24
( 5,'2026-09-07','SHIPPED',  NULL,       99,'2026-09-08',NULL),          -- 25
( 8,'2026-09-13','DELIVERED','FLASH25',   0,'2026-09-14','2026-09-18'),  -- 26
(10,'2026-09-19','DELIVERED',NULL,        0,'2026-09-20','2026-09-24'),  -- 27
(13,'2026-09-24','CANCELLED',NULL,       49,NULL,NULL),                  -- 28
( 1,'2026-09-29','SHIPPED',  'FESTIVE15', 0,'2026-09-30',NULL),          -- 29
( 6,'2026-10-03','PAID',     NULL,       99,NULL,NULL),                  -- 30
(11,'2026-10-08','PLACED',   NULL,       49,NULL,NULL),                  -- 31
(14,'2026-10-12','PLACED',   'DIWALI20',  0,NULL,NULL);                  -- 32

-- ---- order_items: 65 rows -------------------------------------------
INSERT INTO order_items (order_id, product_id, quantity, unit_price, discount_amt) VALUES
( 1, 1,1,24999,0), ( 1, 8,1, 2499,0),
( 2, 7,1, 5999,0), ( 2,19,2, 1199,0),
( 3, 4,1,54999,0), ( 3, 9,1, 3499,0),
( 4,21,2,  999,0), ( 4,23,1, 3499,200),
( 5, 3,1,34999,0), ( 5, 8,2, 2499,0),
( 6,11,1, 3999,0), ( 6,15,1, 1999,0), ( 6,16,1, 1799,0),
( 7,17,1,10999,0), ( 7,30,2,  899,0),
( 8,26,2,  499,0), ( 8,25,1,  599,0), ( 8, 6,1,32999,0),
( 9,12,1, 6499,0),
(10,20,2, 1799,0), (10,19,1, 1199,0),
(11, 5,1,78999,0), (11, 7,1, 5999,0),
(12, 2,1,11999,0), (12, 9,1, 3499,0),
(13,14,1, 2999,0), (13,12,1, 6499,0),
(14,22,1, 3299,0), (14,21,1,  999,0), (14,30,1, 899,0),
(15,10,1,62999,0),
(16,28,1, 2999,0), (16,29,1, 2499,0),
(17,14,1, 2999,0), (17,18,1, 6499,0),
(18,27,3,  349,0), (18,26,1,  499,0),
(19, 1,1,24999,0), (19, 7,1, 5999,0),
(20,23,1, 3499,0), (20,19,2, 1199,0),
(21, 3,1,34999,0), (21, 8,1, 2499,0),
(22,25,2,  599,0), (22,26,2,  499,0),
(23, 4,1,54999,0), (23, 7,1, 5999,0),
(24,15,2, 1999,0), (24,16,1, 1799,0),
(25,17,1,10999,0), (25,18,1, 6499,0),
(26, 2,2,11999,0), (26, 8,2, 2499,0),
(27,30,3,  899,0), (27,28,1, 2999,0),
(28, 6,1,32999,0),
(29, 5,1,78999,0), (29, 9,1, 3499,0),
(30,20,1, 1799,0), (30,22,1, 3299,0), (30,23,1, 3499,0),
(31,21,1,  999,0), (31,20,1, 1799,0),
(32,10,1,62999,0), (32, 8,1, 2499,0);

-- ---- payments: 30 rows (COD rows have NULL txn_ref; amount filled below) ----
INSERT INTO payments (order_id, payment_date, method, payment_status, txn_ref) VALUES
( 1,'2026-04-03','UPI',        'SUCCESS','TXN100001'),
( 2,'2026-04-07','CARD',       'SUCCESS','TXN100002'),
( 3,'2026-04-12','NETBANKING', 'SUCCESS','TXN100003'),
( 4,'2026-04-23','COD',        'SUCCESS',NULL),
( 5,'2026-04-25','UPI',        'REFUNDED','TXN100005'),
( 6,'2026-05-02','CARD',       'SUCCESS','TXN100006'),
( 7,'2026-05-15','COD',        'SUCCESS',NULL),
( 8,'2026-05-14','WALLET',     'SUCCESS','TXN100008'),
( 9,'2026-05-21','UPI',        'FAILED', 'TXN100009'),
(10,'2026-05-28','UPI',        'SUCCESS','TXN100010'),
(11,'2026-06-03','CARD',       'SUCCESS','TXN100011'),
(12,'2026-06-10','NETBANKING', 'SUCCESS','TXN100012'),
(13,'2026-06-16','UPI',        'SUCCESS','TXN100013'),
(14,'2026-06-29','COD',        'SUCCESS',NULL),
(15,'2026-07-01','CARD',       'SUCCESS','TXN100015'),
(16,'2026-07-08','WALLET',     'SUCCESS','TXN100016'),
(17,'2026-07-15','UPI',        'REFUNDED','TXN100017'),
(18,'2026-07-27','COD',        'SUCCESS',NULL),
(19,'2026-07-29','UPI',        'SUCCESS','TXN100019'),
(20,'2026-08-04','CARD',       'SUCCESS','TXN100020'),
(21,'2026-08-11','NETBANKING', 'SUCCESS','TXN100021'),
(22,'2026-08-17','UPI',        'SUCCESS','TXN100022'),
(23,'2026-08-25','CARD',       'SUCCESS','TXN100023'),
(24,'2026-09-06','COD',        'SUCCESS',NULL),
(25,'2026-09-07','UPI',        'SUCCESS','TXN100025'),
(26,'2026-09-13','WALLET',     'SUCCESS','TXN100026'),
(27,'2026-09-19','UPI',        'SUCCESS','TXN100027'),
(28,'2026-09-24','CARD',       'REFUNDED','TXN100028'),
(29,'2026-09-29','UPI',        'SUCCESS','TXN100029'),
(30,'2026-10-03','CARD',       'SUCCESS','TXN100030');

-- ---- reviews: 22 rows (review_text contains NULLs) -------------------
INSERT INTO reviews (product_id, customer_id, rating, review_text, review_date) VALUES
( 1, 1,5,'Great phone, super fast',        '2026-04-15'),
( 8, 1,4,NULL,                             '2026-04-16'),
( 7, 2,5,'Excellent noise cancellation',   '2026-04-20'),
(19, 2,3,'Fabric is okay, runs small',     '2026-04-21'),
( 4, 3,5,'Best laptop in this range',      '2026-04-25'),
( 9, 3,4,'Good sound for the price',       '2026-04-26'),
(21, 4,4,NULL,                             '2026-05-01'),
(23, 4,5,'Very comfortable',               '2026-05-02'),
( 3, 5,2,'Returned - camera issues',       '2026-05-05'),
(11, 6,4,'Powerful grinder',               '2026-05-12'),
(17, 7,5,'Back pain gone',                 '2026-05-25'),
(26, 8,5,'Clear and practical',            '2026-05-27'),
( 6, 8,3,NULL,                             '2026-05-28'),
(20,10,4,'Good fit',                       '2026-06-08'),
( 5,11,5,'Beast of a machine',             '2026-06-15'),
( 2,12,4,'Value for money',                '2026-06-22'),
(14,13,3,'Heats slowly',                   '2026-07-03'),
(10,15,5,'Stunning photos',                '2026-07-14'),
(28,16,4,NULL,                             '2026-07-20'),
(27,18,4,'Gripping story',                 '2026-08-02'),
( 1,19,4,'Good battery',                   '2026-08-10'),
(23,20,2,'Sole wore out quickly',          '2026-08-20');

-- =====================================================================
-- PART 3: HELPER VIEWS (+ fill payment amounts from the order totals)
-- =====================================================================

-- Order-level totals: items - coupon discount + shipping
CREATE OR REPLACE VIEW v_order_totals AS
SELECT o.order_id, o.customer_id, o.order_date, o.status, o.coupon_code,
       SUM(oi.quantity * oi.unit_price - oi.discount_amt)                            AS items_total,
       COALESCE(c.discount_pct, 0)                                                   AS coupon_pct,
       ROUND(SUM(oi.quantity * oi.unit_price - oi.discount_amt) * COALESCE(c.discount_pct,0) / 100, 2) AS coupon_discount,
       o.shipping_fee,
       ROUND(SUM(oi.quantity * oi.unit_price - oi.discount_amt) * (1 - COALESCE(c.discount_pct,0)/100) + o.shipping_fee, 2) AS net_total
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
LEFT JOIN coupons c ON c.coupon_code = o.coupon_code
GROUP BY o.order_id, o.customer_id, o.order_date, o.status, o.coupon_code, c.discount_pct, o.shipping_fee;

-- Revenue-bearing line items only (cancelled / returned / unpaid orders excluded)
CREATE OR REPLACE VIEW v_sales_lines AS
SELECT oi.order_id, o.customer_id, o.order_date, o.status,
       oi.product_id, p.product_name, p.brand, p.category_id, p.cost,
       oi.quantity, oi.unit_price, oi.discount_amt,
       oi.quantity * oi.unit_price - oi.discount_amt AS line_revenue,
       oi.quantity * p.cost                          AS line_cost
FROM order_items oi
JOIN orders   o ON o.order_id   = oi.order_id
JOIN products p ON p.product_id = oi.product_id
WHERE o.status IN ('PAID','SHIPPED','DELIVERED');

UPDATE payments p
JOIN v_order_totals t ON t.order_id = p.order_id
SET p.amount = t.net_total;

-- Row counts (expect: 20, 20, 24, 30, 32, 65, 30, 22)
SELECT 'categories' AS tbl, COUNT(*) AS n FROM categories
UNION ALL SELECT 'coupons',     COUNT(*) FROM coupons
UNION ALL SELECT 'customers',   COUNT(*) FROM customers
UNION ALL SELECT 'products',    COUNT(*) FROM products
UNION ALL SELECT 'orders',      COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'payments',    COUNT(*) FROM payments
UNION ALL SELECT 'reviews',     COUNT(*) FROM reviews;

-- =====================================================================
-- PART 4: THE QUERIES  (Q01 - Q44)
-- "Revenue" below = orders with status PAID, SHIPPED or DELIVERED.
-- =====================================================================

-- ---------------------------------------------------------------------
-- SECTION A: DDL CONSTRAINTS
-- ---------------------------------------------------------------------

-- Q01. Every constraint in the schema, by table and type
SELECT table_name, constraint_name, constraint_type
FROM information_schema.table_constraints
WHERE table_schema = 'ecommerce_db'
ORDER BY table_name, FIELD(constraint_type,'PRIMARY KEY','UNIQUE','FOREIGN KEY','CHECK'), constraint_name;

-- Q02. Foreign key map: which column points where
SELECT table_name, column_name, constraint_name, referenced_table_name, referenced_column_name
FROM information_schema.key_column_usage
WHERE table_schema = 'ecommerce_db' AND referenced_table_name IS NOT NULL
ORDER BY table_name, constraint_name;

-- Q03. CHECK constraint definitions
SELECT tc.table_name, cc.constraint_name, cc.check_clause
FROM information_schema.check_constraints cc
JOIN information_schema.table_constraints tc
  ON tc.constraint_schema = cc.constraint_schema AND tc.constraint_name = cc.constraint_name
WHERE cc.constraint_schema = 'ecommerce_db'
ORDER BY tc.table_name, cc.constraint_name;

-- Q04. ALTER TABLE: add constraints, a column and an index after creation
--      (UNIQUE allows many NULL phones but rejects duplicate real numbers)
ALTER TABLE customers ADD CONSTRAINT uq_customers_phone UNIQUE (phone);
ALTER TABLE products  ADD CONSTRAINT chk_products_stock_max CHECK (stock_qty <= 100000);
ALTER TABLE products  ADD COLUMN warranty_months INT NULL;
ALTER TABLE orders    ADD INDEX idx_orders_status_date (status, order_date);
ALTER TABLE order_items ADD INDEX idx_items_product (product_id);

-- Q05. Constraint tests: each statement below is EXPECTED to fail.
--      Uncomment one at a time (a failing statement stops a script run, so they are commented out).
-- INSERT INTO customers (first_name,last_name,email,city,state,signup_date)
--     VALUES ('Dup','Email','aarav.sharma@mail.com','X','Y','2026-01-01');      -- UNIQUE email
-- INSERT INTO customers (first_name,last_name,email,city,state,signup_date)
--     VALUES ('Bad','Mail','not-an-email','X','Y','2026-01-01');                 -- CHECK email format
-- INSERT INTO customers (first_name,last_name,email,city,state,gender,signup_date)
--     VALUES ('Bad','Gender','bg@mail.com','X','Y','Z','2026-01-01');            -- CHECK gender
-- INSERT INTO products (product_name,category_id,price,cost) VALUES ('Loss Maker',6,100,200); -- CHECK price >= cost
-- INSERT INTO products (product_name,category_id,price,cost) VALUES ('No Cat',999,100,50);    -- FK category
-- INSERT INTO products (product_name,category_id,price,cost,stock_qty) VALUES ('Neg',6,100,50,-5); -- CHECK stock
-- INSERT INTO orders (customer_id,order_date,status) VALUES (1,'2026-10-01','SHIPPING');      -- CHECK status
-- INSERT INTO orders (customer_id,order_date,status,shipped_date) VALUES (1,'2026-10-05','PAID','2026-10-01'); -- CHECK ship date
-- INSERT INTO order_items (order_id,product_id,quantity,unit_price) VALUES (1,1,0,100);       -- CHECK quantity
-- INSERT INTO order_items (order_id,product_id,quantity,unit_price) VALUES (1,1,1,24999);     -- UNIQUE (order, product)
-- INSERT INTO payments (order_id,payment_date,method,payment_status) VALUES (1,'2026-10-01','CASH','SUCCESS'); -- CHECK method
-- INSERT INTO reviews (product_id,customer_id,rating,review_date) VALUES (1,2,6,'2026-10-01');  -- CHECK rating
-- DELETE FROM customers WHERE customer_id = 1;       -- FK RESTRICT: customer has orders
-- DELETE FROM coupons WHERE coupon_code = 'WELCOME10'; -- FK RESTRICT: used by an order

-- ---------------------------------------------------------------------
-- SECTION B: TOP PRODUCTS
-- ---------------------------------------------------------------------

-- Q06. Top 10 products by revenue
SELECT product_id, product_name, SUM(quantity) AS units_sold, SUM(line_revenue) AS revenue
FROM v_sales_lines
GROUP BY product_id, product_name
ORDER BY revenue DESC
LIMIT 10;

-- Q07. Top 5 products by units sold
SELECT product_id, product_name, SUM(quantity) AS units_sold
FROM v_sales_lines
GROUP BY product_id, product_name
ORDER BY units_sold DESC, product_name
LIMIT 5;

-- Q08. Top 10 products by profit, with margin % (NULLIF protects against divide by zero)
SELECT product_name,
       SUM(line_revenue)                 AS revenue,
       SUM(line_revenue - line_cost)     AS profit,
       ROUND(100 * SUM(line_revenue - line_cost) / NULLIF(SUM(line_revenue), 0), 2) AS margin_pct
FROM v_sales_lines
GROUP BY product_id, product_name
ORDER BY profit DESC
LIMIT 10;

-- Q09. Best-selling product inside each category (window function RANK)
SELECT category_name, product_name, revenue
FROM (
    SELECT c.category_name, s.product_name, SUM(s.line_revenue) AS revenue,
           RANK() OVER (PARTITION BY c.category_name ORDER BY SUM(s.line_revenue) DESC) AS rnk
    FROM v_sales_lines s
    JOIN categories c ON c.category_id = s.category_id
    GROUP BY c.category_name, s.product_name
) t
WHERE rnk = 1
ORDER BY revenue DESC;

-- Q10. Revenue by top-level category (child category joined to its parent)
SELECT COALESCE(parent.category_name, c.category_name) AS top_category,
       SUM(s.quantity)     AS units,
       SUM(s.line_revenue) AS revenue
FROM v_sales_lines s
JOIN categories c           ON c.category_id = s.category_id
LEFT JOIN categories parent ON parent.category_id = c.parent_category_id
GROUP BY COALESCE(parent.category_name, c.category_name)
ORDER BY revenue DESC;

-- Q11. Products that were never ordered (LEFT JOIN ... IS NULL anti-join)
SELECT p.product_id, p.product_name, COALESCE(p.brand,'Unbranded') AS brand, p.price
FROM products p
LEFT JOIN order_items oi ON oi.product_id = p.product_id
WHERE oi.order_item_id IS NULL;

-- Q12. Highest rated products (average rating and review count)
SELECT p.product_name, COUNT(r.review_id) AS reviews, ROUND(AVG(r.rating), 2) AS avg_rating
FROM products p
JOIN reviews r ON r.product_id = p.product_id
GROUP BY p.product_id, p.product_name
ORDER BY avg_rating DESC, reviews DESC, p.product_name
LIMIT 10;

-- Q13. Inventory alert: low or empty stock
SELECT product_id, product_name, stock_qty,
       CASE WHEN stock_qty = 0  THEN 'OUT OF STOCK'
            WHEN stock_qty < 40 THEN 'LOW'
            ELSE 'OK' END AS stock_flag
FROM products
WHERE stock_qty < 40
ORDER BY stock_qty, product_name;

-- ---------------------------------------------------------------------
-- SECTION C: CUSTOMER SPEND
-- ---------------------------------------------------------------------

-- Q14. Top 10 customers by lifetime spend
SELECT c.customer_id, CONCAT(c.first_name,' ',c.last_name) AS customer,
       COUNT(*) AS orders, SUM(t.net_total) AS lifetime_spend
FROM customers c
JOIN v_order_totals t ON t.customer_id = c.customer_id
WHERE t.status IN ('PAID','SHIPPED','DELIVERED')
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY lifetime_spend DESC
LIMIT 10;

-- Q15. Average and largest order value per customer
SELECT CONCAT(c.first_name,' ',c.last_name) AS customer,
       COUNT(*)                    AS orders,
       ROUND(AVG(t.net_total), 2)  AS avg_order_value,
       MAX(t.net_total)            AS largest_order
FROM customers c
JOIN v_order_totals t ON t.customer_id = c.customer_id
WHERE t.status IN ('PAID','SHIPPED','DELIVERED')
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY avg_order_value DESC;

-- Q16. Spend tiers (CASE) including customers with no purchases
WITH cs AS (
    SELECT c.customer_id, COALESCE(SUM(t.net_total), 0) AS spend
    FROM customers c
    LEFT JOIN v_order_totals t
           ON t.customer_id = c.customer_id AND t.status IN ('PAID','SHIPPED','DELIVERED')
    GROUP BY c.customer_id
)
SELECT CASE WHEN spend >= 80000 THEN '1-High'
            WHEN spend >= 20000 THEN '2-Medium'
            WHEN spend >  0     THEN '3-Low'
            ELSE '4-No purchase' END AS tier,
       COUNT(*) AS customers, ROUND(SUM(spend), 2) AS total_spend
FROM cs
GROUP BY tier
ORDER BY tier;

-- Q17. Revenue by state
SELECT c.state, COUNT(DISTINCT c.customer_id) AS customers, COUNT(*) AS orders, SUM(t.net_total) AS revenue
FROM customers c
JOIN v_order_totals t ON t.customer_id = c.customer_id
WHERE t.status IN ('PAID','SHIPPED','DELIVERED')
GROUP BY c.state
ORDER BY revenue DESC;

-- Q18. Repeat buyers vs one-time buyers
WITH oc AS (
    SELECT customer_id, COUNT(*) AS n
    FROM orders WHERE status IN ('PAID','SHIPPED','DELIVERED')
    GROUP BY customer_id
)
SELECT CASE WHEN n = 1 THEN 'One-time buyer' ELSE 'Repeat buyer' END AS buyer_type,
       COUNT(*) AS customers
FROM oc
GROUP BY buyer_type;

-- Q19. Customers who never placed an order (anti-join)
SELECT c.customer_id, CONCAT(c.first_name,' ',c.last_name) AS customer, c.city, c.signup_date
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
WHERE o.order_id IS NULL
ORDER BY c.signup_date;

-- Q20. Monthly revenue, orders and active customers
SELECT DATE_FORMAT(order_date, '%Y-%m') AS month,
       COUNT(*)                         AS orders,
       COUNT(DISTINCT customer_id)      AS active_customers,
       SUM(net_total)                   AS revenue
FROM v_order_totals
WHERE status IN ('PAID','SHIPPED','DELIVERED')
GROUP BY DATE_FORMAT(order_date, '%Y-%m')
ORDER BY month;

-- Q21. First order, latest order and the gap between them
SELECT CONCAT(c.first_name,' ',c.last_name) AS customer,
       MIN(o.order_date) AS first_order, MAX(o.order_date) AS last_order,
       DATEDIFF(MAX(o.order_date), MIN(o.order_date)) AS days_between,
       COUNT(*) AS orders
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
HAVING COUNT(*) > 1
ORDER BY days_between DESC;

-- Q22. Spend by gender (NULL gender shown as 'Unknown')
SELECT COALESCE(c.gender, 'Unknown') AS gender,
       COUNT(DISTINCT c.customer_id) AS customers,
       SUM(t.net_total)              AS revenue
FROM customers c
JOIN v_order_totals t ON t.customer_id = c.customer_id
WHERE t.status IN ('PAID','SHIPPED','DELIVERED')
GROUP BY COALESCE(c.gender, 'Unknown')
ORDER BY revenue DESC;

-- Q23. Referral programme: how many customers each referrer brought and what they spent (self join)
SELECT CONCAT(r.first_name,' ',r.last_name) AS referrer,
       COUNT(DISTINCT c.customer_id)        AS referred_customers,
       COALESCE(SUM(t.net_total), 0)        AS revenue_from_referred
FROM customers r
JOIN customers c ON c.referred_by = r.customer_id
LEFT JOIN v_order_totals t
       ON t.customer_id = c.customer_id AND t.status IN ('PAID','SHIPPED','DELIVERED')
GROUP BY r.customer_id, r.first_name, r.last_name
ORDER BY referred_customers DESC, revenue_from_referred DESC;

-- ---------------------------------------------------------------------
-- SECTION D: NULL HANDLING
-- ---------------------------------------------------------------------

-- Q24. IS NULL / IS NOT NULL: customers with no phone number on file
SELECT customer_id, CONCAT(first_name,' ',last_name) AS customer, email
FROM customers
WHERE phone IS NULL;

-- Q25. COALESCE gives readable defaults for NULL phone and NULL brand
SELECT customer_id, COALESCE(phone, 'No phone on file') AS phone FROM customers WHERE customer_id IN (1,3,7);
SELECT product_id, product_name, COALESCE(brand, 'Unbranded') AS brand FROM products WHERE brand IS NULL;

-- Q26. The classic NULL trap: <> never matches NULL rows
SELECT COUNT(*) AS wrong_count  FROM orders WHERE coupon_code <> 'WELCOME10';                        -- skips the NULLs
SELECT COUNT(*) AS right_count  FROM orders WHERE coupon_code <> 'WELCOME10' OR coupon_code IS NULL;
SELECT COUNT(*) AS nullsafe     FROM orders WHERE NOT (coupon_code <=> 'WELCOME10');                 -- NULL-safe equality

-- Q27. COUNT(*) vs COUNT(column) vs COUNT(DISTINCT column)
SELECT COUNT(*)                    AS all_orders,
       COUNT(coupon_code)          AS orders_with_coupon,
       COUNT(DISTINCT coupon_code) AS distinct_coupons_used,
       COUNT(*) - COUNT(coupon_code) AS orders_without_coupon,
       COUNT(shipped_date)         AS shipped_orders,
       COUNT(delivered_date)       AS delivered_orders
FROM orders;

-- Q28. Aggregates skip NULLs; SUM over zero rows is NULL, so wrap it in COALESCE
SELECT AVG(DATEDIFF(delivered_date, order_date))              AS avg_days_to_deliver,   -- ignores undelivered
       AVG(COALESCE(DATEDIFF(delivered_date, order_date), 0)) AS misleading_avg_with_zeros
FROM orders;
SELECT SUM(amount) AS sum_empty_set, COALESCE(SUM(amount), 0) AS safe_sum
FROM payments WHERE payment_status = 'NONE';

-- Q29. NULLIF avoids divide-by-zero: reviews per 100 units sold, product by product
SELECT p.product_name,
       COALESCE(u.units, 0)  AS units_sold,
       COALESCE(rv.cnt, 0)   AS reviews,
       ROUND(100 * COALESCE(rv.cnt, 0) / NULLIF(COALESCE(u.units, 0), 0), 1) AS reviews_per_100_units
FROM products p
LEFT JOIN (SELECT product_id, SUM(quantity) AS units FROM v_sales_lines GROUP BY product_id) u ON u.product_id = p.product_id
LEFT JOIN (SELECT product_id, COUNT(*) AS cnt FROM reviews GROUP BY product_id) rv            ON rv.product_id = p.product_id
ORDER BY reviews_per_100_units DESC, p.product_name;

-- Q30. Delivery status text from NULL dates (IFNULL / CASE) and NULLs sorted last
SELECT order_id, status,
       IFNULL(DATE_FORMAT(delivered_date,'%d-%b-%Y'), 'Not delivered yet') AS delivered_on,
       CASE WHEN shipped_date IS NULL THEN 'Not shipped'
            WHEN delivered_date IS NULL THEN 'In transit'
            ELSE CONCAT(DATEDIFF(delivered_date, shipped_date), ' days in transit') END AS transit_info
FROM orders
ORDER BY delivered_date IS NULL, delivered_date DESC
LIMIT 15;

-- Q31. Coupon vs no-coupon orders (revenue comparison driven by a NULL test)
SELECT CASE WHEN coupon_code IS NULL THEN 'No coupon' ELSE 'Coupon used' END AS coupon_usage,
       COUNT(*) AS orders, ROUND(AVG(items_total), 2) AS avg_basket,
       ROUND(SUM(coupon_discount), 2) AS discount_given
FROM v_order_totals
WHERE status IN ('PAID','SHIPPED','DELIVERED')
GROUP BY coupon_usage;

-- ---------------------------------------------------------------------
-- SECTION E: JOINS
-- ---------------------------------------------------------------------

-- Q32. INNER JOIN across 4 tables: full order detail
SELECT o.order_id, o.order_date, CONCAT(c.first_name,' ',c.last_name) AS customer,
       p.product_name, oi.quantity, oi.unit_price,
       oi.quantity * oi.unit_price - oi.discount_amt AS line_total
FROM orders o
JOIN customers   c  ON c.customer_id = o.customer_id
JOIN order_items oi ON oi.order_id   = o.order_id
JOIN products    p  ON p.product_id  = oi.product_id
ORDER BY o.order_id, p.product_name
LIMIT 25;

-- Q33. LEFT JOIN: every customer with an order count (zero included)
SELECT c.customer_id, CONCAT(c.first_name,' ',c.last_name) AS customer, COUNT(o.order_id) AS orders
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY orders DESC, customer;

-- Q34. RIGHT JOIN: every category, even parents that hold no products directly
SELECT c.category_name, COUNT(p.product_id) AS products
FROM products p
RIGHT JOIN categories c ON c.category_id = p.category_id
GROUP BY c.category_id, c.category_name
ORDER BY products DESC, c.category_name;

-- Q35. FULL OUTER JOIN emulation (MySQL has none): LEFT JOIN UNION RIGHT JOIN
SELECT p.product_name, r.review_id, r.rating
FROM products p LEFT JOIN reviews r ON r.product_id = p.product_id
UNION
SELECT p.product_name, r.review_id, r.rating
FROM products p RIGHT JOIN reviews r ON r.product_id = p.product_id
ORDER BY product_name, review_id;

-- Q36. SELF JOIN: category hierarchy (child -> parent)
SELECT child.category_name AS category, COALESCE(parent.category_name, '(top level)') AS parent_category
FROM categories child
LEFT JOIN categories parent ON parent.category_id = child.parent_category_id
ORDER BY parent_category, category;

-- Q37. CROSS JOIN: complete payment method x status matrix, zeros included
SELECT m.method, s.payment_status, COUNT(p.payment_id) AS payments
FROM (SELECT 'UPI' AS method UNION ALL SELECT 'CARD' UNION ALL SELECT 'NETBANKING'
      UNION ALL SELECT 'COD' UNION ALL SELECT 'WALLET') m
CROSS JOIN (SELECT 'SUCCESS' AS payment_status UNION ALL SELECT 'FAILED' UNION ALL SELECT 'REFUNDED') s
LEFT JOIN payments p ON p.method = m.method AND p.payment_status = s.payment_status
GROUP BY m.method, s.payment_status
ORDER BY m.method, s.payment_status;

-- Q38. Orders with no payment record, and shipped/delivered orders whose payment did not succeed
SELECT o.order_id, o.status, p.payment_status,
       CASE WHEN p.payment_id IS NULL THEN 'No payment recorded'
            ELSE 'Payment not successful' END AS issue
FROM orders o
LEFT JOIN payments p ON p.order_id = o.order_id
WHERE p.payment_id IS NULL
   OR (o.status IN ('SHIPPED','DELIVERED') AND p.payment_status <> 'SUCCESS');

-- Q39. EXISTS / NOT EXISTS: customers who bought Electronics vs customers who ordered but never did
SELECT cu.customer_id, CONCAT(cu.first_name,' ',cu.last_name) AS customer, 'Bought Electronics' AS segment
FROM customers cu
WHERE EXISTS (SELECT 1
              FROM orders o
              JOIN order_items oi ON oi.order_id = o.order_id
              JOIN products p     ON p.product_id = oi.product_id
              JOIN categories c   ON c.category_id = p.category_id
              WHERE o.customer_id = cu.customer_id AND c.parent_category_id = 1)
UNION ALL
SELECT cu.customer_id, CONCAT(cu.first_name,' ',cu.last_name), 'Ordered, no Electronics'
FROM customers cu
WHERE EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = cu.customer_id)
  AND NOT EXISTS (SELECT 1
                  FROM orders o
                  JOIN order_items oi ON oi.order_id = o.order_id
                  JOIN products p     ON p.product_id = oi.product_id
                  JOIN categories c   ON c.category_id = p.category_id
                  WHERE o.customer_id = cu.customer_id AND c.parent_category_id = 1)
ORDER BY segment, customer_id;

-- Q40. Join to a derived table: products priced above their category average
SELECT p.product_name, c.category_name, p.price, ROUND(a.avg_price, 2) AS category_avg_price
FROM products p
JOIN categories c ON c.category_id = p.category_id
JOIN (SELECT category_id, AVG(price) AS avg_price FROM products GROUP BY category_id) a
  ON a.category_id = p.category_id
WHERE p.price > a.avg_price
ORDER BY c.category_name, p.price DESC;

-- ---------------------------------------------------------------------
-- SECTION F: REPORTING WITH WINDOWS
-- ---------------------------------------------------------------------

-- Q41. Running total of monthly revenue and month-over-month growth (first month is NULL by design)
WITH m AS (
    SELECT DATE_FORMAT(order_date, '%Y-%m') AS ym, SUM(net_total) AS revenue
    FROM v_order_totals
    WHERE status IN ('PAID','SHIPPED','DELIVERED')
    GROUP BY DATE_FORMAT(order_date, '%Y-%m')
)
SELECT ym, revenue,
       SUM(revenue) OVER (ORDER BY ym) AS running_total,
       ROUND(100 * (revenue - LAG(revenue) OVER (ORDER BY ym))
             / NULLIF(LAG(revenue) OVER (ORDER BY ym), 0), 2) AS mom_pct
FROM m
ORDER BY ym;

-- Q42. Payment method share of successful payments
SELECT method, COUNT(*) AS payments, SUM(amount) AS amount,
       ROUND(100 * SUM(amount) / SUM(SUM(amount)) OVER (), 2) AS share_pct
FROM payments
WHERE payment_status = 'SUCCESS'
GROUP BY method
ORDER BY amount DESC;

-- Q43. Customer ranking inside each state
WITH s AS (
    SELECT c.customer_id, c.state, CONCAT(c.first_name,' ',c.last_name) AS customer, SUM(t.net_total) AS spend
    FROM customers c
    JOIN v_order_totals t ON t.customer_id = c.customer_id
    WHERE t.status IN ('PAID','SHIPPED','DELIVERED')
    GROUP BY c.customer_id, c.state, c.first_name, c.last_name
)
SELECT state, customer, spend,
       RANK() OVER (PARTITION BY state ORDER BY spend DESC) AS rank_in_state
FROM s
ORDER BY state, rank_in_state;

-- Q44. Order status funnel with share of all orders, and money lost to cancellations / returns
SELECT t.status, COUNT(*) AS orders, ROUND(SUM(t.net_total), 2) AS value,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_orders
FROM v_order_totals t
GROUP BY t.status
ORDER BY FIELD(t.status,'PLACED','PAID','SHIPPED','DELIVERED','CANCELLED','RETURNED');

-- =====================================================================
-- NOTES
--  * Row counts: categories 20, coupons 20, customers 24, products 30,
--                orders 32, order_items 65, payments 30, reviews 22.
--  * Intentional NULLs for the NULL-handling queries: customers.phone / gender / referred_by,
--    products.brand, orders.coupon_code / shipped_date / delivered_date,
--    payments.txn_ref (COD), reviews.review_text.
--  * Products 13 and 24 are never sold (Q11); customers 21-24 never ordered (Q19).
--  * PostgreSQL port: CONCAT works as is; replace DATE_FORMAT with TO_CHAR, DATEDIFF with
--    (date1 - date2), <=> with IS NOT DISTINCT FROM, FIELD() with a CASE expression,
--    and the FULL OUTER JOIN in Q35 with the native FULL OUTER JOIN.
-- =====================================================================

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
  rating           int,
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
  rating             int      NOT NULL,
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


delimiter &&

drop procedure if exists create_customer&&
create procedure create_customer(
  in p_username varchar(64),
  in p_password_hash varchar(255),
  in p_full_name varchar(255),
  in p_email varchar(255),
  in p_phone varchar(32),
  in p_address text
)
begin
  insert into Customers(username, password_hash, full_name, email, phone, address)
  values (p_username, p_password_hash, p_full_name, p_email, p_phone, p_address);
end&&

drop procedure if exists create_seller&&
create procedure create_seller(
  in p_username varchar(64),
  in p_password_hash varchar(255),
  in p_display_name varchar(255),
  in p_email varchar(255),
  in p_phone varchar(32),
  in p_address text
)
begin
  insert into Sellers(username, password_hash, display_name, email, phone, address)
  values (p_username, p_password_hash, p_display_name, p_email, p_phone, p_address);
end&&

drop procedure if exists add_product&&
create procedure add_product(
  in p_seller_username varchar(64),
  in p_name varchar(255),
  in p_price int unsigned,
  in p_quantity int unsigned,
  in p_description text
)
begin
  insert into Products(seller_username, name, rating, price, quantity, description)
  values (p_seller_username, p_name, null, p_price, p_quantity, p_description);
end&&

drop procedure if exists place_order&&
create procedure place_order(
  in p_customer_username varchar(64),
  in p_product_id int unsigned,
  in p_quantity int unsigned
)
begin
  declare v_stock int;

  select quantity into v_stock
  from Products
  where product_id = p_product_id
  for update;

  if v_stock is null then
    signal sqlstate '45000' set message_text = 'Product not found';
  elseif v_stock < p_quantity then
    signal sqlstate '45000' set message_text = 'Insufficient stock';
  else
    insert into Orders(product_id, customer_username, quantity)
    values (p_product_id, p_customer_username, p_quantity);

    update Products
    set quantity = quantity - p_quantity
    where product_id = p_product_id;
  end if;
end&&

drop procedure if exists clear_cart&&
create procedure clear_cart(
  in p_customer_username varchar(64)
)
begin
  delete from CartItems
  where customer_username = p_customer_username;
end&&

drop function if exists product_avg_rating&&
create function product_avg_rating(
  p_product_id int unsigned
)
returns decimal(3,2)
reads sql data
begin
  declare v_avg decimal(3,2);
  select ifnull(avg(rating),0) into v_avg
  from Reviews
  where product_id = p_product_id;
  return v_avg;
end&&

drop procedure if exists get_invoice&&
create procedure get_invoice(in p_user varchar(10))
begin
select p.name as product,o.quantity as quantity,p.price * o.quantity as price
from Products p,
Orders o
where o.customer_username = p_user
and o.product_id = p.product_id
union all
select 'TOTAL' as product,sum(o.quantity) as quantity, sum(p.price * o.quantity) as price
from Products p,
Orders o
where o.customer_username = p_user
and o.product_id = p.product_id;
end&&

drop function if exists customer_total_spent&&
create function customer_total_spent(
  p_customer_username varchar(64)
)
returns int
reads sql data
begin
  declare v_total int;
  select ifnull(sum(o.quantity * p.price),0) into v_total
  from Orders o
  join Products p on p.product_id = o.product_id
  where o.customer_username = p_customer_username;
  return v_total;
end&&

drop function if exists customer_order_count&&
create function customer_order_count(
  p_customer_username varchar(64)
)
returns int
reads sql data
begin
  declare v_cnt int;
  select count(*) into v_cnt
  from Orders
  where customer_username = p_customer_username;
  return v_cnt;
end&&

drop function if exists product_stock&&
create function product_stock(
  p_product_id int unsigned
)
returns int
reads sql data
begin
  declare v_stock int;
  select quantity into v_stock
  from Products
  where product_id = p_product_id;
  return ifnull(v_stock,0);
end&&

drop function if exists seller_total_revenue&&
create function seller_total_revenue(
  p_seller_username varchar(64)
)
returns int
reads sql data
begin
  declare v_total int;
  select ifnull(sum(o.quantity * p.price),0) into v_total
  from Orders o
  join Products p on p.product_id = o.product_id
  join Sellers s on s.username = p.seller_username
  where s.username = p_seller_username;
  return v_total;
end&&

drop trigger if exists reviews_before_insert_rating&&
create trigger reviews_before_insert_rating
before insert on Reviews
for each row
begin
  if new.rating < 1 or new.rating > 5 then
    signal sqlstate '45000' set message_text = 'Rating must be between 1 and 5';
  end if;
end&&

drop trigger if exists cartitems_before_insert_quantity&&
create trigger cartitems_before_insert_quantity
before insert on CartItems
for each row
begin
  if new.quantity <= 0 then
    signal sqlstate '45000' set message_text = 'Cart item quantity must be greater than 0';
  end if;
end&&

drop trigger if exists orders_before_insert_stock&&
create trigger orders_before_insert_stock
before insert on Orders
for each row
begin
  declare v_stock int;
  select quantity into v_stock
  from Products
  where product_id = new.product_id;

  if v_stock is null then
    signal sqlstate '45000' set message_text = 'Product not found for order';
  elseif v_stock < new.quantity then
    signal sqlstate '45000' set message_text = 'Insufficient stock for order';
  end if;
end&&

drop trigger if exists orders_after_insert_decrement_stock&&
create trigger orders_after_insert_decrement_stock
after insert on Orders
for each row
begin
  update Products
  set quantity = quantity - new.quantity
  where product_id = new.product_id;
end&&

drop trigger if exists products_after_update_price&&
create trigger products_after_update_price
after update on Products
for each row
begin
  if new.price <> old.price then
    insert into ProductPriceHistory(product_id, old_price, new_price)
    values (new.product_id, old.price, new.price);
  end if;
end&&

delimiter ;

create table if not exists ProductPriceHistory (
  id int unsigned not null auto_increment,
  product_id int unsigned not null,
  old_price int unsigned not null,
  new_price int unsigned not null,
  changed_at datetime not null default current_timestamp,
  primary key (id),
  foreign key (product_id) references Products(product_id) on delete cascade
);

-- =========================================================
-- DOCUMENTATION TABLE FOR PROCEDURES / FUNCTIONS / TRIGGERS
-- =========================================================

create table if not exists DbArtifacts (
  name         varchar(128) not null,
  type         varchar(16)  not null,
  description  text         not null,
  param_count  int          not null default 0,
  primary key (name, type),
  check (type in ('PROCEDURE','FUNCTION','TRIGGER')),
  check (param_count >= 0)
);

insert into DbArtifacts (name, type, description, param_count) values
-- procedures
('create_customer', 'PROCEDURE', 'creates a new customer row in the customers table', 6),
('create_seller',   'PROCEDURE', 'creates a new seller row in the sellers table',    6),
('add_product',     'PROCEDURE', 'adds a new product for a given seller',            5),
('place_order',     'PROCEDURE', 'places an order and decrements product stock',     3),
('clear_cart',      'PROCEDURE', 'removes all cart items for a specific customer',   1),
('get_invoice',     'PROCEDURE', 'returns all orders for a user with total amount',  1),

-- functions
('product_avg_rating',   'FUNCTION', 'returns the average rating for a product',     1),
('customer_total_spent', 'FUNCTION', 'returns total amount spent by a customer',     1),
('customer_order_count', 'FUNCTION', 'returns the number of orders for a customer',  1),
('product_stock',        'FUNCTION', 'returns current stock quantity for a product', 1),
('seller_total_revenue', 'FUNCTION', 'returns total revenue for a seller',           1),

-- triggers (always 0 params)
('reviews_before_insert_rating',        'TRIGGER', 'validates review ratings range on insert',    0),
('cartitems_before_insert_quantity',    'TRIGGER', 'ensures cart quantity is greater than zero', 0),
('orders_before_insert_stock',          'TRIGGER', 'checks stock before inserting an order',     0),
('orders_after_insert_decrement_stock', 'TRIGGER', 'decrements product stock after an order',    0),
('products_after_update_price',         'TRIGGER', 'logs product price changes',                 0);


delimiter &&

drop procedure if exists join_orders_products_inner&&
create procedure join_orders_products_inner(
  in p_customer_username varchar(64)
)
begin
  select o.product_id, p.name, o.quantity, p.price * o.quantity as total_price
  from Orders o
  join Products p on p.product_id = o.product_id
  where o.customer_username = p_customer_username;
end&&

drop procedure if exists join_products_reviews_left&&
create procedure join_products_reviews_left()
begin
  select p.product_id, p.name, r.customer_username, r.rating
  from Products p
  left join Reviews r on r.product_id = p.product_id;
end&&

drop procedure if exists join_sellers_products_right&&
create procedure join_sellers_products_right()
begin
  select s.username as seller_username, s.display_name, p.product_id, p.name
  from Products p
  right join Sellers s on p.seller_username = s.username;
end&&

drop procedure if exists join_products_reviews_full&&
create procedure join_products_reviews_full()
begin
  select p.product_id, p.name, r.customer_username, r.rating
  from Products p
  left join Reviews r on r.product_id = p.product_id
  union
  select p.product_id, p.name, r.customer_username, r.rating
  from Products p
  right join Reviews r on r.product_id = p.product_id;
end&&

drop procedure if exists join_customers_sellers_cross&&
create procedure join_customers_sellers_cross(
  in p_limit int
)
begin
  select c.username as customer_username, s.username as seller_username
  from Customers c
  cross join Sellers s
  limit p_limit;
end&&

drop procedure if exists ra_union_customers_orders_reviews&&
create procedure ra_union_customers_orders_reviews()
begin
  select distinct customer_username
  from Orders
  union
  select distinct customer_username
  from Reviews;
end&&

drop procedure if exists ra_intersection_customers_orders_reviews&&
create procedure ra_intersection_customers_orders_reviews()
begin
  select distinct o.customer_username
  from Orders o
  join Reviews r on r.customer_username = o.customer_username;
end&&

drop procedure if exists ra_difference_customers_orders_not_reviews&&
create procedure ra_difference_customers_orders_not_reviews()
begin
  select distinct o.customer_username
  from Orders o
  left join Reviews r on r.customer_username = o.customer_username
  where r.customer_username is null;
end&&

drop procedure if exists ra_division_loyal_customers&&
create procedure ra_division_loyal_customers(
  in p_seller_username varchar(64)
)
begin
  select c.username
  from Customers c
  where not exists (
    select 1
    from Products p
    where p.seller_username = p_seller_username
    and not exists (
      select 1
      from Orders o
      where o.customer_username = c.username
      and o.product_id = p.product_id
    )
  );
end&&

drop procedure if exists agg_orders_by_customer&&
create procedure agg_orders_by_customer(
  in p_customer_username varchar(64)
)
begin
  select
    p_customer_username as customer_username,
    count(*) as order_count,
    sum(o.quantity * p.price) as total_amount,
    avg(o.quantity * p.price) as avg_order_value,
    min(o.quantity * p.price) as min_order_value,
    max(o.quantity * p.price) as max_order_value
  from Orders o
  join Products p on p.product_id = o.product_id
  where o.customer_username = p_customer_username;
end&&

drop function if exists agg_total_orders_amount&&
create function agg_total_orders_amount(
  p_customer_username varchar(64)
)
returns int
begin
  declare v_total int;
  select ifnull(sum(o.quantity * p.price),0) into v_total
  from Orders o
  join Products p on p.product_id = o.product_id
  where o.customer_username = p_customer_username;
  return v_total;
end&&

drop function if exists agg_order_count&&
create function agg_order_count(
  p_customer_username varchar(64)
)
returns int
begin
  declare v_cnt int;
  select count(*) into v_cnt
  from Orders
  where customer_username = p_customer_username;
  return v_cnt;
end&&

drop function if exists agg_order_avg_value&&
create function agg_order_avg_value(
  p_customer_username varchar(64)
)
returns decimal(10,2)
begin
  declare v_avg decimal(10,2);
  select ifnull(avg(o.quantity * p.price),0) into v_avg
  from Orders o
  join Products p on p.product_id = o.product_id
  where o.customer_username = p_customer_username;
  return v_avg;
end&&

drop function if exists agg_order_min_value&&
create function agg_order_min_value(
  p_customer_username varchar(64)
)
returns int
begin
  declare v_min int;
  select ifnull(min(o.quantity * p.price),0) into v_min
  from Orders o
  join Products p on p.product_id = o.product_id
  where o.customer_username = p_customer_username;
  return v_min;
end&&

drop function if exists agg_order_max_value&&
create function agg_order_max_value(
  p_customer_username varchar(64)
)
returns int
begin
  declare v_max int;
  select ifnull(max(o.quantity * p.price),0) into v_max
  from Orders o
  join Products p on p.product_id = o.product_id
  where o.customer_username = p_customer_username;
  return v_max;
end&&

drop function if exists ra_has_bought_all_from_seller&&
create function ra_has_bought_all_from_seller(
  p_customer_username varchar(64),
  p_seller_username varchar(64)
)
returns int
begin
  declare v_missing int;
  select count(*) into v_missing
  from Products p
  where p.seller_username = p_seller_username
  and not exists (
    select 1
    from Orders o
    where o.customer_username = p_customer_username
    and o.product_id = p.product_id
  );
  if v_missing = 0 then
    return 1;
  else
    return 0;
  end if;
end&&

drop trigger if exists reviews_after_insert_update_product_rating&&
create trigger reviews_after_insert_update_product_rating
after insert on Reviews
for each row
begin
  update Products p
  set p.rating = (
    select round(avg(r.rating))
    from Reviews r
    where r.product_id = new.product_id
  )
  where p.product_id = new.product_id;
end&&

delimiter ;

insert into DbArtifacts(name, type, description, param_count) values
('join_orders_products_inner','PROCEDURE','shows inner join between orders and products for one customer',1),
('join_products_reviews_left','PROCEDURE','shows left join of products with their reviews',0),
('join_sellers_products_right','PROCEDURE','shows right join of sellers with their products',0),
('join_products_reviews_full','PROCEDURE','shows full join of products and reviews using union of left and right',0),
('join_customers_sellers_cross','PROCEDURE','shows cross join of customers and sellers with a limit',1),
('ra_union_customers_orders_reviews','PROCEDURE','shows union of customers who ordered or reviewed',0),
('ra_intersection_customers_orders_reviews','PROCEDURE','shows customers who both ordered and reviewed',0),
('ra_difference_customers_orders_not_reviews','PROCEDURE','shows customers who ordered but never reviewed',0),
('ra_division_loyal_customers','PROCEDURE','shows customers who bought all products from one seller',1),
('agg_orders_by_customer','PROCEDURE','shows all aggregate order stats for one customer',1),
('agg_total_orders_amount','FUNCTION','returns total order amount for one customer',1),
('agg_order_count','FUNCTION','returns number of orders for one customer',1),
('agg_order_avg_value','FUNCTION','returns average order value for one customer',1),
('agg_order_min_value','FUNCTION','returns minimum order value for one customer',1),
('agg_order_max_value','FUNCTION','returns maximum order value for one customer',1),
('ra_has_bought_all_from_seller','FUNCTION','returns 1 if a customer bought all products from a seller',2),
('reviews_after_insert_update_product_rating','TRIGGER','updates product rating after a review insert using avg aggregation',0);

INSERT INTO Customers (username, password_hash, full_name, email, phone, address) VALUES
('cust001', 'hash_cust001', 'Alice Johnson', '[alice.johnson01@example.com](mailto:alice.johnson01@example.com)', '+1-555-0001', '123 Maple Street, Springfield'),
('cust002', 'hash_cust002', 'Brian Smith', '[brian.smith02@example.com](mailto:brian.smith02@example.com)', '+1-555-0002', '45 Oak Avenue, Riverton'),
('cust003', 'hash_cust003', 'Caroline Baker', '[caroline.baker03@example.com](mailto:caroline.baker03@example.com)', '+1-555-0003', '78 Pine Road, Lakeview'),
('cust004', 'hash_cust004', 'Daniel Carter', '[daniel.carter04@example.com](mailto:daniel.carter04@example.com)', '+1-555-0004', '9 Cedar Lane, Brookfield'),
('cust005', 'hash_cust005', 'Emily Davis', '[emily.davis05@example.com](mailto:emily.davis05@example.com)', '+1-555-0005', '210 Birch Boulevard, Hillcrest'),
('cust006', 'hash_cust006', 'Frank Edwards', '[frank.edwards06@example.com](mailto:frank.edwards06@example.com)', '+1-555-0006', '15 Willow Street, Milltown'),
('cust007', 'hash_cust007', 'Grace Foster', '[grace.foster07@example.com](mailto:grace.foster07@example.com)', '+1-555-0007', '88 Cherry Court, Greenfield'),
('cust008', 'hash_cust008', 'Henry Garcia', '[henry.garcia08@example.com](mailto:henry.garcia08@example.com)', '+1-555-0008', '37 Elm Terrace, Lakeside'),
('cust009', 'hash_cust009', 'Isabella Hughes', '[isabella.hughes09@example.com](mailto:isabella.hughes09@example.com)', '+1-555-0009', '64 Walnut Drive, Fairview'),
('cust010', 'hash_cust010', 'Jack Irving', '[jack.irving10@example.com](mailto:jack.irving10@example.com)', '+1-555-0010', '502 Cypress Way, Riverbend'),
('cust011', 'hash_cust011', 'Karen Johnson', '[karen.johnson11@example.com](mailto:karen.johnson11@example.com)', '+1-555-0011', '19 Poplar Street, Clearwater'),
('cust012', 'hash_cust012', 'Liam King', '[liam.king12@example.com](mailto:liam.king12@example.com)', '+1-555-0012', '31 Dogwood Lane, Silverlake'),
('cust013', 'hash_cust013', 'Mia Lewis', '[mia.lewis13@example.com](mailto:mia.lewis13@example.com)', '+1-555-0013', '76 Spruce Avenue, Grandview'),
('cust014', 'hash_cust014', 'Noah Martinez', '[noah.martinez14@example.com](mailto:noah.martinez14@example.com)', '+1-555-0014', '5 Aspen Circle, Westfield'),
('cust015', 'hash_cust015', 'Olivia Nelson', '[olivia.nelson15@example.com](mailto:olivia.nelson15@example.com)', '+1-555-0015', '98 Sycamore Road, Bayside'),
('cust016', 'hash_cust016', 'Patrick Owens', '[patrick.owens16@example.com](mailto:patrick.owens16@example.com)', '+1-555-0016', '140 Linden Place, Kingsport'),
('cust017', 'hash_cust017', 'Quinn Peterson', '[quinn.peterson17@example.com](mailto:quinn.peterson17@example.com)', '+1-555-0017', '27 Magnolia Street, Rosewood'),
('cust018', 'hash_cust018', 'Rachel Quinn', '[rachel.quinn18@example.com](mailto:rachel.quinn18@example.com)', '+1-555-0018', '63 Hawthorn Road, Edgewater'),
('cust019', 'hash_cust019', 'Samuel Reed', '[samuel.reed19@example.com](mailto:samuel.reed19@example.com)', '+1-555-0019', '81 Bayberry Court, Parkview'),
('cust020', 'hash_cust020', 'Taylor Scott', '[taylor.scott20@example.com](mailto:taylor.scott20@example.com)', '+1-555-0020', '7 Palm Avenue, Harborview'),
('cust021', 'hash_cust021', 'Uma Turner', '[uma.turner21@example.com](mailto:uma.turner21@example.com)', '+1-555-0021', '45 Clover Lane, Ridgewood'),
('cust022', 'hash_cust022', 'Victor Underwood', '[victor.underwood22@example.com](mailto:victor.underwood22@example.com)', '+1-555-0022', '230 Garden Street, Northlake'),
('cust023', 'hash_cust023', 'Wendy Vaughn', '[wendy.vaughn23@example.com](mailto:wendy.vaughn23@example.com)', '+1-555-0023', '12 Highland Road, Eastwood'),
('cust024', 'hash_cust024', 'Xavier Walker', '[xavier.walker24@example.com](mailto:xavier.walker24@example.com)', '+1-555-0024', '59 Summit Court, Clearbrook'),
('cust025', 'hash_cust025', 'Yara Xu', '[yara.xu25@example.com](mailto:yara.xu25@example.com)', '+1-555-0025', '402 River Street, Stonebridge'),
('cust026', 'hash_cust026', 'Zach Young', '[zach.young26@example.com](mailto:zach.young26@example.com)', '+1-555-0026', '88 Meadow Lane, Cedarview'),
('cust027', 'hash_cust027', 'Ava Carter', '[ava.carter27@example.com](mailto:ava.carter27@example.com)', '+1-555-0027', '17 Maple Court, Lakeshore'),
('cust028', 'hash_cust028', 'Blake Daniels', '[blake.daniels28@example.com](mailto:blake.daniels28@example.com)', '+1-555-0028', '305 Willow Avenue, Kingslake'),
('cust029', 'hash_cust029', 'Chloe Evans', '[chloe.evans29@example.com](mailto:chloe.evans29@example.com)', '+1-555-0029', '76 Oak Ridge, Brookstone'),
('cust030', 'hash_cust030', 'Dylan Flores', '[dylan.flores30@example.com](mailto:dylan.flores30@example.com)', '+1-555-0030', '9 Valley Road, Crestview'),
('cust031', 'hash_cust031', 'Ella Green', '[ella.green31@example.com](mailto:ella.green31@example.com)', '+1-555-0031', '422 Forest Drive, Maplewood'),
('cust032', 'hash_cust032', 'Felix Hall', '[felix.hall32@example.com](mailto:felix.hall32@example.com)', '+1-555-0032', '5 Riverbend Way, Willowbrook'),
('cust033', 'hash_cust033', 'Georgia Ives', '[georgia.ives33@example.com](mailto:georgia.ives33@example.com)', '+1-555-0033', '69 Parkside Lane, Sunnyvale'),
('cust034', 'hash_cust034', 'Harper James', '[harper.james34@example.com](mailto:harper.james34@example.com)', '+1-555-0034', '18 Sunrise Court, Hillview'),
('cust035', 'hash_cust035', 'Ian Keller', '[ian.keller35@example.com](mailto:ian.keller35@example.com)', '+1-555-0035', '390 Lake Road, Greystone'),
('cust036', 'hash_cust036', 'Jade Lawrence', '[jade.lawrence36@example.com](mailto:jade.lawrence36@example.com)', '+1-555-0036', '104 Brookside Avenue, Elmwood'),
('cust037', 'hash_cust037', 'Kyle Mitchell', '[kyle.mitchell37@example.com](mailto:kyle.mitchell37@example.com)', '+1-555-0037', '71 Garden Court, Fairmont'),
('cust038', 'hash_cust038', 'Lily Norton', '[lily.norton38@example.com](mailto:lily.norton38@example.com)', '+1-555-0038', '36 Crescent Drive, Oakfield'),
('cust039', 'hash_cust039', 'Mason Ortiz', '[mason.ortiz39@example.com](mailto:mason.ortiz39@example.com)', '+1-555-0039', '250 Hill Street, Riverview'),
('cust040', 'hash_cust040', 'Nora Pierce', '[nora.pierce40@example.com](mailto:nora.pierce40@example.com)', '+1-555-0040', '8 Ridge Avenue, Stonehill');

INSERT INTO Sellers (username, password_hash, display_name, email, phone, address) VALUES
('seller001', 'hash_seller001', 'TechNova Store', '[support@technova-store.com](mailto:support@technova-store.com)', '+1-555-1001', '101 Innovation Drive, Silicon City'),
('seller002', 'hash_seller002', 'GadgetGalaxy Online', '[sales@gadgetgalaxy.com](mailto:sales@gadgetgalaxy.com)', '+1-555-1002', '55 Orbit Avenue, Metroplex'),
('seller003', 'hash_seller003', 'PrimePeripherals', '[contact@primeperipherals.com](mailto:contact@primeperipherals.com)', '+1-555-1003', '900 Peripheral Road, Ridgeport'),
('seller004', 'hash_seller004', 'Urban Digitals', '[hello@urbandigitals.com](mailto:hello@urbandigitals.com)', '+1-555-1004', '42 Skyline Plaza, Downtown'),
('seller005', 'hash_seller005', 'NextGen Devices', '[service@nextgendevices.com](mailto:service@nextgendevices.com)', '+1-555-1005', '12 Future Park, Newtown'),
('seller006', 'hash_seller006', 'WorkFromHome Essentials', '[info@wfh-essentials.com](mailto:info@wfh-essentials.com)', '+1-555-1006', '77 Remote Lane, Cloudville'),
('seller007', 'hash_seller007', 'ProOffice Gear', '[support@proofficegear.com](mailto:support@proofficegear.com)', '+1-555-1007', '310 Business Park, Commerce City'),
('seller008', 'hash_seller008', 'PixelPeak Electronics', '[team@pixelpeak-electro.com](mailto:team@pixelpeak-electro.com)', '+1-555-1008', '24 Summit Tower, Highpoint'),
('seller009', 'hash_seller009', 'Everyday Tech Hub', '[care@everydaytechhub.com](mailto:care@everydaytechhub.com)', '+1-555-1009', '63 Main Market, Midtown'),
('seller010', 'hash_seller010', 'NovaConnect Store', '[contact@novaconnect.io](mailto:contact@novaconnect.io)', '+1-555-1010', '500 Network Boulevard, Gridtown'),
('seller011', 'hash_seller011', 'Elite Deskware', '[hello@elitedeskware.com](mailto:hello@elitedeskware.com)', '+1-555-1011', '83 Executive Way, Capital Heights'),
('seller012', 'hash_seller012', 'HomeOffice Warehouse', '[sales@homeoffice-warehouse.com](mailto:sales@homeoffice-warehouse.com)', '+1-555-1012', '12 Depot Street, Warehouse District'),
('seller013', 'hash_seller013', 'CloudEdge Retail', '[support@cloudedgeretail.com](mailto:support@cloudedgeretail.com)', '+1-555-1013', '222 Horizon Road, Vertex City'),
('seller014', 'hash_seller014', 'SmartChoice Electronics', '[help@smartchoice-electro.com](mailto:help@smartchoice-electro.com)', '+1-555-1014', '18 Choice Plaza, Central Park'),
('seller015', 'hash_seller015', 'ConnectIT Outlet', '[service@connectit-outlet.com](mailto:service@connectit-outlet.com)', '+1-555-1015', '79 Connector Avenue, Junction City');

INSERT INTO Products (product_id, seller_username, name, rating, price, quantity, description) VALUES
(1, 'seller001', 'Acer Mini Fold | 67 Keys Compact Foldable Bluetooth Keyboard | BT 5.0 | 180mAh Rechargeable Battery | USB-C Fast Charging | 76H Use | Lightweight 133g | Black | Compatible with Windows Mac Android', 4, 2999, 120, 'Ultra portable tri fold Bluetooth keyboard designed for commuters and students. Low profile scissor switch keys provide quiet typing while multi device pairing supports laptops tablets and phones. Durable matte black housing and integrated phone stand make it ideal for travel and remote work setups.'),
(2, 'seller001', 'Acer Mini Fold Pro | 67 Keys Compact Foldable Bluetooth Keyboard | BT 5.3 | Backlit Keys | 230mAh Battery | USB-C | 90H Use | Travel Pouch Included | Space Gray', 5, 3999, 80, 'Professional grade foldable Bluetooth keyboard with adjustable white backlight and reinforced aluminum alloy chassis. Pairs with three devices simultaneously and remembers last connection for seamless switching between laptop tablet and smartphone. Silent key design reduces fatigue during long writing sessions.'),
(3, 'seller002', 'LogiFlex TravelBoard | 64 Keys Ultra Slim Foldable Wireless Keyboard | BT 5.0 | Multi OS Support | Quiet Keys | Built in Phone Cradle | Dark Graphite', 4, 2799, 150, 'Compact wireless keyboard aimed at travelers who need laptop like typing on the go. Features quiet chiclet style keys and well spaced layout for accurate typing even in cramped environments. Includes built in phone cradle and automatic sleep mode to extend battery life.'),
(4, 'seller002', 'LogiFlex TravelBoard Plus | 64 Keys Ultra Slim Foldable Wireless Keyboard | BT 5.1 | Backlit | Aluminum Frame | 200mAh Battery | Graphite Gray', 5, 3599, 95, 'Premium version of the LogiFlex foldable keyboard with aluminum frame and adjustable three level backlight. Multi host capability lets you switch between office desktop and tablet with one key. Ideal for professionals and students attending online classes.'),
(5, 'seller003', 'KeyPro GoType | 60 Keys Pocket Size Bluetooth Keyboard | BT 5.0 | Rechargeable | Included Carry Case | Charcoal Black', 3, 2199, 140, 'Pocket sized keyboard focused on smartphone and tablet users. Lightweight design fits easily into small bags. Island style keys deliver surprisingly comfortable typing for quick emails chats and note taking. Includes matching zipper carry case for protection.'),
(6, 'seller003', 'KeyPro GoType XL | 78 Keys Foldable Bluetooth Keyboard with Number Row | BT 5.2 | 250mAh Battery | USB-C | Dark Slate', 4, 3299, 110, 'Extended foldable keyboard with full function row and dedicated media keys. Meant for users who want near laptop typing in a compact package. Robust metal hinge ensures long term durability while soft touch coating improves grip.'),
(7, 'seller004', 'SkyBoard AirFold | 65 Keys Lightweight Foldable Bluetooth Keyboard | BT 5.0 | Quiet Keys | Up to 70H Battery | Silver', 4, 2899, 130, 'Minimalist foldable keyboard with thin profile optimized for tablet stands and portable monitors. Soft quiet keys and anti slip rubber feet ensure stable typing even on smooth surfaces. Auto reconnect feature saves time when switching between meetings.'),
(8, 'seller004', 'SkyBoard AirFold RGB | 65 Keys Foldable Bluetooth Keyboard | BT 5.1 | RGB Edge Lighting | 220mAh Battery | Silver White', 5, 4199, 60, 'Stylish foldable keyboard featuring subtle RGB edge lighting with breathing and static modes. Ideal for users who want visual flair without sacrificing portability. Supports both Bluetooth and wired USB-C modes for versatility.'),
(9, 'seller005', 'NovaType FlexKeys | 68 Keys Foldable Wireless Keyboard | BT 5.0 | Touchpad | Compact Layout | Black', 4, 3499, 90, 'Foldable keyboard with integrated multi touch trackpad for full control without external mouse. Tailored for smart TV and tablet users who want laptop like navigation. Precision touch support for scroll pinch and gesture navigation in supported operating systems.'),
(10, 'seller005', 'NovaType FlexKeys Pro | 68 Keys Foldable Wireless Keyboard with Large Trackpad | BT 5.2 | Multi Device | Gunmetal', 5, 4499, 75, 'Upgraded FlexKeys model with enlarged glass like trackpad surface and three device pairing. Designed for digital nomads and business travelers who frequently switch between tablets phones and laptops. Reinforced hinge rated for thousands of folds.'),
(11, 'seller006', 'WorkMate QuietTouch | Full Size Wireless Keyboard and Mouse Combo | 2.4GHz USB Receiver | Spill Resistant | Black', 4, 2599, 200, 'Desk friendly keyboard and mouse combo aimed at home office workers. Full size layout with number pad and low profile keys for comfortable extended typing. Silent click mouse with adjustable DPI works smoothly on most surfaces and shares a single nano receiver.'),
(12, 'seller006', 'WorkMate QuietTouch Plus | Full Size Wireless Keyboard and Mouse Combo | 2.4GHz | Palm Rest | Long Life Batteries | Black', 5, 3099, 160, 'Enhanced office combo including soft detachable palm rest and dedicated shortcut keys for media and calculator. Optimized for corporate environments with reliable 2.4GHz wireless connection and up to two years of battery life on common AA and AAA cells.'),
(13, 'seller007', 'ProClick ErgoMouse | Wireless Vertical Mouse | 2.4GHz and BT 5.0 | Adjustable DPI 800 2400 | Ergonomic Grip | Black', 4, 2499, 140, 'Ergonomic vertical mouse designed to reduce wrist strain during long computer sessions. Features textured rubber grip, forward and back buttons, and DPI button for quick sensitivity change. Can connect via Bluetooth or included USB receiver.'),
(14, 'seller007', 'ProClick ErgoMouse Plus | Rechargeable Wireless Vertical Mouse | BT 5.1 | Silent Buttons | USB-C Charging | Dark Gray', 5, 2999, 120, 'Rechargeable variant of ErgoMouse with silent main buttons ideal for shared offices and late night work. USB-C charging provides quick top ups while dual connectivity keeps it versatile across laptops and tablets.'),
(15, 'seller008', 'PixelMove SlimMouse | Ultra Thin Wireless Mouse | 2.4GHz | Silent Clicks | Travel Pouch | Silver', 3, 1799, 180, 'Ultra slim wireless mouse built for laptop bags and tablet sleeves. Silent buttons and smooth scroll wheel deliver distraction free navigation in classrooms and libraries. Includes travel pouch and auto sleep to preserve battery.'),
(16, 'seller008', 'PixelMove SlimMouse Dual | Ultra Thin Wireless Mouse | 2.4GHz and BT | Rechargeable | Silver White', 4, 2299, 150, 'Dual mode version of PixelMove SlimMouse with both Bluetooth and USB receiver options. Ideal for users juggling between work and personal devices. Rechargeable internal battery eliminates disposable cells.'),
(17, 'seller009', 'EverydayCharge 30W | USB C Fast Charger | Single Port PD 3.0 | Compact Wall Adapter | White', 4, 1499, 220, 'Compact 30 watt USB C charger suitable for phones tablets and smaller laptops that support Power Delivery. Foldable plug makes it travel friendly while intelligent charging ensures safe power delivery without overheating.'),
(18, 'seller009', 'EverydayCharge 45W Duo | USB C and USB A Fast Charger | PD 3.0 and QC 3.0 | Compact | White', 5, 1899, 210, 'Versatile wall charger with both USB C and USB A ports so you can charge legacy devices alongside newer phones and tablets. Supports multiple fast charging protocols and features built in protection against overcurrent and short circuits.'),
(19, 'seller010', 'NovaConnect PowerCube 65W | USB C GaN Fast Charger | 2x USB C 1x USB A | Foldable Plug | White', 5, 2999, 160, 'High efficiency GaN charger capable of powering ultrabooks tablets and phones from a single compact brick. Two USB C ports with intelligent power distribution automatically adjust to connected devices while the USB A port supports legacy fast charging.'),
(20, 'seller010', 'NovaConnect PowerCube 100W | USB C GaN Fast Charger | 3x USB C 1x USB A | Laptop Compatible | Travel Ready', 5, 3999, 90, 'Heavy duty GaN charger aimed at power users carrying multiple USB C laptops and tablets. Supports up to 100 watt output through primary USB C port while dynamically sharing power when additional ports are used. Includes travel friendly interchangeable plug pins.'),
(21, 'seller011', 'EliteDesk ComfortPad | Memory Foam Keyboard Wrist Rest | Non Slip Base | Black', 4, 999, 140, 'Soft memory foam wrist pad designed to support neutral wrist posture during long typing sessions. Smooth fabric surface feels gentle on skin while rubber underside prevents sliding on desks and glass tables.'),
(22, 'seller011', 'EliteDesk ComfortPad XL | Extended Keyboard and Mouse Wrist Rest Set | Black', 5, 1499, 110, 'Extended wrist rest set covering both keyboard and mouse area for complete desk comfort. Ideal for programmers writers and gamers who spend hours at their workstation. Easy to clean surface resists spills and everyday wear.'),
(23, 'seller012', 'HomeOffice DualRise | Adjustable Laptop Stand | Aluminum | 11 to 17 Inch Laptops | Silver', 4, 2499, 130, 'Sturdy aluminum laptop stand with multiple height adjustments for ergonomic eye level viewing. Open design improves airflow and helps laptops run cooler during heavy workloads. Rubber pads protect devices from scratches.'),
(24, 'seller012', 'HomeOffice DualRise Fold | Foldable Aluminum Laptop Stand | Height and Angle Adjustable | Carry Pouch | Silver', 5, 2699, 120, 'Foldable version of DualRise stand that collapses flat into included pouch for commuting and travel. Multiple angle settings support typing drawing and viewing modes for a range of workflows.'),
(25, 'seller013', 'CloudEdge ZoomCam 1080 | Full HD USB Webcam | 1080p 30fps | Built in Dual Mics | Privacy Cover | Black', 4, 3299, 140, 'Full HD webcam suited for remote meetings online classes and streaming. Delivers crisp 1080p image with automatic low light correction. Integrated privacy cover helps maintain security when camera is not in use.'),
(26, 'seller013', 'CloudEdge ZoomCam 1080 Pro | Full HD USB Webcam | 1080p 60fps | Wide 90 Degree Field | Tripod Mount | Black', 5, 3799, 100, 'Enhanced webcam with smoother 60fps video and wider field of view for conference rooms and collaborative workspaces. Standard tripod thread and included clip make placement flexible on monitors or stands.'),
(27, 'seller014', 'SmartChoice FocusCam 2K | QHD USB Webcam | 1440p 30fps | Auto Focus | Dual Noise Cancel Mics | Black', 5, 4499, 90, 'High resolution 2K webcam providing sharper detail for content creators trainers and professionals who want clearer visuals. Auto focus quickly adjusts when you move closer or hold objects in front of the lens.'),
(28, 'seller014', 'SmartChoice FocusCam 2K Lite | QHD USB Webcam | 1440p 30fps | Fixed Focus | Privacy Shutter | Black', 4, 3799, 110, 'Simplified 2K webcam with fixed focus lens tuned for typical desktop distance and built in privacy shutter. Good choice for users who want upgraded clarity without advanced configuration.'),
(29, 'seller015', 'ConnectIT StreamMic USB | Desktop USB Microphone | Cardioid Pattern | Mute Button | Headphone Monitoring | Black', 4, 2999, 130, 'USB microphone geared toward podcasters and remote workers who need clearer voice capture than laptop mics. Features tactile mute button with LED indicator and built in headphone jack for real time monitoring.'),
(30, 'seller015', 'ConnectIT StreamMic USB Pro | Desktop USB Microphone | Gain Control | Pop Filter | Adjustable Arm Stand | Black', 5, 3999, 80, 'Professional style USB microphone kit including adjustable boom arm and removable pop filter. Cardioid pickup pattern reduces background noise while gain knob and monitoring jack give finer control over recordings.');

INSERT INTO Products (product_id, seller_username, name, rating, price, quantity, description) VALUES
(31, 'seller001', 'Acer QuietWave | Wireless Over Ear Headphones | BT 5.0 | 40mm Drivers | 25H Battery | Foldable | Black', 4, 3499, 150, 'Comfortable over ear Bluetooth headphones with padded ear cups and adjustable headband. Tuned for balanced sound suitable for music calls and movies. Foldable design makes storage simple in backpacks and desk drawers.'),
(32, 'seller001', 'Acer QuietWave ANC | Wireless Over Ear Headphones | BT 5.1 | Active Noise Canceling | 30H Battery | Fast Charge | Black', 5, 4999, 100, 'Noise canceling variant of QuietWave built for commuters and open offices. Hybrid ANC reduces constant background hum while transparency mode lets in important ambient sound when needed. Fast charging provides several hours of playback from short top ups.'),
(33, 'seller002', 'LogiSound Everyday | On Ear Wireless Headphones | BT 5.0 | Lightweight 160g | 20H Playtime | Blue', 4, 2699, 160, 'On ear wireless headphones designed for everyday commuting and studying. Lightweight frame and soft cushions minimize pressure over long listening sessions. Simple side button controls manage playback and calls.'),
(34, 'seller002', 'LogiSound BassBoost | Over Ear Wireless Headphones | BT 5.0 | Extra Bass | 30H Battery | Black Red', 4, 3299, 140, 'Bass focused over ear headphones for music lovers who enjoy punchy low end. Extended battery supports long travel days and marathon playlists. Foldable arms and swivel cups make it easy to pack.'),
(35, 'seller003', 'KeyPro StudioPods | True Wireless Earbuds | BT 5.1 | 24H Total Playtime | Touch Controls | USB C | White', 4, 2999, 200, 'Compact true wireless earbuds with snug fit tips and touch controls for play pause and assistant access. Charging case provides multiple recharges for all day listening. Ideal for gym commutes and light calls.'),
(36, 'seller003', 'KeyPro StudioPods ANC | True Wireless Earbuds | BT 5.2 | Active Noise Canceling | Wireless Charging Case | Black', 5, 4499, 120, 'Premium earbuds with hybrid ANC and ambient mode designed for noisy commutes and open workspaces. Wireless charging case supports drop and charge on most Qi pads.'),
(37, 'seller004', 'SkyBoard WorkHub 6 in 1 | USB C Hub | 4K HDMI | 3x USB 3.0 | SD MicroSD | Aluminum Gray', 4, 2599, 180, 'Slim USB C hub that expands laptop connectivity with HDMI, multiple USB ports and card readers. Supports up to 4K 30Hz displays, making it useful for presentations and external monitors.'),
(38, 'seller004', 'SkyBoard WorkHub 9 in 1 | USB C Multiport Adapter | 4K HDMI | VGA | Ethernet | 3x USB | SD MicroSD | PD 100W', 5, 3599, 120, 'Comprehensive USB C hub suitable for docking thin laptops at home or office. Includes wired Ethernet for stable connections and supports pass through charging up to 100W to keep devices powered.'),
(39, 'seller005', 'NovaType DataLink | USB C to USB A 3.1 Cable | 1m | 5Gbps | 3A Charging | Braided Black', 4, 699, 300, 'Durable braided USB C to USB A cable rated for fast charging and quick data transfers. Reinforced stress relief and bend tested connectors extend lifespan for daily plugging.'),
(40, 'seller005', 'NovaType DataLink Plus | USB C to USB C 3.2 Cable | 2m | 10Gbps | 60W PD | Braided Gray', 5, 1199, 260, 'High speed USB C to C cable suitable for modern phones tablets and laptops. Supports fast data sync and up to 60W charging making it a versatile staple cable at home or office.'),
(41, 'seller006', 'WorkMate DualScreen Stand | Dual Monitor Stand | Fits 13 to 27 Inch Monitors | Height Adjustable | Black', 4, 3799, 80, 'Dual monitor stand for clean efficient workspaces. Adjustable arms accommodate most office displays and rotate for portrait or landscape. Integrated cable management keeps wires tidy.'),
(42, 'seller006', 'WorkMate SingleScreen Arm | Gas Spring Monitor Arm | 17 to 32 Inch | Clamp and Grommet | Black', 5, 3399, 90, 'Gas spring monitor arm that allows smooth height and tilt adjustments with a light touch. Suitable for ergonomic sit stand configurations at home or corporate desks.'),
(43, 'seller007', 'ProClick OfficeMat | Extended Desk Mat | 900 x 400mm | Water Resistant | Dark Gray', 4, 1299, 170, 'Extended desk mat that fits keyboard mouse and accessories while protecting desk surface. Smooth fabric offers consistent mouse tracking and easy wiping of spills.'),
(44, 'seller007', 'ProClick OfficeMat Classic | 800 x 300mm Desk Mat | Anti Fray Edges | Black', 4, 999, 190, 'Standard sized desk mat for compact workstations and gaming desks. Anti fray stitched edges resist wear from daily use and re positioning.'),
(45, 'seller008', 'PixelPeak SlimDock | Vertical Laptop Stand | Adjustable Width | Aluminum | Space Gray', 4, 2199, 110, 'Vertical stand designed to hold closed laptops beside monitors, freeing valuable desk space. Adjustable clamps support thin ultrabooks and thicker gaming laptops securely.'),
(46, 'seller008', 'PixelPeak SlimDock Duo | Dual Vertical Laptop Stand | Aluminum | Space Gray', 5, 2899, 90, 'Dual slot version of SlimDock that holds two laptops or a laptop plus tablet in vertical orientation. Ideal for dual system creators and IT admins.'),
(47, 'seller009', 'EverydayCharge PowerStrip 4 | 4 AC Sockets | 3 USB Ports | 2m Cord | Overload Protection | White', 4, 1999, 140, 'Compact power strip combining AC outlets and USB charging in one unit. Integrated surge and overload protection safeguards connected devices while LED indicator shows power status.'),
(48, 'seller009', 'EverydayCharge PowerStrip Tower | 8 AC Sockets | 4 USB Ports | 2m Cord | Overload Switch | White Gray', 5, 2799, 90, 'Vertical tower style extension board for crowded computer and entertainment setups. Rotating layout allows large plugs and adapters without blocking other outlets.'),
(49, 'seller010', 'NovaConnect MeshWiFi Mini | AC1200 Dual Band Mesh Router | Covers Up to 90m2 | App Control | White', 4, 3999, 75, 'Entry level mesh WiFi node designed for small apartments and home offices. Provides consistent dual band coverage and simple setup via mobile app with guided instructions.'),
(50, 'seller010', 'NovaConnect MeshWiFi Pro | AX1800 WiFi 6 Mesh Router | Covers Up to 150m2 | OFDMA | App Management | White', 5, 6999, 60, 'WiFi 6 mesh unit engineered for modern homes full of smart devices. Supports more simultaneous connections with lower latency and efficient bandwidth scheduling.'),
(51, 'seller011', 'EliteDesk CableTray | Under Desk Cable Management Tray | Steel | Black', 4, 1599, 120, 'Simple under desk tray that holds power strips and cables off the floor for a cleaner look and safer workspace. Steel construction supports multiple adapters and bricks.'),
(52, 'seller011', 'EliteDesk CableChannel Kit | 6 Piece Adhesive Cable Raceway | Paintable | White', 4, 1299, 130, 'Adhesive raceway channels that hide monitor and laptop cables along walls and desk edges. Paintable surface blends with decor in home offices and conference rooms.'),
(53, 'seller012', 'HomeOffice FootRest Comfort | Adjustable Under Desk Footrest | Textured Surface | Black', 4, 1899, 110, 'Ergonomic footrest that helps maintain healthy leg posture while seated. Adjustable tilt lets users rock gently to promote circulation during long sessions.'),
(54, 'seller012', 'HomeOffice FootRest Memory | Memory Foam Under Desk Foot Cushion | Removable Cover | Gray', 5, 1799, 100, 'Soft memory foam foot cushion that doubles as leg riser on sofas and recliners. Washable outer cover makes maintenance easy for busy households.'),
(55, 'seller013', 'CloudEdge RingLight 10 | 10 Inch LED Ring Light | 3 Color Modes | Tripod Stand | Phone Holder', 4, 2199, 140, 'Compact ring light kit tailored for video calls content recording and product photography. Adjustable brightness and color temperature help you match ambient lighting in any room.'),
(56, 'seller013', 'CloudEdge RingLight 12 Pro | 12 Inch LED Ring Light | Remote Control | Tall Tripod | Phone Clamp', 5, 2799, 100, 'Larger ring light with extended tripod height for standing full body shots and whiteboard videos. Included remote enables quick adjustments during live sessions.'),
(57, 'seller014', 'SmartChoice LapDesk Air | Portable Laptop Lap Desk | Ventilation | Mouse Pad Area | Gray', 4, 1999, 150, 'Portable lap desk that provides stable base and cooling vents for laptops when working from sofa or bed. Built in mouse area serves right or left handed users.'),
(58, 'seller014', 'SmartChoice LapDesk Cushion | Padded Lap Desk | Plush Bottom Cushion | Phone Slot | Wood Top', 4, 2299, 130, 'Lap desk with pillowy bottom cushion and sturdy wood top offering comfortable support for laptops and notebooks. Integrated groove holds phone upright beside work area.'),
(59, 'seller015', 'ConnectIT USB Audio Hub | 4 Port USB 3.0 Hub with Audio Jack | Aluminum | Blue LED', 4, 1699, 160, 'Compact USB hub adding four fast USB ports and a convenient headphone jack to desktops and laptops. Ideal for plugging in microphones webcams and storage drives.'),
(60, 'seller015', 'ConnectIT USB C Hub Slim | 5 in 1 USB C Hub | 2x USB 3.0 | HDMI | SD | MicroSD | Gray', 5, 2499, 140, 'Slim profile hub for modern USB C notebooks which frequently ship with limited ports. Ideal companion for presentations and photographers needing quick card access.');

INSERT INTO Products (product_id, seller_username, name, rating, price, quantity, description) VALUES
(61, 'seller001', 'Acer Mini Fold Business | 67 Keys Foldable Bluetooth Keyboard | BT 5.2 | Silent Office Keys | Dark Gray', 5, 3499, 90, 'Business focused variant of Acer Mini Fold tuned for quiet office use. Low noise key switches and subtle dark gray finish help it blend into professional environments.'),
(62, 'seller002', 'LogiFlex TravelBoard Student | 64 Keys Foldable Keyboard | BT 5.0 | Color Accent Keys | Blue Gray', 4, 2599, 130, 'Student centric foldable keyboard with colorful accent keys for frequently used shortcuts. Durable hinge and spill resistant key bed suit campus life and coffee shop work.'),
(63, 'seller003', 'KeyPro GoType Kids | 60 Keys Compact Bluetooth Keyboard | BT 5.0 | Colorful Keycaps | Spill Resistant', 4, 2399, 140, 'Educational keyboard designed for kids and young learners. Features rounded keycaps simple layout and spill resistance for everyday accidents during homework sessions.'),
(64, 'seller004', 'SkyBoard AirFold Business | 65 Keys Foldable Keyboard | BT 5.1 | Soft Touch Coating | Dark Blue', 4, 3099, 110, 'Business version of AirFold with refined soft touch finish and discrete function icons. Great for consultants and managers who travel with tablets instead of laptops.'),
(65, 'seller005', 'NovaType FlexKeys Office | 68 Keys Keyboard with Trackpad | BT 5.2 | Silent Keys | Space Gray', 5, 4699, 70, 'Office optimized FlexKeys model with silent switches and enlarged arrow cluster. Supports simultaneous connection to desktop laptop and tablet for multi screen workflows.'),
(66, 'seller006', 'WorkMate QuietTouch Basic | Wireless Keyboard | 2.4GHz | Tenkeyless | Black', 4, 1999, 180, 'Tenkeyless wireless keyboard for compact desks where space is at a premium. Shares design cues with QuietTouch combo but omits number pad to free mouse room.'),
(67, 'seller007', 'ProClick ErgoMouse Compact | Small Vertical Mouse | BT 5.0 | 2.4GHz | For Small Hands | Black', 4, 2399, 100, 'Compact variant of ErgoMouse designed for users with smaller hands. Maintains vertical design while reducing footprint, suitable for laptop bags and narrow desks.'),
(68, 'seller008', 'PixelMove SlimMouse Color | Ultra Thin Wireless Mouse | 2.4GHz | Silent | Rose Gold', 4, 1899, 130, 'Colorful edition of SlimMouse aimed at users who want style with function. Rose gold finish pairs nicely with modern rose and gold laptops and tablets.'),
(69, 'seller009', 'EverydayCharge 20W Mini | USB C Fast Charger | Pocket Size | White', 4, 1199, 250, 'Small USB C wall adapter for phones and accessories that support fast charging. Lightweight build makes it an easy everyday carry in handbag or backpack.'),
(70, 'seller010', 'NovaConnect PowerCube 30W Duo | 2x USB C PD Wall Charger | Compact | White', 5, 2499, 170, 'Dual USB C charger designed for couples or users with multiple phones and earbuds. Intelligent controller ensures safe delivery to each connected device.'),
(71, 'seller011', 'EliteDesk ComfortPad Color | Memory Foam Wrist Rest | Navy Blue', 4, 1099, 120, 'Color variant of ComfortPad with deep navy blue fabric for modern office looks. Same supportive memory foam core encourages neutral wrist alignment.'),
(72, 'seller012', 'HomeOffice DualRise Black | Adjustable Laptop Stand | Matte Black', 4, 2599, 100, 'Matte black finish version of DualRise laptop stand blending with dark peripherals and gaming setups. Provides ergonomic lift and enhanced cooling.'),
(73, 'seller013', 'CloudEdge ZoomCam 720 | HD USB Webcam | 720p 30fps | Built in Mic | Clip Mount | Black', 3, 2199, 150, 'Entry level webcam for basic video calling and online learning. Lightweight clip easily grips laptop lids and thin monitors, delivering clear picture in decent light.'),
(74, 'seller014', 'SmartChoice FocusCam 1080 | Full HD Webcam | 1080p 30fps | Auto Focus | Privacy Cover', 4, 2999, 130, 'Full HD webcam positioned between budget and 2K lines, good for users who need reliable clarity without premium pricing.'),
(75, 'seller015', 'ConnectIT StreamMic Mini | Compact USB Microphone | Mute Button | Tripod Stand | Black', 4, 2499, 140, 'Compact microphone suited for portable podcasting and impromptu voiceovers. Tripod stand allows quick setup on any desk or table.'),
(76, 'seller001', 'Acer QuietWave Lite | Wireless On Ear Headphones | BT 5.0 | 18H Battery | Blue', 4, 2399, 160, 'Lightweight on ear headphones with comfortable cushions and reliable Bluetooth link. Made for students and commuters who want branded audio on a budget.'),
(77, 'seller002', 'LogiSound Everyday Kids | Volume Limited On Ear Headphones | 85dB Safe Listening | Blue Green', 4, 1999, 120, 'Child friendly headphones with built in volume limiter to protect hearing. Bright colors and tangle resistant flat cable make them parent approved.'),
(78, 'seller003', 'KeyPro StudioPods Sport | True Wireless Earbuds | Ear Hooks | IPX5 Sweat Resistant | Black', 4, 3299, 130, 'Sport targeted earbuds with secure ear hook design and sweat resistance. Ideal for runners and gym goers who need stable fit and energetic sound.'),
(79, 'seller004', 'SkyBoard WorkHub Slim | USB C Hub | 2x USB 3.0 | HDMI | USB C PD | Gray', 4, 2399, 170, 'Slim travel hub focused on giving laptops HDMI output while passing through power and offering two USB ports for essentials.'),
(80, 'seller005', 'NovaType DataLink Ultra | USB C to USB C Cable | 1m | 100W PD | 4K Video Support | Black', 5, 1599, 190, 'High performance cable supporting up to 100 watt charging and 4K video output, perfect for docking and power hungry laptops.');

INSERT INTO Products (product_id, seller_username, name, rating, price, quantity, description) VALUES
(81, 'seller006', 'WorkMate SingleScreen Arm Silver | Gas Spring Monitor Arm | 17 to 32 Inch | Silver', 5, 3499, 80, 'Silver variant of WorkMate arm matching light monitors and clean Scandinavian style desks. Provides same smooth adjustment range for ergonomic setups.'),
(82, 'seller007', 'ProClick OfficeMat Pattern | 900 x 400mm Desk Mat | Geometric Pattern | Dark', 4, 1399, 140, 'Desk mat with subtle geometric print that adds personality while remaining office appropriate. Serves as comfortable surface for writing and mouse control.'),
(83, 'seller008', 'PixelPeak SlimDock Black | Vertical Laptop Stand | Aluminum | Matte Black', 4, 2299, 100, 'Matte black SlimDock option for users who prefer stealthy aesthetics to match black monitors and keyboards.'),
(84, 'seller009', 'EverydayCharge PowerStrip 6 USB | 3 AC Sockets | 6 USB Ports | 1.8m Cord | White', 4, 2299, 120, 'Power strip focused on USB charging for families with multiple phones tablets and wearables. Compact footprint suits bedside tables and charging counters.'),
(85, 'seller010', 'NovaConnect MeshWiFi Wall | AC1300 Wall Plug Mesh Node | Compact | White', 4, 3599, 70, 'Wall plug mesh node that extends WiFi coverage without needing shelf space. Ideal for hallways staircases and rental homes.'),
(86, 'seller011', 'EliteDesk CableTray Large | Wide Under Desk Cable Management Tray | Black', 4, 1899, 90, 'Wider version of CableTray accommodating large surge protectors and power bricks for multi monitor settings.'),
(87, 'seller012', 'HomeOffice FootRest Rocker | Under Desk Rocking Footrest | Adjustable Height | Black', 4, 1999, 80, 'Footrest with rocking mechanism that encourages micro movement and helps reduce stiffness during long seated tasks.'),
(88, 'seller013', 'CloudEdge RingLight Desk | Clamp On LED Ring Light | Flexible Arm | USB Powered', 4, 2399, 100, 'Clamp mounted ring light that attaches to monitors and desk edges, freeing up workspace while providing flattering front light.'),
(89, 'seller014', 'SmartChoice LapDesk Student | Lightweight Lap Desk | Storage Pocket | Gray', 4, 1899, 120, 'Student oriented lap desk with side pocket for pens notepads and small accessories, ideal for dorm rooms and shared spaces.'),
(90, 'seller015', 'ConnectIT USB C Hub Pro | 8 in 1 USB C Hub | 4K HDMI | Ethernet | 3x USB | SD MicroSD | Gray', 5, 2999, 100, 'Professional hub providing essential ports for conference rooms and hot desk setups, including wired network and card access.');

INSERT INTO Reviews (product_id, customer_username, rating, review) VALUES
(1, 'cust001', 4, 'Very compact keyboard and folds neatly into my backpack. Keys feel good for long emails.'),
(1, 'cust005', 5, 'Perfect travel companion for my tablet. Battery easily lasts a full week of meetings.'),
(1, 'cust010', 3, 'Portable and light but took a bit of time to get used to the smaller layout.'),
(2, 'cust002', 5, 'Backlit keys and solid build make this feel almost like a premium laptop keyboard.'),
(2, 'cust006', 5, 'Pairs quickly with my phone and laptop and switching devices is seamless.'),
(2, 'cust011', 4, 'Great for night work. The hinge feels sturdy though the case marks easily.'),
(3, 'cust003', 4, 'Nice low profile design. I use it on trains with my tablet and it works perfectly.'),
(3, 'cust007', 4, 'Phone cradle is surprisingly handy on video calls. Keys are quiet.'),
(3, 'cust012', 3, 'Good overall but wish the battery indicator was clearer.'),
(4, 'cust004', 5, 'Backlight and metal frame feel high end. Excellent for frequent travelers.'),
(4, 'cust008', 5, 'Switching between work laptop and personal tablet is effortless.'),
(4, 'cust013', 4, 'Typing is comfortable though the fold seam takes a day to ignore.'),
(5, 'cust001', 3, 'Very small keyboard. Great for quick notes but not for long reports.'),
(5, 'cust009', 4, 'Carry case is useful. Keys are responsive despite the compact size.'),
(5, 'cust014', 3, 'Works well but some keys feel a little close together.'),
(6, 'cust002', 4, 'Love having a full number row on a foldable keyboard. Build quality is solid.'),
(6, 'cust015', 5, 'My go to keyboard for hotel desks. Packs easily and feels like a normal board.'),
(6, 'cust016', 4, 'Keys are spaced nicely and the finish feels premium.'),
(7, 'cust003', 4, 'Super light and quiet. Perfect for working in libraries.'),
(7, 'cust017', 4, 'Auto reconnect is quick. Layout is familiar and easy to adapt to.'),
(7, 'cust018', 3, 'Good product though the silver finish shows fingerprints.'),
(8, 'cust004', 5, 'RGB edge lighting looks subtle but stylish. Great balance of aesthetics and function.'),
(8, 'cust019', 5, 'Backlight plus foldable design is exactly what I needed for late night writing.'),
(8, 'cust020', 4, 'Nice typing feel and lighting effects. Battery holds up well.'),
(9, 'cust005', 4, 'Trackpad works surprisingly well for navigating presentations.'),
(9, 'cust021', 4, 'Great all in one combo for my smart TV. Setup was instant.'),
(9, 'cust022', 3, 'Keyboard is fine but trackpad could be a bit larger.'),
(10, 'cust006', 5, 'Large smooth trackpad and silent keys make this perfect for remote work.'),
(10, 'cust023', 5, 'Three device pairing is fantastic when I jump between laptop phone and tablet.'),
(10, 'cust024', 4, 'Premium feel and very solid hinges. A bit heavier than basic models.'),
(11, 'cust007', 4, 'Comfortable keys and mouse. Great value for a home office setup.'),
(11, 'cust025', 4, 'Shared nano receiver keeps my USB ports free. No connection drops so far.'),
(11, 'cust026', 3, 'Works as advertised though keyboard tilt feet feel a bit flimsy.'),
(12, 'cust008', 5, 'Palm rest and quiet keys make long spreadsheets much easier.'),
(12, 'cust027', 5, 'Battery life is excellent and mouse feels precise.'),
(12, 'cust028', 4, 'Nice combo though the keyboard is slightly large for my narrow desk.'),
(13, 'cust009', 4, 'Vertical shape really helped my wrist pain after a few days.'),
(13, 'cust029', 4, 'Easy to switch between Bluetooth and receiver mode.'),
(13, 'cust030', 3, 'Good ergonomics but takes time to adjust to the new grip.'),
(14, 'cust010', 5, 'Silent buttons are perfect for late night work. Charging is quick.'),
(14, 'cust031', 5, 'Comfortable and responsive. Exactly what I wanted from a vertical mouse.'),
(14, 'cust032', 4, 'Feels premium though the finish is a bit smooth for my taste.'),
(15, 'cust011', 3, 'Very slim and portable but not ideal for large hands.'),
(15, 'cust033', 4, 'Silent clicks and small receiver make this great for travel.'),
(15, 'cust034', 3, 'Does the job but the scroll wheel could be smoother.'),
(16, 'cust012', 4, 'Dual connectivity works great and the rechargeable battery is convenient.'),
(16, 'cust035', 4, 'Nice slim design that matches my ultrabook.'),
(16, 'cust036', 3, 'Good mouse but I occasionally bump the DPI button.'),
(17, 'cust013', 4, 'Small adapter that charges my phone fast without getting hot.'),
(17, 'cust037', 5, 'Perfect travel charger. I keep one in my backpack at all times.'),
(17, 'cust038', 4, 'Works as expected with my phone and tablet.'),
(18, 'cust014', 5, 'Handy dual port charger for my phone and power bank together.'),
(18, 'cust039', 5, 'Charges quickly and the size is still compact enough for travel.'),
(18, 'cust040', 4, 'Solid build and no noticeable heating even during long charges.'),
(19, 'cust015', 5, 'My primary laptop charger now. Powers my ultrabook and phone simultaneously.'),
(19, 'cust001', 5, 'GaN design keeps it small for such high wattage. Very impressed.'),
(19, 'cust002', 4, 'Great performance though it is slightly heavier than a basic charger.'),
(20, 'cust016', 5, 'Fantastic multi port charger for work trips. Handles laptop tablet and phone together.'),
(20, 'cust003', 5, 'Interchangeable plugs made international travel painless.'),
(20, 'cust004', 4, 'Expensive but replaces several bricks in my bag.'),
(21, 'cust017', 4, 'Comfortable wrist support and stays in place on my wooden desk.'),
(21, 'cust005', 4, 'Foam feels supportive even after months of use.'),
(21, 'cust006', 3, 'Nice pad but I wish it were slightly longer.'),
(22, 'cust018', 5, 'Complete set for keyboard and mouse. Great for long coding sessions.'),
(22, 'cust007', 5, 'Soft surface and easy to clean. My wrists no longer ache.'),
(22, 'cust008', 4, 'Very comfortable though it took a while for the foam to break in.'),
(23, 'cust019', 4, 'Simple sturdy stand that keeps my laptop at eye level.'),
(23, 'cust009', 4, 'Assembly was quick and the aluminum looks premium.'),
(23, 'cust010', 3, 'Works well but the edges could be a bit smoother.'),
(24, 'cust020', 5, 'Folds flat and fits into my backpack pocket. Perfect for coworking spaces.'),
(24, 'cust011', 5, 'Multiple angles are useful when switching between typing and drawing.'),
(24, 'cust012', 4, 'Rock solid once set up. Slight wobble only on very soft surfaces.'),
(25, 'cust021', 4, 'Clear picture and plug and play with my laptop.'),
(25, 'cust013', 4, 'Privacy cover is a thoughtful touch. Microphones sound decent on calls.'),
(25, 'cust014', 3, 'Good camera but image softens slightly in low light.'),
(26, 'cust022', 5, 'Smooth 60fps video makes a big difference for training videos.'),
(26, 'cust015', 5, 'Wide field works great for team meetings in our small huddle room.'),
(26, 'cust016', 4, 'Excellent webcam though the cable could be longer.'),
(27, 'cust023', 5, '2K resolution looks very crisp on screen shares and recordings.'),
(27, 'cust017', 5, 'Auto focus is quick even when I show documents up close.'),
(27, 'cust018', 4, 'Great upgrade from my default laptop camera.'),
(28, 'cust024', 4, 'Sharp image and privacy shutter makes it feel secure.'),
(28, 'cust019', 4, 'Color reproduction is natural and not overly saturated.'),
(28, 'cust020', 3, 'Good but fixed focus means you need to sit at the right distance.'),
(29, 'cust025', 4, 'Clear voice quality on calls and meetings. Mute button is very handy.'),
(29, 'cust021', 4, 'Simple to set up and works instantly with my laptop.'),
(29, 'cust022', 3, 'Good microphone but picks up some keyboard noise.'),
(30, 'cust026', 5, 'Boom arm and pop filter make this feel like a studio setup.'),
(30, 'cust023', 5, 'Gain control helps balance levels quickly between meetings and recordings.'),
(30, 'cust024', 4, 'Great sound though the arm clamp needs a solid desk edge.');

INSERT INTO CartItems (product_id, customer_username, quantity) VALUES
(1, 'cust001', 1),
(2, 'cust005', 1),
(4, 'cust008', 1),
(10, 'cust023', 2),
(12, 'cust027', 1),
(14, 'cust010', 1),
(18, 'cust039', 1),
(19, 'cust015', 1),
(20, 'cust003', 1),
(23, 'cust019', 1),
(24, 'cust020', 1),
(25, 'cust021', 1),
(26, 'cust022', 1),
(27, 'cust017', 1),
(30, 'cust026', 1),
(31, 'cust031', 1),
(32, 'cust001', 1),
(35, 'cust005', 2),
(36, 'cust013', 1),
(37, 'cust007', 1),
(40, 'cust002', 1),
(41, 'cust016', 1),
(45, 'cust033', 1),
(48, 'cust040', 1),
(50, 'cust006', 1),
(55, 'cust014', 1),
(56, 'cust018', 1),
(57, 'cust012', 1),
(59, 'cust034', 1),
(60, 'cust010', 1);

INSERT INTO Orders (product_id, customer_username, quantity) VALUES
(1, 'cust001', 1),
(2, 'cust005', 1),
(3, 'cust003', 1),
(4, 'cust008', 1),
(5, 'cust009', 1),
(6, 'cust015', 1),
(7, 'cust003', 1),
(8, 'cust004', 1),
(9, 'cust005', 1),
(10, 'cust006', 1),
(11, 'cust007', 1),
(12, 'cust008', 1),
(13, 'cust009', 1),
(14, 'cust010', 1),
(15, 'cust011', 1),
(16, 'cust012', 1),
(17, 'cust013', 1),
(18, 'cust014', 1),
(19, 'cust015', 1),
(20, 'cust016', 1),
(21, 'cust017', 1),
(22, 'cust018', 1),
(23, 'cust019', 1),
(24, 'cust020', 1),
(25, 'cust021', 1),
(26, 'cust022', 1),
(27, 'cust023', 1),
(28, 'cust024', 1),
(29, 'cust025', 1),
(30, 'cust026', 1),
(31, 'cust031', 1),
(32, 'cust001', 1),
(33, 'cust002', 1),
(34, 'cust033', 1),
(35, 'cust005', 1),
(36, 'cust013', 1),
(40, 'cust002', 1),
(41, 'cust016', 1),
(45, 'cust033', 1),
(48, 'cust040', 1),
(50, 'cust006', 1),
(55, 'cust014', 1),
(56, 'cust018', 1),
(57, 'cust012', 1),
(59, 'cust034', 1),
(60, 'cust010', 1);


INSERT INTO Reviews (product_id, customer_username, rating, review) VALUES
(31, 'cust027', 4, 'Comfortable over ear design and battery life meets the advertised 20 plus hours. Sound is balanced for music and calls.'),
(31, 'cust008', 4, 'I use these daily at my desk and on the bus. Foldable design makes them easy to pack.'),
(31, 'cust014', 3, 'Good headphones but the clamping force is a bit strong for my head.'),
(32, 'cust001', 5, 'Noise canceling performance is excellent for the price. Great for open office work.'),
(32, 'cust019', 5, 'Battery easily lasts several days of commuting. Fast charge is genuinely fast.'),
(32, 'cust035', 4, 'Comfortable fit and effective ANC though the case is slightly bulky.'),
(33, 'cust002', 4, 'Lightweight and comfortable with clear audio. Perfect for online classes.'),
(33, 'cust021', 4, 'Simple controls and long battery life. My teenager loves them.'),
(33, 'cust030', 3, 'Does the job but lacks deep bass if you are a music enthusiast.'),
(34, 'cust003', 4, 'Bass heavy sound works great for workouts. Ear cups are soft.'),
(34, 'cust017', 4, 'Good battery life and strong wireless connection.'),
(34, 'cust038', 3, 'Nice punchy sound but can get a bit warm after long sessions.'),
(35, 'cust004', 4, 'Comfortable earbuds with secure fit. Case is compact and pocket friendly.'),
(35, 'cust020', 4, 'Very easy to pair with my phone and laptop. Touch controls work reliably.'),
(35, 'cust028', 3, 'Sound is decent but ambient noise isolation is only average.'),
(36, 'cust005', 5, 'ANC works surprisingly well on the subway. Wireless charging is a nice extra.'),
(36, 'cust016', 5, 'Great all round earbuds for calls and music. Ambient mode feels natural.'),
(36, 'cust031', 4, 'Premium feel and good soundstage. Case is slightly larger than basic models.'),
(37, 'cust006', 4, 'Solid hub that handles my mouse keyboard and HDMI monitor with no issues.'),
(37, 'cust022', 4, 'Compact and does not heat up much even when all ports are in use.'),
(37, 'cust039', 3, 'Works fine but the attached cable could be a little longer.'),
(38, 'cust007', 5, 'Replaced my bulky dock with this hub. Ethernet and multiple USB ports are very handy.'),
(38, 'cust018', 5, 'Perfect for working from home with dual monitors and wired network.'),
(38, 'cust034', 4, 'Overall excellent though the VGA port is a bit loose with older cables.'),
(39, 'cust008', 4, 'Strong braided cable that feels durable. Charges my phone quickly.'),
(39, 'cust025', 4, 'Good value for the quality. Length is ideal for bedside charging.'),
(39, 'cust012', 3, 'Nice cable but the connector housing is slightly thick for my slim phone case.'),
(40, 'cust009', 5, 'Charges my tablet and laptop without issue. Data transfer is fast.'),
(40, 'cust001', 5, 'My go to USB C cable now. Feels very sturdy.'),
(40, 'cust023', 4, 'Performs as advertised. Would love a shorter version for desktop use.'),
(41, 'cust010', 4, 'Dual arms freed up a lot of desk space and improved posture.'),
(41, 'cust029', 4, 'Installation was straightforward and everything feels secure.'),
(41, 'cust036', 3, 'Good but requires a strong desk clamp area for heavier monitors.'),
(42, 'cust011', 5, 'Gas spring arm is very smooth. Adjusting height is effortless.'),
(42, 'cust020', 5, 'Great range of motion for my ultrawide monitor. Very sturdy.'),
(42, 'cust037', 4, 'Excellent build quality though cable routing clips could be stronger.'),
(43, 'cust012', 4, 'Desk mat is large enough for keyboard and mouse with room for notes.'),
(43, 'cust024', 4, 'Surface feels nice and helps the mouse glide smoothly.'),
(43, 'cust033', 3, 'Edges curl a bit after unboxing but settled after a few days.'),
(44, 'cust013', 4, 'Good basic mat that protects my old desk from scratches.'),
(44, 'cust026', 4, 'Great for gaming and everyday use. Easy to wipe clean.'),
(44, 'cust021', 3, 'Does the job but I prefer a thicker mat.'),
(45, 'cust014', 4, 'Vertical stand securely holds my laptop and freed up space for documents.'),
(45, 'cust002', 4, 'Adjustable width works perfectly with both my work and personal laptops.'),
(45, 'cust032', 3, 'Good stand but the base could be a bit heavier for extra stability.'),
(46, 'cust015', 5, 'Dual slots are ideal for my two laptops. Desk looks much cleaner now.'),
(46, 'cust005', 5, 'Space saver for my small home office. Finish matches my monitor stand.'),
(46, 'cust027', 4, 'Very good though tightening the adjustment screws takes some patience.'),
(47, 'cust016', 4, 'Nice quality power strip with both AC and USB. Helps reduce clutter.'),
(47, 'cust030', 4, 'Cord length is sufficient and the overload switch feels reassuring.'),
(47, 'cust040', 3, 'All good so far but the power button light is quite bright at night.'),
(48, 'cust017', 5, 'Tower design is perfect for my entertainment center. No blocked sockets.'),
(48, 'cust006', 5, 'Great balance of USB ports and outlets. Feels safe and well built.'),
(48, 'cust039', 4, 'Very useful though the vertical form takes up some visual space on the desk.'),
(49, 'cust018', 4, 'Mesh node improved coverage in my bedroom significantly.'),
(49, 'cust019', 4, 'Setup through the app was simple and quick.'),
(49, 'cust011', 3, 'Good for a small apartment but range drops off near the balcony.'),
(50, 'cust020', 5, 'WiFi 6 unit handles all our smart devices with no lag.'),
(50, 'cust022', 5, 'Streaming and gaming are smoother after upgrading to this mesh router.'),
(50, 'cust028', 4, 'Great performance though the app has a slight learning curve.'),
(51, 'cust021', 4, 'Keeps my cables and power strip off the floor. Looks much tidier.'),
(51, 'cust007', 4, 'Easy to mount and strong enough for multiple chargers.'),
(51, 'cust013', 3, 'Works but the included screws are on the shorter side.'),
(52, 'cust022', 4, 'Raceways hide cables nicely along the wall. Paintable surface is a bonus.'),
(52, 'cust019', 4, 'Adhesive holds well on painted walls. Installation was quick.'),
(52, 'cust034', 3, 'Neat solution but cutting sections to size takes a bit of effort.'),
(53, 'cust023', 4, 'Footrest helps reduce leg fatigue during long writing sessions.'),
(53, 'cust008', 4, 'Non slip surface is great and the tilt adjustment is useful.'),
(53, 'cust025', 3, 'Comfortable but a little lightweight for aggressive rocking.'),
(54, 'cust024', 5, 'Memory foam feels plush and supportive. Cover is easy to remove and wash.'),
(54, 'cust001', 5, 'Doubles as a leg pillow on the sofa. Very versatile.'),
(54, 'cust029', 4, 'Great comfort, though I wish it were slightly wider.'),
(55, 'cust025', 4, 'Ring light improves my video call quality significantly.'),
(55, 'cust009', 4, 'Good brightness levels and the tripod is stable for desk use.'),
(55, 'cust036', 3, 'Nice overall but the phone holder mechanism feels a bit stiff.'),
(56, 'cust026', 5, 'Perfect for recording tutorials and standing meetings. Remote is very handy.'),
(56, 'cust018', 5, 'Bright, even light and easy color adjustments.'),
(56, 'cust037', 4, 'Excellent kit though the extended tripod takes some room to store.'),
(57, 'cust027', 4, 'Great lap desk for working from couch. Vents keep my laptop cooler.'),
(57, 'cust010', 4, 'Mouse area is spacious and comfortable to use.'),
(57, 'cust032', 3, 'Good build but not ideal for very large gaming laptops.'),
(58, 'cust028', 4, 'Cushioned bottom is very comfortable on my legs. Wood top feels solid.'),
(58, 'cust012', 4, 'Phone slot is convenient for notifications while working.'),
(58, 'cust040', 3, 'Nice product but a little heavy to carry around the house.'),
(59, 'cust029', 4, 'Handy hub for my mic and external drive. Audio jack is a nice touch.'),
(59, 'cust014', 4, 'Small and solid. Blue LED is useful to see when it is active.'),
(59, 'cust033', 3, 'Works well but the cable is quite short for under desk mounting.'),
(60, 'cust030', 5, 'Perfect travel hub with HDMI and card readers. My go to accessory.'),
(60, 'cust002', 5, 'Handles my mouse, flash drive and external display smoothly.'),
(60, 'cust035', 4, 'Very good hub, only warms up slightly under heavy use.');

INSERT INTO Products (product_id, seller_username, name, rating, price, quantity, description) VALUES
(91, 'seller001', 'Acer Desk Dock Pro | 11 in 1 USB C Docking Station | Dual 4K HDMI | DisplayPort | Ethernet | 4x USB | SD MicroSD | 100W PD | Space Gray', 5, 7999, 70, 'High end docking station designed for power users who require multiple external displays and fast wired connectivity. Supports dual 4K monitors via HDMI and DisplayPort, includes gigabit Ethernet and four USB ports for peripherals, and passes through up to 100W USB C power for charging modern laptops.'),
(92, 'seller001', 'Acer Desk Dock Essential | 7 in 1 USB C Hub | 4K HDMI | 3x USB 3.0 | SD MicroSD | 60W PD | Silver', 4, 4499, 120, 'Compact all in one USB C hub for home offices and students. Provides single 4K HDMI output, three high speed USB ports, and dual card readers for cameras and drones. 60W pass through power keeps ultrabooks charged while connected.'),
(93, 'seller002', 'LogiFlex ErgoStand | Adjustable Laptop Riser | Aluminum | Foldable | 10 to 17 Inch Laptops | Silver', 4, 2599, 110, 'Ergonomic laptop stand with multiple height and angle adjustments, designed to raise screens to eye level and reduce neck strain. Folds flat into a slim profile for easy storage and transport in backpacks or briefcases.'),
(94, 'seller002', 'LogiFlex ErgoStand Duo | Dual Height Laptop Stand | Integrated Phone Holder | Ventilated | Gray', 4, 2799, 90, 'Laptop stand with two quick switch height positions and integrated groove to hold a smartphone beside the keyboard. Wide ventilated surface improves airflow for gaming and productivity laptops.'),
(95, 'seller003', 'KeyPro NumPad Plus | Wireless Numeric Keypad | 34 Keys | BT 5.0 | Rechargeable | Black', 4, 1999, 150, 'Standalone wireless numeric keypad tailored for spreadsheet users and accountants. Includes dedicated calculator hotkey and programmable shortcut keys for frequently used functions. Rechargeable battery charges via USB C.'),
(96, 'seller003', 'KeyPro NumPad Lite | Wireless Numeric Keypad | 22 Keys | 2.4GHz USB Receiver | Silver', 3, 1699, 130, 'Simple plug and play numeric keypad using 2.4GHz receiver, ideal for laptops without a number pad. Slim design with soft touch keys for comfortable numeric entry.'),
(97, 'seller004', 'SkyBoard CompactPad | Wireless Touchpad | Multi Gesture Support | USB C Rechargeable | Silver', 4, 3299, 100, 'Standalone wireless touchpad providing multi gesture support for scrolling, zooming and app switching. Designed for minimalists using desktops with external keyboards who miss laptop style navigation.'),
(98, 'seller004', 'SkyBoard CompactPad Plus | Wireless Touchpad | Glass Surface | BT 5.2 | Multi OS | Space Gray', 5, 4299, 80, 'Premium touchpad with smooth glass surface and refined haptics that mimic high end notebook trackpads. Supports customizable gestures on Windows and macOS via companion software.'),
(99, 'seller005', 'NovaType SilentKeys | Full Size Wired Keyboard | Quiet Scissor Switches | Spill Resistant | Black', 4, 1799, 200, 'Full size wired keyboard geared toward shared offices and libraries. Quiet scissor switches provide soft feedback and the spill resistant design protects against accidental coffee or water spills.'),
(100, 'seller005', 'NovaType SilentKeys RGB | Full Size Wired Keyboard | White Backlight | Media Keys | Black', 4, 2199, 160, 'Variant of SilentKeys with white backlighting for late night work and dedicated media controls for quick volume and playback adjustments. Uses same quiet scissor switches and slim profile housing.'),
(101, 'seller006', 'WorkMate ProChair Cushion | Memory Foam Seat Cushion | Non Slip Bottom | Black', 5, 2199, 140, 'Thick memory foam cushion that turns standard office chairs into more ergonomic seats. Contoured design helps relieve tailbone pressure during long working sessions. Non slip base keeps it securely in place.'),
(102, 'seller006', 'WorkMate ProChair Back | Lumbar Support Pillow | Adjustable Straps | Breathable Mesh | Black', 4, 1999, 130, 'Lumbar support cushion aimed at improving posture when sitting for long hours. Breathable mesh cover and adjustable straps allow it to fit different office and gaming chairs.'),
(103, 'seller007', 'ProClick TravelCase | Hard Shell Accessory Case | Fits Mouse Charger Cables | Black', 4, 1299, 160, 'Durable travel case with customizable dividers for organizing mice, small chargers, power banks and cables. Hard shell construction protects fragile accessories inside bags and suitcases.'),
(104, 'seller007', 'ProClick TravelCase Mini | Compact Tech Organizer | Elastic Loops | Zipper Pocket | Gray', 4, 999, 180, 'Smaller tech organizer sized for daily carry, featuring elastic loops for cables and chargers plus a mesh pocket for USB drives and adapters. Ideal for commuters and students.'),
(105, 'seller008', 'PixelPeak ClarityScreen 15 | 15.6 Inch Portable Monitor | 1080p IPS | USB C and HDMI | Smart Cover Stand | Black', 5, 11999, 70, 'Portable full HD monitor that expands workspace for laptops and gaming consoles. Single USB C connection carries both power and video with compatible devices, while HDMI offers flexibility with older hardware. Includes smart cover that doubles as stand.'),
(106, 'seller008', 'PixelPeak ClarityScreen 13 | 13.3 Inch Portable Monitor | 1080p | Slim Bezel | USB C | Silver', 4, 9999, 80, 'Sleek 13.3 inch portable display designed for ultra portable laptops and tablets. Lightweight body and slim bezels make it ideal for dual screen productivity on the go.'),
(107, 'seller009', 'EverydayCharge DeskDock | Wireless Charging Stand | 15W Fast Charge | Adjustable Angle | Black', 4, 2499, 150, 'Qi wireless charging stand that props up phones at adjustable viewing angles for video calls and notifications. Supports up to 15W charging for compatible phones with foreign object detection and overheat protection.'),
(108, 'seller009', 'EverydayCharge MultiPad | 3 in 1 Wireless Charging Pad | Phone Earbuds Watch | 25W Total | White', 5, 3999, 90, 'Multi device charging pad capable of powering a phone, true wireless earbuds and supported smart watch at the same time. Designed to declutter nightstands and office desks from multiple cables.'),
(109, 'seller010', 'NovaConnect TravelRouter Nano | AC750 Dual Band Travel Router | Repeater and AP Modes | USB Powered | White', 4, 3299, 90, 'Compact travel router that converts hotel Ethernet or weak WiFi into a private secure network. Multiple operating modes support repeater, access point and client bridge configurations.'),
(110, 'seller010', 'NovaConnect TravelRouter Pro | AC1200 Dual Band Travel Router | USB C Power | VPN Passthrough | White', 5, 4499, 70, 'Upgraded travel router with faster AC1200 speeds and better antenna design for larger rooms. USB C powered for compatibility with power banks and modern chargers, ideal for frequent travelers.'),
(111, 'seller011', 'EliteDesk SteelMonitor Stand | Monitor Riser | Integrated Drawer | Black', 4, 2499, 100, 'Steel monitor riser that lifts screens to ergonomic height while providing a small drawer for storing stationery and accessories. Ventilated top keeps laptops and consoles cool.'),
(112, 'seller011', 'EliteDesk WoodMonitor Stand | Bamboo Monitor Riser | Dual Slots | Natural Finish', 5, 2799, 80, 'Bamboo monitor stand that blends with modern and minimal desk setups. Dual slots can hold phones or tablets upright, while the space beneath stores keyboard or documents.'),
(113, 'seller012', 'HomeOffice Whiteboard Glass | Frameless Glass Dry Erase Board | 60 x 40 cm | Wall Mount | Frosted White', 4, 3499, 90, 'Tempered glass dry erase board that adds a clean writing surface to home offices and meeting corners. Resists ghosting and can be mounted horizontally or vertically with included hardware.'),
(114, 'seller012', 'HomeOffice Whiteboard Glass XL | 90 x 60 cm | Magnetic Glass Board | White', 5, 4999, 60, 'Larger magnetic glass board designed for team planning and brainstorming sessions. Works with strong magnets to hold notes and printouts alongside sketches.'),
(115, 'seller013', 'CloudEdge StudioLight Bar | Monitor Light Bar | Stepless Dimming | Warm to Cool | USB Powered | Black', 5, 2999, 120, 'Slim light bar that mounts on top of monitors and illuminates the desk without screen glare. Adjustable color temperature ranges from warm to cool white to match ambient lighting and reduce eye strain.'),
(116, 'seller013', 'CloudEdge StudioLight Bar Pro | Monitor Light Bar | Auto Dimming Sensor | Touch Controls | Black', 5, 3799, 90, 'Enhanced monitor light bar with ambient light sensor that automatically adjusts brightness. Touch controls allow quick switching between color modes and levels for productivity or reading.'),
(117, 'seller014', 'SmartChoice CableBox | Cable Management Box | Fits Power Strip | Flame Retardant Plastic | White', 4, 1599, 150, 'Cable management box that hides surge protectors and tangled plugs, making floors and desks safer and tidier. Ventilation slots control heat while child friendly design keeps outlets out of sight.'),
(118, 'seller014', 'SmartChoice CableBox XL | Large Cable Organizer Box | Dual Side Openings | Black', 4, 1899, 120, 'Oversized cable box designed for larger power strips and bulky chargers. Dual openings route cables neatly in home theaters and multi monitor workstations.'),
(119, 'seller015', 'ConnectIT StreamDeck Mini | Programmable Macro Pad | 12 Keys | Per Key Backlight | USB C | Black', 5, 4599, 70, 'Compact macro pad designed for streamers and productivity power users. Each key has customizable backlight and programmable macros for app launching, scene switching and shortcut chains.'),
(120, 'seller015', 'ConnectIT StreamDeck XL | Programmable Macro Pad | 24 Keys | Detachable Stand | Black', 5, 6999, 50, 'Larger macro controller with 24 programmable keys and detachable angled stand. Ideal for complex streaming setups, video editing timelines and automation heavy workflows.'),
(121, 'seller001', 'Acer SilentMouse Duo | Wireless Mouse Combo | 2.4GHz and BT 5.1 | Silent Clicks | Dual Device | Black', 4, 2299, 160, 'Quiet dual mode mouse aimed at professionals who frequently switch between laptop and tablet. Side mounted toggle selects between Bluetooth and receiver mode, and silent main buttons keep noise to a minimum in shared spaces.'),
(122, 'seller001', 'Acer SilentMouse Duo Plus | Rechargeable Wireless Mouse | USB C | Adjustable DPI | Graphite', 4, 2499, 130, 'Rechargeable version of SilentMouse Duo with USB C port and on the fly DPI adjustment. Designed for users who prefer a single mouse for both home and office, without disposable batteries.'),
(123, 'seller002', 'LogiFlex SplitBoard | Ergonomic Split Keyboard | Cushioned Palm Rest | 2.4GHz Wireless | Black', 5, 5499, 90, 'Ergonomic split keyboard that encourages natural wrist alignment and reduces strain for heavy typists. Includes soft palm rest and dedicated shortcut keys for productivity.'),
(124, 'seller002', 'LogiFlex SplitBoard Compact | Tenkeyless Ergonomic Wireless Keyboard | BT 5.0 | Black', 4, 4999, 80, 'Compact split keyboard with no number pad, ideal for keeping mouse closer to the body and reducing shoulder strain. Connects via Bluetooth to laptops and tablets.'),
(125, 'seller003', 'KeyPro GamerPad TKL | Tenkeyless Mechanical Keyboard | Red Switches | RGB Backlight | Black', 5, 5999, 100, 'Mechanical gaming keyboard with linear red switches and per key RGB lighting. Tenkeyless layout gives more mouse room while retaining function keys, making it suitable for both work and gaming.'),
(126, 'seller003', 'KeyPro GamerPad 60 | 60 Percent Mechanical Keyboard | Brown Switches | USB C | White', 4, 5499, 90, 'Compact 60 percent mechanical board with tactile brown switches for a satisfying yet office friendly feel. Programmable layers let users access arrow keys and function rows through shortcuts.'),
(127, 'seller004', 'SkyBoard ErgoLift Stand | Aluminum Laptop Stand | Single Piece Design | Silver', 4, 2399, 120, 'Fixed height laptop stand that raises screens to ergonomic level while keeping typing angle comfortable. One piece aluminum design improves stability and aesthetics on minimalist desks.'),
(128, 'seller004', 'SkyBoard ErgoLift Stand Black | Aluminum Laptop Riser | Matte Black', 4, 2499, 100, 'Matte black variant of ErgoLift stand to match dark themed setups and gaming rigs. Same sturdy construction and non slip pads on base and top surface.'),
(129, 'seller005', 'NovaType ChargeBar 6 | Desktop Charging Station | 6 USB Ports | 60W Total Output | Black', 4, 2799, 130, 'Compact desktop charging station with six high speed USB ports for phones, tablets and accessories. Ideal for shared family spaces and office collaboration areas.'),
(130, 'seller005', 'NovaType ChargeBar 10 | Desktop Charging Tower | 10 USB Ports | Smart Auto ID | White', 5, 3499, 90, 'Vertical charging tower that organizes up to ten devices at once. Smart auto identification distributes current efficiently and protects against overcharging.');

INSERT INTO Reviews (product_id, customer_username, rating, review) VALUES
(91, 'cust001', 5, 'Replaced my old dock with this and now I run two 4K monitors plus Ethernet from a single cable. Rock solid performance.'),
(91, 'cust015', 5, 'Exactly what I needed for my work from home setup. All ports work without any driver hassles on Windows.'),
(91, 'cust028', 4, 'Great dock though it does get slightly warm under full load.'),
(92, 'cust002', 4, 'Compact hub that lives in my laptop sleeve. HDMI and card readers are very handy on shoots.'),
(92, 'cust021', 4, 'Good selection of ports for the price. PD passthrough keeps my ultrabook charged.'),
(92, 'cust034', 3, 'Works well but HDMI tops out at 30Hz at 4K, which is fine for productivity but not gaming.'),
(93, 'cust003', 4, 'Sturdy stand and easy to adjust height. Helps with neck strain during long coding sessions.'),
(93, 'cust010', 4, 'Folds flat which is perfect for tossing into my backpack.'),
(93, 'cust036', 3, 'Good stand though the front lip slightly interferes with my thick laptop.'),
(94, 'cust004', 4, 'I like the quick switch height presets and phone slot. Simple and effective.'),
(94, 'cust024', 4, 'Ventilated design keeps my gaming laptop cooler when docked.'),
(94, 'cust039', 3, 'Works as described but the hinge feels a bit stiff out of the box.'),
(95, 'cust005', 4, 'Numeric keypad is responsive and connects quickly to my laptop. Battery lasts weeks.'),
(95, 'cust018', 4, 'Helpful for spreadsheets and accounting software. Shortcut keys save time.'),
(95, 'cust031', 3, 'Nice device but the finish shows fingerprints easily.'),
(96, 'cust006', 3, 'Simple plug and play keypad. Does what it says.'),
(96, 'cust020', 4, 'Great for use with my small laptop when entering lots of numbers.'),
(96, 'cust032', 3, 'Keys are a bit louder than I expected but accuracy is fine.'),
(97, 'cust007', 4, 'Touchpad gives me laptop like gestures on my desktop. Very convenient.'),
(97, 'cust017', 4, 'Multi gesture support is smooth on Windows 11. Battery life is excellent.'),
(97, 'cust029', 3, 'Nice idea but occasionally misses very fast gestures.'),
(98, 'cust008', 5, 'Glass surface feels premium and tracking is extremely accurate.'),
(98, 'cust022', 5, 'Companion software is easy to use for configuring custom gestures.'),
(98, 'cust037', 4, 'Fantastic device though the price is on the higher side.'),
(99, 'cust009', 4, 'Quiet keyboard that is perfect for taking notes during calls.'),
(99, 'cust019', 4, 'Spill resistance saved it from a coffee spill on day two.'),
(99, 'cust033', 3, 'Layout is standard, but key travel could be a tad deeper.'),
(100, 'cust010', 4, 'White backlight is subtle and helpful for late night work.'),
(100, 'cust025', 4, 'Media keys are a big plus for quickly controlling streaming audio.'),
(100, 'cust038', 3, 'Solid keyboard though the backlight has only one brightness level.'),
(101, 'cust011', 5, 'Seat cushion completely changed the comfort level of my old chair. Highly recommend.'),
(101, 'cust023', 5, 'Memory foam provides great support during long editing sessions.'),
(101, 'cust035', 4, 'Very comfortable but takes a day to fully expand after unboxing.'),
(102, 'cust012', 4, 'Lumbar pillow keeps my back supported and straps fit my gaming chair.'),
(102, 'cust026', 4, 'Mesh fabric is breathable and does not trap heat.'),
(102, 'cust040', 3, 'Helps posture but the cushion is slightly firm for my taste.'),
(103, 'cust013', 4, 'Perfect size for my wireless mouse and power bank. Hard shell feels protective.'),
(103, 'cust016', 4, 'Useful for organizing travel adapters in my suitcase.'),
(103, 'cust027', 3, 'Good case but the zippers feel a little light duty.'),
(104, 'cust014', 4, 'Keeps all my cables tidy in my backpack. Lightweight and slim.'),
(104, 'cust021', 4, 'Elastic loops hold chargers and earphones securely.'),
(104, 'cust030', 3, 'Nice organizer but could use one more internal pocket.'),
(105, 'cust015', 5, 'Portable monitor works perfectly with my laptop and Switch. Colors are vibrant.'),
(105, 'cust028', 5, 'Single USB C cable is super convenient. The cover stand is stable enough for typing.'),
(105, 'cust036', 4, 'Fantastic for dual screen coding although speakers are just average.'),
(106, 'cust016', 4, 'Great travel monitor for my 13 inch ultrabook. Lightweight but sturdy.'),
(106, 'cust020', 4, 'Fits easily in my laptop bag and helps when working in cafes.'),
(106, 'cust032', 3, 'Good screen but the brightness could be slightly higher for outdoor use.'),
(107, 'cust017', 4, 'Charge stand keeps my phone visible on my desk while charging quickly.'),
(107, 'cust024', 4, 'Angle adjustments are handy during video calls.'),
(107, 'cust033', 3, 'Charges fine but the LED indicator is bright in a dark room.'),
(108, 'cust018', 5, 'Finally one pad for my phone, earbuds and watch. Great bedside accessory.'),
(108, 'cust029', 5, 'Less cable clutter and charges everything overnight reliably.'),
(108, 'cust037', 4, 'Works well though alignment for the watch pad is a bit finicky at first.'),
(109, 'cust019', 4, 'Useful travel router that makes hotel WiFi more secure. Setup is fairly simple.'),
(109, 'cust002', 4, 'Compact size and USB power make it easy to pack.'),
(109, 'cust031', 3, 'Performs okay but the web interface feels dated.'),
(110, 'cust020', 5, 'Fast travel router with strong signal even in larger rooms.'),
(110, 'cust003', 5, 'USB C power is a big plus since I already carry compatible chargers.'),
(110, 'cust034', 4, 'Excellent device though it takes a bit to learn all the modes.'),
(111, 'cust021', 4, 'Monitor stand with drawer cleared clutter from under my screen.'),
(111, 'cust007', 4, 'Metal construction feels very solid and stable.'),
(111, 'cust035', 3, 'Good product but the drawer could slide a little smoother.'),
(112, 'cust022', 5, 'Beautiful bamboo stand that matches my wooden desk. Highly recommend.'),
(112, 'cust005', 5, 'Dual slots for phone and tablet are more useful than I expected.'),
(112, 'cust038', 4, 'Looks great, just be careful not to spill liquids on the wood finish.'),
(113, 'cust023', 4, 'Glass whiteboard is much nicer than regular boards and wipes clean every time.'),
(113, 'cust008', 4, 'Size is perfect for my office wall. Installation took about 20 minutes.'),
(113, 'cust030', 3, 'Good board but magnets only work with very strong types.'),
(114, 'cust024', 5, 'Large surface is great for planning weekly tasks and project timelines.'),
(114, 'cust001', 5, 'Magnetic feature is super handy for pinning printouts and notes.'),
(114, 'cust039', 4, 'Fantastic board but you must mount it with care due to weight.'),
(115, 'cust025', 5, 'Monitor light bar reduced eye strain and gave my desk a clean look.'),
(115, 'cust009', 5, 'No screen glare at all. Warm light mode is excellent for late evenings.'),
(115, 'cust033', 4, 'Very good, though the touch controls are a bit sensitive.'),
(116, 'cust026', 5, 'Auto dimming sensor works flawlessly as daylight changes.'),
(116, 'cust012', 5, 'Best desk upgrade I have bought in years. Light is even and adjustable.'),
(116, 'cust037', 4, 'Premium product with good build. Pricey but worth it if you work long hours.'),
(117, 'cust027', 4, 'Cable box hides all my adaptors and transformers behind the TV.'),
(117, 'cust010', 4, 'Plastic feels sturdy and vents keep things from overheating.'),
(117, 'cust032', 3, 'Works fine but I wish it came with cable ties in the box.'),
(118, 'cust028', 4, 'XL version easily fits my long power board and oversized plugs.'),
(118, 'cust011', 4, 'Keeps curious kids and pets away from the power strip.'),
(118, 'cust040', 3, 'Good size but the lid flexes slightly when fully loaded.'),
(119, 'cust029', 5, 'Macro pad made streaming and editing much easier. Software is intuitive.'),
(119, 'cust014', 5, 'Per key backlight looks great and keys feel mechanical and responsive.'),
(119, 'cust036', 4, 'Fantastic tool for macros. Took some time to set up profiles initially.'),
(120, 'cust030', 5, '24 keys give me enough shortcuts for all my video editing tasks.'),
(120, 'cust002', 5, 'Detachable stand lets me position it perfectly next to my keyboard.'),
(120, 'cust034', 4, 'Great device though it occupies a decent chunk of desk space.'),
(121, 'cust003', 4, 'Silent clicks and dual connectivity work as promised. Feels comfortable in hand.'),
(121, 'cust018', 4, 'Switching between laptop and tablet with the toggle is very convenient.'),
(121, 'cust031', 3, 'Nice mouse but the side buttons are a little small for my thumb.'),
(122, 'cust004', 4, 'Rechargeable battery and USB C port make this an easy recommendation.'),
(122, 'cust017', 4, 'DPI switch on top is handy when moving between design work and browsing.'),
(122, 'cust037', 3, 'Good overall but the finish is slightly slippery without a mouse mat.'),
(123, 'cust005', 5, 'Split layout dramatically reduced wrist pain. Palm rest is soft and supportive.'),
(123, 'cust019', 5, 'Takes a day to get used to but typing comfort is excellent afterward.'),
(123, 'cust033', 4, 'High quality board, though slightly large on smaller desks.'),
(124, 'cust006', 4, 'Compact split keyboard fit my narrow workspace perfectly.'),
(124, 'cust020', 4, 'Bluetooth connection is stable to both my laptop and tablet.'),
(124, 'cust038', 3, 'Good board but missing dedicated arrow keys takes adapting.'),
(125, 'cust007', 5, 'Red switches feel smooth for gaming and typing. RGB looks great.'),
(125, 'cust021', 5, 'Solid build with minimal flex. Perfect tenkeyless layout.'),
(125, 'cust039', 4, 'Great keyboard though software could use a dark mode.'),
(126, 'cust008', 4, 'Compact size frees up a lot of space on my desk.'),
(126, 'cust022', 4, 'Brown switches have a nice tactile bump while staying quiet.'),
(126, 'cust036', 3, 'Love the feel but need time to memorize the layers for function keys.'),
(127, 'cust009', 4, 'Simple clean stand. Lifts my laptop to a better viewing angle.'),
(127, 'cust023', 4, 'Solid aluminum and rubber pads keep it from sliding around.'),
(127, 'cust035', 3, 'Good stand but not adjustable, so check the height suits you.'),
(128, 'cust010', 4, 'Black finish matches my monitor and keyboard perfectly.'),
(128, 'cust024', 4, 'Feels sturdy and looks premium on my dark desk.'),
(128, 'cust037', 3, 'Nice stand but I wish the logo on the front were smaller.'),
(129, 'cust011', 4, 'Great hub for charging family devices in the living room.'),
(129, 'cust025', 4, 'Six ports are enough for phones plus a couple of tablets.'),
(129, 'cust040', 3, 'Works fine but blue status LEDs are a bit bright at night.'),
(130, 'cust012', 5, 'Perfect for our office hot desk area. Everyone can charge at once.'),
(130, 'cust026', 5, 'Vertical tower saves space and keeps cables organized.'),
(130, 'cust032', 4, 'Excellent charger though the power cable itself could be slightly longer.');

INSERT INTO Products (product_id, seller_username, name, rating, price, quantity, description) VALUES
(131, 'seller006', 'WorkMate QuietPad | Wireless Numeric Keyboard and Trackpad Combo | 2.4GHz | Compact Tenkeyless Layout | Black', 4, 2799, 120, 'Compact wireless keyboard with integrated numeric pad and precision touchpad, designed for small desks and conference room kiosks. 2.4GHz receiver ensures low latency input and eliminates cable clutter. Ideal for media PCs and minimalist workspaces.'),
(132, 'seller006', 'WorkMate QuietPad Plus | Wireless Numeric Keyboard and Trackpad Combo | BT 5.0 and 2.4GHz | Rechargeable | Gray', 5, 3299, 100, 'Upgraded QuietPad with dual wireless modes and rechargeable battery via USB C. Silent scissor switches keep noise to a minimum while multi gesture trackpad supports smooth scrolling and zooming in productivity apps.'),
(133, 'seller007', 'ProClick PrecisionMouse | Wireless Ergonomic Mouse | 2.4GHz | Adjustable DPI 800 3200 | 6 Buttons | Black', 4, 2199, 160, 'Ergonomic right handed mouse with contoured thumb rest and six programmable buttons. Adjustable DPI ranges from 800 to 3200 for precise control in spreadsheets, design software and games.'),
(134, 'seller007', 'ProClick PrecisionMouse RGB | Wireless Gaming Mouse | 2.4GHz | RGB Halo Lighting | 7 Buttons | Black', 4, 2599, 130, 'Gaming focused variant of PrecisionMouse featuring RGB halo lighting and additional shield button for DPI shift. Includes onboard memory for saving profiles between computers.'),
(135, 'seller008', 'PixelPeak KeyGuard | Universal Silicone Keyboard Cover | For 13 15 Inch Laptops | Transparent', 4, 799, 200, 'Thin silicone keyboard cover that protects laptop keys from dust, spills and wear while maintaining visibility of printed letters. Easy to wash and reuse, compatible with most 13 and 15 inch notebook layouts.'),
(136, 'seller008', 'PixelPeak KeyGuard Color | Universal Silicone Keyboard Skin | Transparent Smoke Gray', 4, 899, 180, 'Smoky transparent variant of KeyGuard for users who prefer a subtle tinted overlay. Preserves key legends and reduces glare from overhead lighting in bright offices.'),
(137, 'seller009', 'EverydayCharge CarFast 36W | Dual Port Car Charger | 18W USB C PD + 18W USB A QC | Compact Metal Body | Black', 5, 1599, 220, 'Compact metal car charger delivering fast charging to both USB C and USB A devices. Flush fit design sits nearly level with the dashboard and blue indicator ring shows power status at a glance.'),
(138, 'seller009', 'EverydayCharge CarFast 48W | Dual USB C PD Car Charger | All Metal | Black', 5, 1899, 180, 'High output dual USB C car charger capable of powering two smartphones or a tablet and phone simultaneously at fast speeds. Robust aluminum shell dissipates heat efficiently during long trips.'),
(139, 'seller010', 'NovaConnect SignalBoost | High Gain WiFi Range Extender | AC1200 | Dual External Antennas | Wall Plug | White', 4, 2999, 140, 'Wall plug WiFi extender designed to eliminate dead zones in apartments and small offices. Dual external antennas improve coverage and stability, with simple WPS button setup for quick deployment.'),
(140, 'seller010', 'NovaConnect SignalBoost Pro | WiFi 6 Range Extender | AX1500 | Gigabit LAN Port | App Control | White', 5, 4499, 100, 'Next gen WiFi 6 extender delivering improved speed and lower latency for gaming and streaming. Includes gigabit LAN port for wiring consoles or desktop PCs and full configuration via smartphone app.'),
(141, 'seller011', 'EliteDesk DrawerOrganizer | Under Monitor Desk Organizer | 3 Compartments | Sliding Drawer | White', 4, 1999, 130, 'Low profile organizer that sits under monitors or laptops, providing compartments for pens, sticky notes and USB drives. Sliding drawer keeps small accessories out of sight to maintain a clean workspace.'),
(142, 'seller011', 'EliteDesk DrawerOrganizer Wood | Under Monitor Organizer | Bamboo Top | White Drawer', 5, 2299, 100, 'Hybrid organizer combining warm bamboo top surface with white drawer base. Blends into home office decor while offering hidden storage for small supplies and cables.'),
(143, 'seller012', 'HomeOffice SitStand Riser | Desktop Sit Stand Converter | Gas Spring | Up to 32 Inch Monitor | Black', 5, 9999, 60, 'Desk converter that transforms a regular table into a sit stand workstation. Gas spring mechanism allows smooth transitions between sitting and standing, with spacious keyboard tray and upper platform for monitors or laptops.'),
(144, 'seller012', 'HomeOffice SitStand Compact | Slim Sit Stand Desk Riser | Single Handle Lift | Black', 4, 7499, 70, 'Compact sit stand riser designed for smaller desks and laptop centric setups. Single handle lift system enables quick height changes without heavy lifting, supporting healthy posture changes through the day.'),
(145, 'seller013', 'CloudEdge CaptureCard 1080 | USB HDMI Capture Card | 1080p 60fps | Low Latency | Plug and Play', 4, 3699, 110, 'USB capture card for streaming consoles, cameras and laptops at 1080p 60fps. Low latency passthrough allows smooth gameplay on an external monitor while capturing footage for streaming platforms.'),
(146, 'seller013', 'CloudEdge CaptureCard 4K | HDMI Capture Device | 4K Passthrough | 1080p 60fps Capture | USB C', 5, 5499, 80, 'Premium capture card with 4K passthrough for modern consoles and high frame rate capture at 1080p. USB C interface ensures stable bandwidth and compatibility with modern laptops and desktops.'),
(147, 'seller014', 'SmartChoice Headset Stand Duo | Dual Headphone Stand | Aluminum Frame | Cable Hook | Black', 4, 1499, 150, 'Dual arm headphone stand that holds two headsets to keep them off the desk. Integrated cable hook organizes audio and charging cables, making it ideal for shared gaming or studio setups.'),
(148, 'seller014', 'SmartChoice Headset Stand RGB | Single Headphone Stand | RGB Base Lighting | USB Hub | Black', 4, 1999, 120, 'Headphone stand with RGB illuminated base and integrated two port USB hub for plugging in flash drives and peripherals. Adds subtle ambient lighting to gaming and streaming desks.'),
(149, 'seller015', 'ConnectIT DockHub 8 | USB C Laptop Dock | Dual HDMI | 3x USB 3.0 | Ethernet | SD MicroSD | 87W PD', 5, 6999, 90, 'All in one dock that turns a single USB C port into dual display outputs, Ethernet and multiple USB ports. Supports up to two 1080p displays and passes through up to 87W charging to compatible notebooks.'),
(150, 'seller015', 'ConnectIT DockHub 12 | USB C Docking Station | Dual 4K HDMI | 6x USB | Ethernet | Audio | 100W PD', 5, 9499, 60, 'High capacity docking station for professional desks, supporting dual 4K monitors, multiple USB peripherals, audio out and gigabit Ethernet. Designed as a central hub for permanent home office installations.'),
(151, 'seller001', 'Acer TravelPower Bank 20K | 20000mAh Power Bank | 22.5W Fast Charge | USB C In Out | Dual USB A | Black', 4, 2999, 180, 'High capacity power bank built for frequent travelers needing reliable backup power. Supports fast charging via USB C and dual USB A ports, with LED indicators to show remaining capacity at a glance.'),
(152, 'seller001', 'Acer TravelPower Bank 10K | 10000mAh Slim Power Bank | 18W PD | USB C and USB A | Blue', 4, 2299, 200, 'Slim and lightweight 10000mAh power bank that slides easily into pockets and small bags. Capable of fast charging modern phones via USB C PD while still offering a legacy USB A port.'),
(153, 'seller002', 'LogiFlex NotePad Stand | Adjustable Tablet and Phone Stand | Aluminum | Foldable | Silver', 4, 1499, 170, 'Adjustable stand suited for tablets and large phones in portrait or landscape mode. Folds flat for transport and uses silicone pads to prevent slipping on glossy surfaces.'),
(154, 'seller002', 'LogiFlex NotePad Stand Pro | Heavy Duty Tablet Stand | Weighted Base | Rotation | Gray', 5, 2499, 100, 'Professional grade tablet stand with weighted base and 360 degree rotation for point of sale terminals, kitchens and studios. Holds tablets securely while allowing flexible viewing positions.'),
(155, 'seller003', 'KeyPro SilentMouse BT | Bluetooth Silent Mouse | 3 Level DPI | Compact | Gray', 4, 1599, 160, 'Compact Bluetooth mouse with silent primary buttons tailored for quiet offices and lecture halls. Three DPI presets suit both precise work and casual browsing.'),
(156, 'seller003', 'KeyPro SilentMouse BT Duo | Bluetooth and 2.4GHz Wireless Mouse | Silent | USB C Rechargeable | Black', 4, 1999, 140, 'Dual mode silent mouse that can pair via Bluetooth or included nano receiver. Rechargeable design eliminates the need for disposable batteries and supports quick top ups via USB C.'),
(157, 'seller004', 'SkyBoard CableSleeve Kit | 4 Pack Neoprene Cable Sleeves | Zipper Closure | Black', 4, 1299, 180, 'Set of flexible neoprene sleeves that bundle multiple cables into neat runs behind desks and TV units. Zipper design allows cables to be added or removed without disconnecting everything.'),
(158, 'seller004', 'SkyBoard CableSleeve Mixed | 4 Pack Cable Sleeves | Black and Gray | Hook Loop Closure', 4, 1199, 160, 'Mixed color cable sleeve kit with hook and loop closures for easily adjustable bundling. Ideal for temporary event setups and rental spaces where adhesive solutions are not preferred.'),
(159, 'seller005', 'NovaType Laptop CoolerMax | Dual Fan Laptop Cooling Pad | Adjustable Angle | RGB Edge | Black', 4, 2399, 140, 'Cooling pad with dual high airflow fans and adjustable height for gaming and workstation laptops. RGB edge lighting adds ambient glow while metal mesh surface improves heat dissipation.'),
(160, 'seller005', 'NovaType Laptop CoolerSlim | Single Fan Cooling Pad | Ultra Slim | USB Powered | Black', 4, 1599, 160, 'Slim cooling pad for everyday laptops with single quiet fan and USB powered operation. Lightweight design makes it easy to carry between home and office.'),
(161, 'seller006', 'WorkMate FileSorter | Desktop File Organizer | 5 Vertical Slots | Metal Mesh | Black', 4, 999, 200, 'Metal mesh organizer with five vertical sections for folders, notebooks and mail. Keeps frequently accessed documents upright and within reach on crowded desks.'),
(162, 'seller006', 'WorkMate FileSorter Plus | Desktop File Organizer | 5 Slots + Drawer | Black', 5, 1399, 150, 'Enhanced file sorter with five vertical slots and a small drawer for clips and sticky notes. Ideal for reception desks and home offices that need both document and small item storage.'),
(163, 'seller007', 'ProClick ScreenWipe Kit | Screen Cleaning Kit | 200ml Spray + Microfiber Cloth | Streak Free | For Monitors and Laptops', 4, 799, 220, 'Gentle cleaning solution formulated for anti glare and glossy screens. Includes plush microfiber cloth that removes fingerprints and dust without scratching displays or leaving streaks.'),
(164, 'seller007', 'ProClick ScreenWipe Travel | Pocket Screen Cleaning Spray | 30ml | Microfiber Pouch', 4, 599, 200, 'Travel sized screen cleaner designed for laptops, tablets and phones on the go. Comes with a microfiber pouch that doubles as a wipe for quick touchups.'),
(165, 'seller008', 'PixelPeak Portable SSD 500 | 500GB USB C Portable SSD | Up to 540MB s | Shock Resistant | Gray', 5, 6499, 120, 'Compact solid state drive that offers fast transfer speeds and robust shock resistance for photographers and traveling professionals. USB C interface includes USB A adapter for older systems.'),
(166, 'seller008', 'PixelPeak Portable SSD 1TB | 1TB USB C Portable SSD | Up to 540MB s | Gray', 5, 9499, 100, 'High capacity 1TB portable SSD for storing large video projects, RAW photo libraries and backups. Slim aluminum housing dissipates heat while remaining pocket friendly.'),
(167, 'seller009', 'EverydayCharge CableSet Trio | 3 in 1 Charging Cable | Lightning USB C Micro USB | 1.2m | Nylon Braided | Black', 4, 999, 260, 'Multi tip cable with Lightning, USB C and Micro USB connectors to charge multiple device types from one lead. Ideal for families and shared office charging stations.'),
(168, 'seller009', 'EverydayCharge CableSet Trio 2m | 3 in 1 Charging Cable | 2m Length | Nylon Braided | Gray', 4, 1199, 220, 'Longer 2m version of CableSet Trio that reaches from wall outlets to sofas and beds comfortably. Reinforced joints reduce fraying from frequent bending.'),
(169, 'seller010', 'NovaConnect USB C Ethernet Adapter | USB C to Gigabit Ethernet | Aluminum | Silver', 4, 1699, 180, 'Single port adapter that adds reliable wired network connectivity to thin laptops lacking an Ethernet jack. Aluminum shell complements modern notebooks and helps dissipate heat.'),
(170, 'seller010', 'NovaConnect USB C Ethernet + Hub | 3 Port USB Hub with Gigabit Ethernet | USB C | Gray', 5, 2399, 150, 'Multi function adapter that combines gigabit Ethernet with three USB ports, perfect for hot desking and conference rooms where stable network and multiple peripherals are needed.');

INSERT INTO Reviews (product_id, customer_username, rating, review) VALUES
(131, 'cust001', 4, 'Nice compact combo for my media PC. Trackpad gestures work well and keys are quiet.'),
(131, 'cust009', 4, 'Perfect size for the living room coffee table. Range is good even from the sofa.'),
(131, 'cust022', 3, 'Works fine but the touchpad is a bit small for detailed work.'),
(132, 'cust002', 5, 'Rechargeable battery and dual connectivity make this ideal for presentations.'),
(132, 'cust014', 5, 'I switch between smart TV and laptop with no issues. Battery lasts for weeks.'),
(132, 'cust031', 4, 'Excellent device though the glossy surface picks up fingerprints.'),
(133, 'cust003', 4, 'Comfortable mouse for daily office work. DPI switching is very handy.'),
(133, 'cust015', 4, 'Smooth tracking on my cloth pad and no connection drops so far.'),
(133, 'cust028', 3, 'Good mouse but the side buttons could be more pronounced.'),
(134, 'cust004', 4, 'RGB looks nice without being overwhelming. Great for casual gaming.'),
(134, 'cust021', 4, 'Plenty of buttons for in game macros. Wireless latency feels low.'),
(134, 'cust037', 3, 'Performs well but the software UI could be more intuitive.'),
(135, 'cust005', 4, 'Fits my 15 inch laptop almost perfectly and protects against crumbs.'),
(135, 'cust019', 4, 'Easy to wash and reapply. Keys remain clearly visible.'),
(135, 'cust034', 3, 'Does the job but slightly affects key feel when typing fast.'),
(136, 'cust006', 4, 'Smoke tint looks classy and still shows the backlit keys nicely.'),
(136, 'cust020', 4, 'Stopped dust build up on my keyboard. Cleaning is quick under running water.'),
(136, 'cust030', 3, 'Good cover but it takes a bit to sit completely flat after unboxing.'),
(137, 'cust007', 5, 'Charges both my phone and my partners device quickly on long drives.'),
(137, 'cust023', 5, 'Metal body feels premium and it sits nearly flush with the socket.'),
(137, 'cust036', 4, 'Great charger, only minor gripe is the bright indicator ring at night.'),
(138, 'cust008', 5, 'Dual USB C outputs are great for our modern phones. No more old cables.'),
(138, 'cust018', 5, 'Even on road trips with navigation and music, it keeps the phone topped up.'),
(138, 'cust039', 4, 'Works flawlessly though removal can be a little tricky due to the snug fit.'),
(139, 'cust009', 4, 'Extended WiFi to the far bedroom without much setup.'),
(139, 'cust017', 4, 'WPS pairing was fast. Speeds are good for streaming HD content.'),
(139, 'cust029', 3, 'Helps coverage but occasionally needs a reboot after several days.'),
(140, 'cust010', 5, 'WiFi 6 extender brought solid speeds to my gaming corner.'),
(140, 'cust024', 5, 'App interface is clean and makes tweaking settings easy.'),
(140, 'cust033', 4, 'Excellent performance, though the unit is bulkier than standard extenders.'),
(141, 'cust011', 4, 'Keeps pens and sticky notes under the monitor and off the main desk area.'),
(141, 'cust025', 4, 'Drawer glides smoothly and the plastic feels sturdy.'),
(141, 'cust032', 3, 'Good organizer but the top surface scuffs if not careful.'),
(142, 'cust012', 5, 'Bamboo top looks premium and matches my desk. Plenty of room in the drawer.'),
(142, 'cust026', 5, 'Nice blend of wood and white plastic. Great for small accessories.'),
(142, 'cust038', 4, 'Very functional, though the drawer handle could be slightly larger.'),
(143, 'cust013', 5, 'Sit stand riser completely changed how comfortable my day feels. Smooth lift motion.'),
(143, 'cust019', 5, 'Easily handles my 27 inch monitor and laptop together. Highly recommended.'),
(143, 'cust035', 4, 'Solid product, but it is heavy to move between rooms.'),
(144, 'cust014', 4, 'Compact size works well on my narrow desk. Lift handle is easy to use.'),
(144, 'cust027', 4, 'Great for alternating between standing and sitting during long calls.'),
(144, 'cust040', 3, 'Good but the keyboard platform is a little shallow for very deep keyboards.'),
(145, 'cust015', 4, 'Capture card works great for 1080p streaming. Setup was plug and play.'),
(145, 'cust020', 4, 'Low latency passthrough makes gaming while streaming very smooth.'),
(145, 'cust031', 3, 'Does the job but gets slightly warm after a few hours.'),
(146, 'cust016', 5, '4K passthrough and clean 1080p capture for my console. Perfect for content creation.'),
(146, 'cust022', 5, 'USB C connection is reliable and uses little CPU on my laptop.'),
(146, 'cust037', 4, 'Fantastic device, though the included HDMI cable is a bit short.'),
(147, 'cust017', 4, 'Now both my gaming headset and work headset have a proper home.'),
(147, 'cust028', 4, 'Stable base and cable hook keep things tidy.'),
(147, 'cust034', 3, 'Good stand but the arms could be slightly taller for very large headsets.'),
(148, 'cust018', 4, 'RGB base adds a nice glow and powers my wireless dongle via USB.'),
(148, 'cust029', 4, 'USB hub is convenient for plugging small drives in quickly.'),
(148, 'cust036', 3, 'Looks good, but lighting modes are limited compared to my keyboard.'),
(149, 'cust019', 5, 'Single cable to my laptop now drives two monitors and Ethernet. Super convenient.'),
(149, 'cust030', 5, 'Dock works flawlessly with my ultrabook and charges it at full speed.'),
(149, 'cust038', 4, 'Great dock, though it takes a moment to wake both monitors after sleep.'),
(150, 'cust020', 5, 'Full desktop replacement dock with more ports than I currently need. Rock solid so far.'),
(150, 'cust021', 5, 'Dual 4K output is crisp and stable. Ethernet is reliable for video calls.'),
(150, 'cust039', 4, 'Excellent dock but quite large, so best suited to permanent setups.'),
(151, 'cust001', 4, 'Charges my phone multiple times during trips. Feels sturdy in hand.'),
(151, 'cust023', 4, 'Good capacity and the multiple ports are useful at airports.'),
(151, 'cust029', 3, 'Works well but takes several hours to fully recharge the bank itself.'),
(152, 'cust002', 4, 'Slim enough to fit in my jeans pocket. PD charging is fast on my phone.'),
(152, 'cust024', 4, 'Perfect backup for daily commutes and meetings.'),
(152, 'cust033', 3, 'Nice bank but the plastic shell scratches a bit easily.'),
(153, 'cust003', 4, 'Handy stand for my tablet while cooking and following recipes.'),
(153, 'cust025', 4, 'Folds flat into my laptop sleeve and holds my phone vertically near my monitor.'),
(153, 'cust032', 3, 'Does the job but adjusting angles requires two hands.'),
(154, 'cust004', 5, 'Weighted base feels very stable, even with a large tablet attached.'),
(154, 'cust026', 5, 'Rotation is smooth and useful for client demos.'),
(154, 'cust040', 4, 'Great stand but occupies a bit of space on a narrow shelf.'),
(155, 'cust005', 4, 'Small silent mouse that is perfect for my travel kit.'),
(155, 'cust027', 4, 'Pairs quickly with my tablet and works without lag.'),
(155, 'cust035', 3, 'Comfortable for short sessions but a bit small for all day use.'),
(156, 'cust006', 4, 'Love the option to use either Bluetooth or the dongle. Silent clicks are a bonus.'),
(156, 'cust028', 4, 'Rechargeable via USB C means no more AA batteries on my desk.'),
(156, 'cust037', 3, 'Good mouse but the side finish gets slightly slippery over time.'),
(157, 'cust007', 4, 'Cable sleeves tidy up the mess behind my desk nicely.'),
(157, 'cust021', 4, 'Easy to wrap and zip around existing cables.'),
(157, 'cust031', 3, 'Works well but black only is a bit plain for open setups.'),
(158, 'cust008', 4, 'Hook and loop closures make it easy to readjust cable bundles.'),
(158, 'cust022', 4, 'Gray sleeves blend better with my wall color than black.'),
(158, 'cust034', 3, 'Good, but I would have liked slightly longer pieces.'),
(159, 'cust009', 4, 'Cooling pad dropped my gaming laptop temperatures a few degrees.'),
(159, 'cust019', 4, 'Fans are quiet and RGB adds a nice accent.'),
(159, 'cust036', 3, 'Works well but the USB pass through port feels a bit loose.'),
(160, 'cust010', 4, 'Slim pad that fits perfectly into my laptop bag. Fan is very quiet.'),
(160, 'cust023', 4, 'Helps keep my work laptop cool during long video calls.'),
(160, 'cust038', 3, 'Good cooling but angle adjustment options are limited.'),
(161, 'cust011', 4, 'File sorter cleared the clutter of loose folders on my desk.'),
(161, 'cust024', 4, 'Metal construction feels solid and slots are wide enough for thick binders.'),
(161, 'cust032', 3, 'Nice but the edges could be slightly smoother.'),
(162, 'cust012', 5, 'Extra drawer is great for sticky notes and clips. Very practical design.'),
(162, 'cust025', 5, 'Now my inbox, outbox and reference folders all have a place.'),
(162, 'cust039', 4, 'Excellent organizer though it takes some footprint on small desks.'),
(163, 'cust013', 4, 'Cleaning spray leaves my monitor spotless without streaks.'),
(163, 'cust026', 4, 'Microfiber cloth is thick and soft. Bottle should last a long time.'),
(163, 'cust033', 3, 'Works well but the spray nozzle is a bit stiff.'),
(164, 'cust014', 4, 'Travel spray is perfect for wiping my phone and laptop on the go.'),
(164, 'cust027', 4, 'Microfiber pouch is clever and doubles as a small case.'),
(164, 'cust035', 3, 'Good cleaner but the bottle could be slightly larger.'),
(165, 'cust015', 5, 'Extremely fast SSD for editing photos directly from the drive.'),
(165, 'cust028', 5, 'Tiny and robust. Survived a few bumps in my camera bag without issues.'),
(165, 'cust037', 4, 'Great performance, though the cable could be a bit longer.'),
(166, 'cust016', 5, '1TB capacity is perfect for my 4K video projects.'),
(166, 'cust029', 5, 'Transfer speeds are consistently high on both Mac and Windows.'),
(166, 'cust038', 4, 'Excellent SSD, just warms up slightly during long copy operations.'),
(167, 'cust017', 4, 'One cable in the car now charges all our different devices.'),
(167, 'cust021', 4, 'Braided outer layer feels durable and tangle resistant.'),
(167, 'cust030', 3, 'Versatile but charging speed is a bit slower when all tips are used heavily.'),
(168, 'cust018', 4, 'Extra length makes it easy to reach the sofa from the wall socket.'),
(168, 'cust022', 4, 'Great cable for bedside charging with different connectors.'),
(168, 'cust034', 3, 'Good overall but the adapter heads are slightly bulky.'),
(169, 'cust019', 4, 'Simple adapter that gives my ultrabook a reliable wired connection.'),
(169, 'cust023', 4, 'Works plug and play on both Windows and Linux.'),
(169, 'cust036', 3, 'Performs well but gets a little warm under sustained transfers.'),
(170, 'cust020', 5, 'Perfect little hub for hotel stays and coworking spaces.'),
(170, 'cust024', 5, 'Ethernet plus three USB ports from one USB C is very convenient.'),
(170, 'cust039', 4, 'Great travel adapter though the attached cable is somewhat short.');


INSERT INTO Products (product_id, seller_username, name, rating, price, quantity, description) VALUES
(171, 'seller011', 'EliteDesk CableTray UnderMount | Under Desk Cable Management Tray | Steel Mesh | Black', 4, 2499, 150,
 'Steel mesh under-desk tray that keeps power strips and cables suspended neatly out of sight. Ideal for standing desks and multi-monitor setups where cable clutter builds quickly.'),

(172, 'seller011', 'EliteDesk CableTray UnderMount XL | Extra Wide Cable Management Tray | 80cm | Black', 5, 2999, 140,
 'Extra wide version of the UnderMount tray suitable for heavy setups with multiple adapters, docking stations and surge protectors. Durable steel construction with ventilated pattern to reduce heat buildup.'),

(173, 'seller012', 'HomeOffice FootRest ErgoLift | Adjustable Foot Rest | Memory Foam Top | Anti Slip Base | Black', 4, 1999, 180,
 'Ergonomic footrest with memory foam top and adjustable tilt positions to improve posture and leg comfort during long office sessions. Anti-slip base keeps it firmly planted on hardwood and carpet.'),

(174, 'seller012', 'HomeOffice FootRest ErgoLift Mesh | Breathable Mesh Foot Rest | Tilt Adjustable | Gray', 4, 1899, 160,
 'Breathable mesh fabric footrest designed for warm climates and long work hours. Lightweight yet stable frame supports multiple height and tilt adjustments for personalized comfort.'),

(175, 'seller013', 'CloudEdge USB Mic StreamLite | USB Condenser Microphone | Cardioid | Mute Button | Tripod Stand | Black', 4, 3999, 110,
 'Plug-and-play USB microphone suitable for streaming, podcasting and video calls. Cardioid pattern captures clear voice with reduced background noise. Includes mute button and tripod desk stand.'),

(176, 'seller013', 'CloudEdge USB Mic StreamPro | USB Condenser Microphone | Gain Control | Pop Filter | Boom Arm | Black', 5, 6299, 80,
 'Professional USB microphone kit with adjustable boom arm, metal pop filter and onboard gain control. Designed for creators requiring crisp vocal capture for narration and livestreams.'),

(177, 'seller014', 'SmartChoice MonitorLight Bar | LED Monitor Light | Auto Dim | USB Powered | Black', 4, 2699, 150,
 'LED monitor light bar that illuminates the desk without screen glare. Auto-dimming sensor adjusts brightness based on ambient light, improving nighttime productivity and reducing eye strain.'),

(178, 'seller014', 'SmartChoice MonitorLight Bar Pro | LED Light Bar | Warm Cool Adjustable | Touch Controls | Black', 5, 3299, 130,
 'Premium monitor light bar with adjustable color temperature and touch-sensitive controls. Perfect for designers and office workers who need flexible lighting for extended screen sessions.'),

(179, 'seller015', 'ConnectIT HDMI Switch 3x1 | 3 Input HDMI Switch | 4K 60Hz | Remote Control | Black', 4, 2299, 170,
 '3-input HDMI switch that allows quick switching between consoles, laptops and media players. Supports 4K 60Hz output and includes IR remote for couch-friendly operation.'),

(180, 'seller015', 'ConnectIT HDMI Switch 5x1 Pro | 5 Input HDMI Switch | 4K HDR | Remote | Aluminum Housing', 5, 3199, 140,
 'Professional grade 5-input HDMI switch with HDR support, metal housing for heat dissipation and responsive IR remote. Great for home theaters and multi-device streaming setups.');

INSERT INTO Reviews (product_id, customer_username, rating, review) VALUES
(171, 'cust001', 4, 'Cleared a ton of cables from under my desk. Installation took just a few minutes.'),
(171, 'cust018', 4, 'Strong metal frame and holds my power strip securely.'),
(171, 'cust032', 3, 'Works but could be slightly deeper for larger adapters.'),

(172, 'cust005', 5, 'Huge tray! Finally enough space for all my adapters and a docking station.'),
(172, 'cust024', 5, 'Solid build and perfect fit for my standing desk.'),
(172, 'cust037', 4, 'Excellent capacity but requires two people to mount comfortably.'),

(173, 'cust002', 4, 'Memory foam feels great and reduces leg fatigue.'),
(173, 'cust022', 4, 'Lightweight and comfortable. Angle adjustments are handy.'),
(173, 'cust035', 3, 'Good but shifts a bit on smooth floors.'),

(174, 'cust003', 4, 'Mesh surface stays cool even after hours of use.'),
(174, 'cust019', 4, 'Nice flex and tilt range. Helps my posture.'),
(174, 'cust034', 3, 'Comfortable but not as cushioned as foam models.'),

(175, 'cust004', 4, 'Audio quality is clear for calls and streaming. Easy setup.'),
(175, 'cust020', 4, 'Great budget mic with decent clarity. Tripod is stable.'),
(175, 'cust039', 3, 'Good value but picks up keyboard noise if too close.'),

(176, 'cust006', 5, 'Boom arm and pop filter make a huge difference for my streams.'),
(176, 'cust025', 5, 'Excellent microphone for the price. Gain control is very useful.'),
(176, 'cust030', 4, 'Great mic though the boom arm clamps tightly on thick desks.'),

(177, 'cust007', 4, 'Really helps reduce eye strain in the evenings.'),
(177, 'cust024', 4, 'Auto dimming works flawlessly. Sleek and simple design.'),
(177, 'cust033', 3, 'Bright enough but cable could be longer.'),

(178, 'cust008', 5, 'Color temp adjustment is perfect for editing photos.'),
(178, 'cust026', 5, 'Best lighting upgrade for my workspace. Touch controls are smooth.'),
(178, 'cust038', 4, 'High quality though slightly pricey.'),

(179, 'cust009', 4, 'Switches fast between my console and laptop. Remote works well.'),
(179, 'cust027', 4, 'Great little switch for my TV setup.'),
(179, 'cust031', 3, 'Works fine but LEDs are a little bright at night.'),

(180, 'cust010', 5, 'Handles all my HDMI devices including my 4K console.'),
(180, 'cust028', 5, 'Metal body feels premium and reduces heat.'),
(180, 'cust036', 4, 'Reliable switch but remote response could be slightly quicker.');

DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS customers;
CREATE TABLE customers (id INT PRIMARY KEY, name VARCHAR(100) NOT NULL, city VARCHAR(50), signup_date DATE) ENGINE=InnoDB;
CREATE TABLE products (id INT PRIMARY KEY, name VARCHAR(100) NOT NULL, category VARCHAR(30), price DECIMAL(8,2)) ENGINE=InnoDB;
CREATE TABLE orders (id INT PRIMARY KEY, customer_id INT NOT NULL, order_date DATE NOT NULL, status VARCHAR(20) NOT NULL, FOREIGN KEY (customer_id) REFERENCES customers(id), INDEX idx_orders_customer (customer_id), INDEX idx_orders_date (order_date)) ENGINE=InnoDB;
CREATE TABLE order_items (order_id INT NOT NULL, product_id INT NOT NULL, quantity INT NOT NULL, PRIMARY KEY (order_id, product_id), FOREIGN KEY (order_id) REFERENCES orders(id), FOREIGN KEY (product_id) REFERENCES products(id)) ENGINE=InnoDB

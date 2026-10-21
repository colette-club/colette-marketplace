CREATE TABLE orders (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  customer_id BIGINT NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'open',
  total_cents BIGINT NOT NULL DEFAULT 0
) ENGINE=InnoDB;

CREATE TABLE products (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(200) NOT NULL,
  stock INT NOT NULL,
  price_cents BIGINT NOT NULL
) ENGINE=InnoDB;

CREATE TABLE catalogue_prices (
  product_id BIGINT PRIMARY KEY,
  price_cents BIGINT NOT NULL,
  FOREIGN KEY (product_id) REFERENCES products (id)
) ENGINE=InnoDB;

CREATE TABLE order_lines (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  order_id BIGINT NOT NULL,
  product_id BIGINT NOT NULL,
  quantity INT NOT NULL,
  price_cents BIGINT NOT NULL,
  FOREIGN KEY (order_id) REFERENCES orders (id),
  FOREIGN KEY (product_id) REFERENCES products (id)
) ENGINE=InnoDB;

-- Created by Redgate Data Modeler (https://datamodeler.redgate-platform.com)
-- Last modification date: 2025-12-21 19:13:42.297

-- tables
-- Table: categories_for_part
CREATE TABLE categories_for_part (
    category_id int  NOT NULL IDENTITY(1, 1),
    name nvarchar(100)  NOT NULL,
    CONSTRAINT categories_for_part_pk PRIMARY KEY  (category_id)
);

CREATE UNIQUE INDEX categories_for_part_idx_1 on categories_for_part (name ASC);

-- Table: categories_for_product
CREATE TABLE categories_for_product (
    category_id int  NOT NULL IDENTITY(1, 1),
    name nvarchar(100)  NOT NULL,
    CONSTRAINT categories_for_product_pk PRIMARY KEY  (category_id)
);

CREATE UNIQUE INDEX categories_for_product_idx_1 on categories_for_product (name ASC);

-- Table: clients
CREATE TABLE clients (
    client_id int  NOT NULL IDENTITY(1, 1), -- Zmieniono na (1, 1) zgodnie z prośbą
    email nvarchar(150)  NOT NULL,
    phone nvarchar(12)  NOT NULL,
    city nvarchar(100)  NOT NULL,
    address nvarchar(150)  NOT NULL,
    city_code nvarchar(10)  NOT NULL,
    CONSTRAINT check_clients CHECK (((phone LIKE '[0-9]%' AND phone NOT LIKE '%[^0-9]%')  OR  (phone LIKE '+[0-9]%' AND SUBSTRING(phone, 2, 12) NOT LIKE '%[^0-9]%') ) and email LIKE '_%@_%.%_'),
    CONSTRAINT clients_pk PRIMARY KEY  (client_id)
);

CREATE UNIQUE INDEX clients_idx_1 on clients (phone ASC,email ASC);

-- Table: clients_company
CREATE TABLE clients_company (
    client_id int  NOT NULL, -- PK jest jednocześnie FK (relacja 1:1), IDENTITY nie jest stosowane
    company_name nvarchar(255)  NOT NULL,
    nip nvarchar(10)  NOT NULL,
    CONSTRAINT clients_company_pk PRIMARY KEY  (client_id)
);

CREATE UNIQUE INDEX clients_company_idx_1 on clients_company (company_name ASC,nip ASC);

-- Table: clients_individual
CREATE TABLE clients_individual (
    client_id int  NOT NULL, -- PK jest jednocześnie FK (relacja 1:1), IDENTITY nie jest stosowane
    first_name nvarchar(100)  NOT NULL,
    last_name nvarchar(100)  NOT NULL,
    CONSTRAINT clients_individual_pk PRIMARY KEY  (client_id)
);

-- Table: employee_time_offs
CREATE TABLE employee_time_offs (
    employee_id int  NOT NULL,
    start_date date  NOT NULL,
    end_date date  NOT NULL,
    reason nvarchar(255)  NOT NULL,
    CONSTRAINT check_employee_time_offs CHECK (end_date >= start_date),
    CONSTRAINT employee_time_offs_pk PRIMARY KEY  (employee_id,start_date)
);

-- Table: employees
CREATE TABLE employees (
    employee_id int  NOT NULL IDENTITY(1, 1),
    first_name nvarchar(100)  NOT NULL,
    last_name nvarchar(100)  NOT NULL,
    base_salary money  NOT NULL,
    is_active bit  NOT NULL,
    role_id int  NOT NULL,
    supervisor_id int  NULL,
    hired_date date  NOT NULL,
    email nvarchar(150)  NOT NULL,
    phone nvarchar(20)  NOT NULL,
    CONSTRAINT check_employees CHECK (base_salary >= 0 and ( (phone LIKE '[0-9]%' AND phone NOT LIKE '%[^0-9]%')  OR  (phone LIKE '+[0-9]%' AND SUBSTRING(phone, 2, 12) NOT LIKE '%[^0-9]%') ) and email LIKE '_%@_%.%_'),
    CONSTRAINT employees_pk PRIMARY KEY  (employee_id)
);

CREATE UNIQUE INDEX employees_idx_1 on employees (email ASC,phone ASC);

-- Table: inventory_parts
CREATE TABLE inventory_parts (
    part_id int  NOT NULL, -- PK jest jednocześnie FK (relacja 1:1 z parts), IDENTITY nie jest stosowane
    available_units int  NOT NULL DEFAULT 0,
    min_units int  NOT NULL,
    max_units int  NOT NULL,
    CONSTRAINT check_inventory_parts CHECK (available_units >= 0 and min_units >= 0),
    CONSTRAINT inventory_parts_pk PRIMARY KEY  (part_id)
);

-- Table: inventory_products
CREATE TABLE inventory_products (
    product_id int  NOT NULL, -- PK jest jednocześnie FK (relacja 1:1 z products), IDENTITY nie jest stosowane
    available_units int  NOT NULL DEFAULT 0,
    min_units int  NOT NULL,
    max_units int  NOT NULL,
    CONSTRAINT check_inventory_products CHECK (available_units >= 0 and min_units >= 0),
    CONSTRAINT inventory_products_pk PRIMARY KEY  (product_id)
);

-- Table: order_details
CREATE TABLE order_details (
    item_id int  NOT NULL IDENTITY(1, 1),
    order_id int  NOT NULL,
    product_id int  NOT NULL,
    quantity int  NOT NULL,
    unit_price money  NOT NULL,
    CONSTRAINT check_order_details CHECK (quantity > 0 and unit_price >= 0),
    CONSTRAINT order_items_pk PRIMARY KEY  (item_id)
);

-- Table: order_parts
CREATE TABLE order_parts (
    order_part_id int  NOT NULL IDENTITY(1, 1), -- Dodano IDENTITY
    offer_id int  NOT NULL,
    order_date date  NOT NULL,
    pack_quantity int  NOT NULL,
    order_delivered date  NULL,
    CONSTRAINT check_order_parts CHECK (order_date <= order_delivered and pack_quantity > 0),
    CONSTRAINT order_parts_pk PRIMARY KEY  (order_part_id)
);

-- Table: order_status
CREATE TABLE order_status (
    order_status_id int  NOT NULL IDENTITY(1, 1), -- Dodano IDENTITY
    order_id int  NOT NULL,
    status_id int  NOT NULL,
    start_date datetime  NOT NULL,
    planned_end_date datetime  NOT NULL,
    end_date datetime  NULL,
    CONSTRAINT check_order_status CHECK (start_date <= planned_end_date),
    CONSTRAINT order_status_pk PRIMARY KEY  (order_status_id)
);

-- Table: orders
CREATE TABLE orders (
    order_id int  NOT NULL IDENTITY(1, 1),
    shipper_id int  NOT NULL,
    order_date datetime  NOT NULL DEFAULT getdate(),
    delivery_city nvarchar(100)  NOT NULL,
    delivery_address nvarchar(150)  NOT NULL,
    supervisor_id int  NOT NULL,
    order_discount decimal(3,2)  NOT NULL,
    client_id int  NOT NULL,
    delivery_city_code nvarchar(10)  NOT NULL,
    CONSTRAINT check_orders CHECK (order_discount >= 0 and order_discount <= 1),
    CONSTRAINT orders_pk PRIMARY KEY  (order_id)
);

-- Table: parts
CREATE TABLE parts (
    part_id int  NOT NULL IDENTITY(1, 1),
    part_name nvarchar(255)  NOT NULL,
    category_id int  NOT NULL,
    unit_space_needed int  NOT NULL DEFAULT 1,
    CONSTRAINT check_parts CHECK (unit_space_needed > 0),
    CONSTRAINT parts_pk PRIMARY KEY  (part_id)
);

-- Table: payments
CREATE TABLE payments (
    payment_id int  NOT NULL IDENTITY(1, 1),
    order_id int  NOT NULL,
    amount money  NOT NULL,
    payment_date datetime  NOT NULL,
    CONSTRAINT check_payments CHECK (amount >= 0),
    CONSTRAINT payments_pk PRIMARY KEY  (payment_id)
);

-- Table: product_recipes
CREATE TABLE product_recipes (
    product_id int  NOT NULL,
    part_id int  NOT NULL,
    quantity_needed int  NOT NULL,
    CONSTRAINT check_product_recipies CHECK (quantity_needed > 0),
    CONSTRAINT product_recipes_pk PRIMARY KEY  (product_id,part_id)
);

-- Table: production_status
CREATE TABLE production_status (
    production_status_id int  NOT NULL IDENTITY(1, 1), -- Dodano IDENTITY
    production_id int  NOT NULL,
    status_id int  NOT NULL,
    start_date datetime  NOT NULL,
    planned_end_date datetime  NOT NULL,
    end_date datetime  NULL,
    CONSTRAINT check_production_status CHECK (start_date <= planned_end_date),
    CONSTRAINT production_status_pk PRIMARY KEY  (production_status_id)
);

-- Table: production_team_assignments
CREATE TABLE production_team_assignments (
    production_id int  NOT NULL,
    employee_id int  NOT NULL,
    hours_logged int  NOT NULL,
    CONSTRAINT check_production_team_assignments CHECK (hours_logged >= 0),
    CONSTRAINT production_team_assignments_pk PRIMARY KEY  (production_id,employee_id)
);

-- Table: productions
CREATE TABLE productions (
    production_id int  NOT NULL IDENTITY(1, 1), -- Dodano IDENTITY
    product_id int  NOT NULL,
    quantity int  NOT NULL,
    work_place_id int  NULL,
    supervisor_id int  NOT NULL,
    CONSTRAINT check_productions CHECK (quantity > 0),
    CONSTRAINT productions_pk PRIMARY KEY  (production_id)
);

-- Table: products
CREATE TABLE products (
    product_id int  NOT NULL IDENTITY(1, 1),
    product_name nvarchar(255)  NOT NULL,
    base_price money  NOT NULL,
    unit_space_needed int  NOT NULL DEFAULT 1,
    is_active bit  NOT NULL DEFAULT 1,
    category_id int  NOT NULL,
    needed_hours int  NOT NULL,
    CONSTRAINT check_products CHECK (unit_space_needed >= 0 and needed_hours >= 0 and base_price >= 0),
    CONSTRAINT products_pk PRIMARY KEY  (product_id)
);

-- Table: products_vat
CREATE TABLE products_vat (
    product_id int  NOT NULL,
    vat_id int  NOT NULL,
    start_date date  NOT NULL,
    end_date date  NULL,
    CONSTRAINT check_products_vat CHECK (start_date <= end_date),
    CONSTRAINT products_vat_pk PRIMARY KEY  (product_id,vat_id,start_date)
);

-- Table: roles
CREATE TABLE roles (
    role_id int  NOT NULL IDENTITY(1, 1),
    possition_name nvarchar(150)  NOT NULL,
    description nvarchar(255)  NOT NULL,
    CONSTRAINT roles_pk PRIMARY KEY  (role_id)
);

CREATE UNIQUE INDEX roles_idx_1 on roles (possition_name ASC);

-- Table: shippers
CREATE TABLE shippers (
    shipper_id int  NOT NULL IDENTITY(1, 1),
    company_name nvarchar(255)  NOT NULL,
    email varchar(150)  NOT NULL,
    CONSTRAINT shippers_pk PRIMARY KEY  (shipper_id)
);

CREATE UNIQUE INDEX shippers_idx_1 on shippers (company_name ASC);

-- Table: status_for_order
CREATE TABLE status_for_order (
    status_id int  NOT NULL IDENTITY(1, 1), -- Dodano IDENTITY
    status_name nvarchar(30)  NOT NULL,
    CONSTRAINT status_for_order_pk PRIMARY KEY  (status_id)
);

CREATE UNIQUE INDEX status_for_order_idx_1 on status_for_order (status_name ASC);

-- Table: status_for_production
CREATE TABLE status_for_production (
    status_id int  NOT NULL IDENTITY(1, 1), -- Dodano IDENTITY
    status_name nvarchar(30)  NOT NULL,
    CONSTRAINT status_for_production_pk PRIMARY KEY  (status_id)
);

CREATE UNIQUE INDEX status_for_production_idx_1 on status_for_production (status_name ASC);

-- Table: supplier_offers
CREATE TABLE supplier_offers (
    offer_id int  NOT NULL IDENTITY(1, 1),
    supplier_id int  NOT NULL,
    part_id int  NOT NULL,
    price money  NOT NULL,
    delivery_days int  NOT NULL,
    pack_size int  NOT NULL DEFAULT 1,
    CONSTRAINT check_supplier_offers CHECK (price >= 0 and delivery_days >= 0 and pack_size > 0),
    CONSTRAINT supplier_offers_pk PRIMARY KEY  (offer_id)
);

-- Table: suppliers
CREATE TABLE suppliers (
    supplier_id int  NOT NULL IDENTITY(1, 1),
    company_name nvarchar(255)  NOT NULL,
    email nvarchar(150)  NOT NULL,
    CONSTRAINT check_suppliers CHECK (email LIKE '_%@_%.%_'),
    CONSTRAINT suppliers_pk PRIMARY KEY  (supplier_id)
);

CREATE UNIQUE INDEX suppliers_idx_1 on suppliers (company_name ASC,email ASC);

-- Table: vat
CREATE TABLE vat (
    vat_id int  NOT NULL IDENTITY(1, 1), -- Dodano IDENTITY
    amount decimal(3,2)  NOT NULL,
    CONSTRAINT check_vat CHECK (amount >= 0 and amount <= 1),
    CONSTRAINT vat_pk PRIMARY KEY  (vat_id)
);

-- Table: work_places
CREATE TABLE work_places (
    work_place_id int  NOT NULL IDENTITY(1, 1), -- Dodano IDENTITY
    work_place_description nvarchar(255)  NOT NULL,
    CONSTRAINT work_places_pk PRIMARY KEY  (work_place_id)
);


-- foreign keys
-- Reference: FK_1 (table: parts)
ALTER TABLE parts ADD CONSTRAINT FK_1
    FOREIGN KEY (category_id)
    REFERENCES categories_for_part (category_id);

-- Reference: FK_11 (table: order_details)
ALTER TABLE order_details ADD CONSTRAINT FK_11
    FOREIGN KEY (order_id)
    REFERENCES orders (order_id);

-- Reference: FK_12 (table: order_details)
ALTER TABLE order_details ADD CONSTRAINT FK_12
    FOREIGN KEY (product_id)
    REFERENCES products (product_id);

-- Reference: FK_15 (table: payments)
ALTER TABLE payments ADD CONSTRAINT FK_15
    FOREIGN KEY (order_id)
    REFERENCES orders (order_id);

-- Reference: FK_16 (table: supplier_offers)
ALTER TABLE supplier_offers ADD CONSTRAINT FK_16
    FOREIGN KEY (supplier_id)
    REFERENCES suppliers (supplier_id);

-- Reference: FK_17 (table: supplier_offers)
ALTER TABLE supplier_offers ADD CONSTRAINT FK_17
    FOREIGN KEY (part_id)
    REFERENCES parts (part_id);

-- Reference: FK_2 (table: product_recipes)
ALTER TABLE product_recipes ADD CONSTRAINT FK_2
    FOREIGN KEY (product_id)
    REFERENCES products (product_id);

-- Reference: FK_3 (table: product_recipes)
ALTER TABLE product_recipes ADD CONSTRAINT FK_3
    FOREIGN KEY (part_id)
    REFERENCES parts (part_id);

-- Reference: FK_4 (table: inventory_parts)
ALTER TABLE inventory_parts ADD CONSTRAINT FK_4
    FOREIGN KEY (part_id)
    REFERENCES parts (part_id);

-- Reference: FK_6 (table: inventory_products)
ALTER TABLE inventory_products ADD CONSTRAINT FK_6
    FOREIGN KEY (product_id)
    REFERENCES products (product_id);

-- Reference: FK_9 (table: orders)
ALTER TABLE orders ADD CONSTRAINT FK_9
    FOREIGN KEY (shipper_id)
    REFERENCES shippers (shipper_id);

-- Reference: clients_company_clients (table: clients_company)
ALTER TABLE clients_company ADD CONSTRAINT clients_company_clients
    FOREIGN KEY (client_id)
    REFERENCES clients (client_id);

-- Reference: clients_individual_clients (table: clients_individual)
ALTER TABLE clients_individual ADD CONSTRAINT clients_individual_clients
    FOREIGN KEY (client_id)
    REFERENCES clients (client_id);

-- Reference: employee_time_off_employees (table: employee_time_offs)
ALTER TABLE employee_time_offs ADD CONSTRAINT employee_time_off_employees
    FOREIGN KEY (employee_id)
    REFERENCES employees (employee_id);

-- Reference: employees_employees (table: employees)
ALTER TABLE employees ADD CONSTRAINT employees_employees
    FOREIGN KEY (supervisor_id)
    REFERENCES employees (employee_id);

-- Reference: employees_roles (table: employees)
ALTER TABLE employees ADD CONSTRAINT employees_roles
    FOREIGN KEY (role_id)
    REFERENCES roles (role_id);

-- Reference: order_parts_supplier_offers (table: order_parts)
ALTER TABLE order_parts ADD CONSTRAINT order_parts_supplier_offers
    FOREIGN KEY (offer_id)
    REFERENCES supplier_offers (offer_id);

-- Reference: order_status_orders (table: order_status)
ALTER TABLE order_status ADD CONSTRAINT order_status_orders
    FOREIGN KEY (order_id)
    REFERENCES orders (order_id);

-- Reference: order_status_status (table: order_status)
ALTER TABLE order_status ADD CONSTRAINT order_status_status
    FOREIGN KEY (status_id)
    REFERENCES status_for_order (status_id);

-- Reference: orders_clients (table: orders)
ALTER TABLE orders ADD CONSTRAINT orders_clients
    FOREIGN KEY (client_id)
    REFERENCES clients (client_id);

-- Reference: orders_employees (table: orders)
ALTER TABLE orders ADD CONSTRAINT orders_employees
    FOREIGN KEY (supervisor_id)
    REFERENCES employees (employee_id);

-- Reference: production_employees (table: productions)
ALTER TABLE productions ADD CONSTRAINT production_employees
    FOREIGN KEY (supervisor_id)
    REFERENCES employees (employee_id);

-- Reference: production_production_status (table: production_status)
ALTER TABLE production_status ADD CONSTRAINT production_production_status
    FOREIGN KEY (production_id)
    REFERENCES productions (production_id);

-- Reference: production_products (table: productions)
ALTER TABLE productions ADD CONSTRAINT production_products
    FOREIGN KEY (product_id)
    REFERENCES products (product_id);

-- Reference: production_status_production_status (table: production_status)
ALTER TABLE production_status ADD CONSTRAINT production_status_production_status
    FOREIGN KEY (status_id)
    REFERENCES status_for_production (status_id);

-- Reference: production_team_assignments_employees (table: production_team_assignments)
ALTER TABLE production_team_assignments ADD CONSTRAINT production_team_assignments_employees
    FOREIGN KEY (employee_id)
    REFERENCES employees (employee_id);

-- Reference: production_team_assignments_production (table: production_team_assignments)
ALTER TABLE production_team_assignments ADD CONSTRAINT production_team_assignments_production
    FOREIGN KEY (production_id)
    REFERENCES productions (production_id);

-- Reference: production_work_places (table: productions)
ALTER TABLE productions ADD CONSTRAINT production_work_places
    FOREIGN KEY (work_place_id)
    REFERENCES work_places (work_place_id);

-- Reference: products_product_categories (table: products)
ALTER TABLE products ADD CONSTRAINT products_product_categories
    FOREIGN KEY (category_id)
    REFERENCES categories_for_product (category_id);

-- Reference: products_vat_products (table: products_vat)
ALTER TABLE products_vat ADD CONSTRAINT products_vat_products
    FOREIGN KEY (product_id)
    REFERENCES products (product_id);

-- Reference: products_vat_vat (table: products_vat)
ALTER TABLE products_vat ADD CONSTRAINT products_vat_vat
    FOREIGN KEY (vat_id)
    REFERENCES vat (vat_id);

-- End of file.


BULK INSERT dbo.categories_for_part
FROM 'C:\sciezka_do_katalogu_z_csv\categories_for_part.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,        -- pomija nagłówki
    FIELDTERMINATOR = ',', -- lub ';' zależnie od Twojego CSV
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001'    -- kodowanie UTF-8 (ważne dla polskich znaków)
);

BULK INSERT dbo.categories_for_product
FROM 'C:\sciezka_do_katalogu_z_csv\categories_for_product.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,        -- pomija nagłówki
    FIELDTERMINATOR = ',', -- lub ';' zależnie od Twojego CSV
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001'    -- kodowanie UTF-8 (ważne dla polskich znaków)
);

BULK INSERT dbo.clients
FROM 'C:\sciezka_do_katalogu_z_csv\clients.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,        -- pomija nagłówki
    FIELDTERMINATOR = ',', -- lub ';' zależnie od Twojego CSV
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001'    -- kodowanie UTF-8 (ważne dla polskich znaków)
);

BULK INSERT dbo.clients_company
FROM 'C:\sciezka_do_katalogu_z_csv\clients_company.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,        -- pomija nagłówki
    FIELDTERMINATOR = ',', -- lub ';' zależnie od Twojego CSV
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001'    -- kodowanie UTF-8 (ważne dla polskich znaków)
);

BULK INSERT dbo.clients_individual
FROM 'C:\sciezka_do_katalogu_z_csv\clients_individual.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,        -- pomija nagłówki
    FIELDTERMINATOR = ',', -- lub ';' zależnie od Twojego CSV
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001'    -- kodowanie UTF-8 (ważne dla polskich znaków)
);


BULK INSERT dbo.work_places
FROM 'C:\sciezka_do_katalogu_z_csv\work_places.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,        -- pomija nagłówki
    FIELDTERMINATOR = ',', -- lub ';' zależnie od Twojego CSV
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001'    -- kodowanie UTF-8 (ważne dla polskich znaków)
);

BULK INSERT dbo.vat
FROM 'C:\sciezka_do_katalogu_z_csv\vat.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,        -- pomija nagłówki
    FIELDTERMINATOR = ',', -- lub ';' zależnie od Twojego CSV
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001'    -- kodowanie UTF-8 (ważne dla polskich znaków)
);

BULK INSERT dbo.suppliers
FROM 'C:\sciezka_do_katalogu_z_csv\suppliers.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,        -- pomija nagłówki
    FIELDTERMINATOR = ',', -- lub ';' zależnie od Twojego CSV
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001'    -- kodowanie UTF-8 (ważne dla polskich znaków)
);

BULK INSERT dbo.status_for_production
FROM 'C:\sciezka_do_katalogu_z_csv\status_for_production.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,        -- pomija nagłówki
    FIELDTERMINATOR = ',', -- lub ';' zależnie od Twojego CSV
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001'    -- kodowanie UTF-8 (ważne dla polskich znaków)
);

BULK INSERT dbo.status_for_order
FROM 'C:\sciezka_do_katalogu_z_csv\status_for_order.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,        -- pomija nagłówki
    FIELDTERMINATOR = ',', -- lub ';' zależnie od Twojego CSV
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001'    -- kodowanie UTF-8 (ważne dla polskich znaków)
);

BULK INSERT dbo.roles
FROM 'C:\sciezka_do_katalogu_z_csv\roles.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,        -- pomija nagłówki
    FIELDTERMINATOR = ',', -- lub ';' zależnie od Twojego CSV
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001'    -- kodowanie UTF-8 (ważne dla polskich znaków)
);

BULK INSERT dbo.shippers
FROM 'C:\sciezka_do_katalogu_z_csv\shippers.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,        -- pomija nagłówki
    FIELDTERMINATOR = ',', -- lub ';' zależnie od Twojego CSV
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001'    -- kodowanie UTF-8 (ważne dla polskich znaków)
);

BULK INSERT dbo.orders
FROM 'C:\sciezka_do_katalogu_z_csv\orders.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,        -- pomija nagłówki
    FIELDTERMINATOR = ',', -- lub ';' zależnie od Twojego CSV
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001'    -- kodowanie UTF-8 (ważne dla polskich znaków)
);

BULK INSERT dbo.order_status
FROM 'C:\sciezka_do_katalogu_z_csv\order_status.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,        -- pomija nagłówki
    FIELDTERMINATOR = ',', -- lub ';' zależnie od Twojego CSV
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001'    -- kodowanie UTF-8 (ważne dla polskich znaków)
);

BULK INSERT dbo.parts
FROM 'C:\sciezka_do_katalogu_z_csv\parts.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001'
);

BULK INSERT dbo.products
FROM 'C:\sciezka_do_katalogu_z_csv\products.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001'
);

BULK INSERT dbo.product_recipes
FROM 'C:\sciezka_do_katalogu_z_csv\product_recipes.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001'
);

BULK INSERT dbo.employees
FROM 'C:\sciezka_do_katalogu_z_csv\employees.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001'
);

BULK INSERT dbo.productions
FROM 'C:\sciezka_do_katalogu_z_csv\productions.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001'
);

BULK INSERT dbo.employee_time_offs
FROM 'C:\sciezka_do_katalogu_z_csv\employee_time_offs.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001'
);


/*to validate!!*/
BULK INSERT dbo.inventory_parts
FROM 'C:\sciezka_do_katalogu_z_csv\inventory_parts.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001'
);
BULK INSERT dbo.inventory_products
FROM 'C:\sciezka_do_katalogu_z_csv\inventory_products.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001'
);



BULK INSERT dbo.products_vat
FROM 'C:\sciezka_do_katalogu_z_csv\products_vat.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001'
);

BULK INSERT dbo.production_team_assignments
FROM 'C:\sciezka_do_katalogu_z_csv\production_team_assignments.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001'
);

BULK INSERT dbo.payments
FROM 'C:\sciezka_do_katalogu_z_csv\payments.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001'
);

BULK INSERT dbo.order_details
FROM 'C:\sciezka_do_katalogu_z_csv\order_details.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001'
);

BULK INSERT dbo.supplier_offers
FROM 'C:\sciezka_do_katalogu_z_csv\supplier_offers.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001'
);

BULK INSERT dbo.order_parts
FROM 'C:\sciezka_do_katalogu_z_csv\order_parts.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001'
);

BULK INSERT dbo.production_status
FROM 'C:\sciezka_do_katalogu_z_csv\production_status.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001'
);
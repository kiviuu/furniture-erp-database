CREATE TRIGGER trg_update_stock_on_delivery
ON order_parts
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF UPDATE(order_delivered)
    BEGIN
        UPDATE ip
        SET ip.available_units = ip.available_units + (i.pack_quantity * so.pack_size)
        FROM inventory_parts ip
        JOIN supplier_offers so ON ip.part_id = so.part_id
        JOIN inserted i ON i.offer_id = so.offer_id
        JOIN deleted d ON i.order_part_id = d.order_part_id
        WHERE i.order_delivered IS NOT NULL AND d.order_delivered IS NULL;
    END
END;
GO


CREATE OR ALTER TRIGGER trg_auto_plan_production
ON inventory_products
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @prod_id INT, @current_stock INT, @min_units INT, @max_units INT;

    DECLARE prod_cursor CURSOR FOR 
    SELECT product_id, available_units, min_units, max_units FROM inserted;

    OPEN prod_cursor;
    FETCH NEXT FROM prod_cursor INTO @prod_id, @current_stock, @min_units, @max_units;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        --stan poniżej min oraz brak aktywnej produkcji
        IF @current_stock <= @min_units 
           AND NOT EXISTS (
               SELECT 1 FROM productions p 
               JOIN production_status ps ON p.production_id = ps.production_id
               WHERE p.product_id = @prod_id AND ps.status_id IN (1, 2) AND ps.end_date IS NULL
           )
        BEGIN
            -- ile wyprodukować by zapchać 80% magazynu
            DECLARE @qty_to_produce INT = (CAST(@max_units AS FLOAT) * 0.8) - @current_stock;

            IF @qty_to_produce > 0
            BEGIN
                --Pobranie godzin z tabeli products i obliczenie dni
                DECLARE @hours_per_unit FLOAT;
                SELECT @hours_per_unit = needed_hours FROM products WHERE product_id = @prod_id;

                -- default planned_date for planned status (godziny * ilość) / 24
                DECLARE @total_hours FLOAT = ISNULL(@hours_per_unit, 1) * @qty_to_produce;
                DECLARE @days_needed INT = CEILING(@total_hours / 24.0);

                DECLARE @new_production_id INT;
                INSERT INTO productions (product_id, quantity, supervisor_id, work_place_id)
                VALUES (@prod_id, @qty_to_produce, 1, NULL); -- emplyee id 1 as default
                

                SET @new_production_id = SCOPE_IDENTITY();
                INSERT INTO production_status (production_id, status_id, start_date, planned_end_date)
                VALUES (
                    @new_production_id, 
                    1,                 -- Status: Planned
                    GETDATE(),
                    DATEADD(day, @days_needed, GETDATE())
                );
            END
        END
        FETCH NEXT FROM prod_cursor INTO @prod_id, @current_stock, @min_units, @max_units;
    END

    CLOSE prod_cursor;
    DEALLOCATE prod_cursor;
END;
GO


CREATE TRIGGER trg_auto_order_parts
ON inventory_parts
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @part_id INT, @current_stock INT, @min_units INT, @max_units INT;

    DECLARE part_cursor CURSOR FOR 
    SELECT i.part_id, i.available_units, i.min_units, i.max_units
    FROM inserted i;

    OPEN part_cursor;
    FETCH NEXT FROM part_cursor INTO @part_id, @current_stock, @min_units, @max_units;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        --Stan <= Min ORAZ brak niedostarczonych (ale aktywnych) zamówień na tę część
        IF @current_stock <= @min_units 
           AND NOT EXISTS (
               SELECT 1 FROM order_parts op 
               JOIN supplier_offers so ON op.offer_id = so.offer_id 
               WHERE so.part_id = @part_id AND op.order_delivered IS NULL
           )
        BEGIN
            -- ile zamówić aby wypchać 80% magazynu
            DECLARE @target_qty INT = (CAST(@max_units AS FLOAT) * 0.8) - @current_stock;

            IF @target_qty > 0
            BEGIN
                -- wyszukanie najlepszej oferty na tę częśc - najpierw cena za pakiet, a potem czas dostawy
                DECLARE @best_offer_id INT, @pack_size INT;
                
                SELECT TOP 1 @best_offer_id = offer_id, @pack_size = pack_size
                FROM supplier_offers
                WHERE part_id = @part_id
                ORDER BY price ASC, delivery_days ASC;

                IF @best_offer_id IS NOT NULL
                BEGIN
                    -- przeliczenie na pełne opakowania (zaokrąglone w górę)
                    DECLARE @packs_to_order INT = CEILING(CAST(@target_qty AS FLOAT) / @pack_size);

                    INSERT INTO order_parts (offer_id, order_date, pack_quantity, order_delivered)
                    VALUES (@best_offer_id, GETDATE(), @packs_to_order, NULL);
                END
            END
        END
        FETCH NEXT FROM part_cursor INTO @part_id, @current_stock, @min_units, @max_units;
    END

    CLOSE part_cursor;
    DEALLOCATE part_cursor;
END;
GO


---======================================================================
--- Stored procedures ---------------------------------------------------
---======================================================================

-- ==========================================
-- Parts area
-- ==========================================
CREATE PROCEDURE sp_upsert_supplier
    @company_name NVARCHAR(255),
    @email NVARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;
    
    IF EXISTS (SELECT 1 FROM suppliers WHERE email = @email)
    BEGIN
        UPDATE suppliers 
        SET company_name = @company_name
        WHERE email = @email;
    END
    ELSE
    BEGIN
        INSERT INTO suppliers (company_name, email)
        VALUES (@company_name, @email);
    END
END;
GO


CREATE PROCEDURE sp_upsert_supplier_offer
    @supplier_id INT,
    @part_id INT,

    -- opcjonalne
    @price MONEY = NULL,
    @delivery_days INT = NULL,
    @pack_size INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- czy oferta już istnieje?
    IF EXISTS (SELECT 1 FROM supplier_offers WHERE supplier_id = @supplier_id AND part_id = @part_id)
    BEGIN
        -- scenario: update
        UPDATE supplier_offers 
        SET price = ISNULL(@price, price), 
            delivery_days = ISNULL(@delivery_days, delivery_days), 
            pack_size = ISNULL(@pack_size, pack_size)
        WHERE supplier_id = @supplier_id AND part_id = @part_id;
    END
    ELSE
    BEGIN
        -- scenario: insert
        IF @price IS NULL OR @delivery_days IS NULL
        BEGIN
            RAISERROR('Błąd: Tworząc nową ofertę musisz podać cenę i czas dostawy.', 16, 1);
            RETURN;
        END
        INSERT INTO supplier_offers (supplier_id, part_id, price, delivery_days, pack_size)
        VALUES (@supplier_id, @part_id, @price, @delivery_days, ISNULL(@pack_size, 1));
    END
END;
GO


CREATE PROCEDURE sp_add_new_part_type
    @part_name NVARCHAR(255),
    @category_name NVARCHAR(100),
    @unit_space_needed INT = 1,
    @min_units INT,
    @max_units INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @cat_id INT;

        -- jeżeli kategoria nie istnieje to trzeba ja dodać
        SELECT @cat_id = category_id FROM categories_for_part WHERE name = @category_name;
        
        IF @cat_id IS NULL
        BEGIN
            INSERT INTO categories_for_part (name) VALUES (@category_name);
            SET @cat_id = SCOPE_IDENTITY();
        END

        -- dodaj część do katalogu części
        INSERT INTO parts (part_name, category_id, unit_space_needed) 
        VALUES (@part_name, @cat_id, @unit_space_needed);
        
        DECLARE @new_part_id INT = SCOPE_IDENTITY();

        -- dodaj wpis do inwentarza części, domyślnie 0 sztuk dostępnych
        INSERT INTO inventory_parts (part_id, available_units, min_units, max_units)
        VALUES (@new_part_id, 0, @min_units, @max_units);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        -- błąd transakcji rzucamy dalej
        THROW;
    END CATCH
END;
GO


CREATE PROCEDURE sp_place_part_order
    @offer_id INT,
    @num_packs INT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @part_id INT, @pack_size INT, @max_units INT, @current_stock INT, @pending_stock INT;
    SELECT 
        @part_id = so.part_id, 
        @pack_size = so.pack_size,
        @max_units = ip.max_units,
        @current_stock = ip.available_units
    FROM supplier_offers so
    JOIN inventory_parts ip ON so.part_id = ip.part_id
    WHERE so.offer_id = @offer_id;

    -- ile jest w drodze?
    SELECT @pending_stock = ISNULL(SUM(op.pack_quantity * so2.pack_size), 0)
    FROM order_parts op 
    JOIN supplier_offers so2 ON op.offer_id = so2.offer_id 
    WHERE so2.part_id = @part_id AND op.order_delivered IS NULL;

    -- stan obecny + w drodze + nowe zamówienie
    DECLARE @total_after_delivery INT = @current_stock + @pending_stock + (@num_packs * @pack_size);

    -- walidacja czy nie przekroczymy max_units
    IF @total_after_delivery > @max_units
    BEGIN
    -- formatmessage - komunikat, formatowanie tak jak w C
        DECLARE @msg NVARCHAR(255) = FORMATMESSAGE('Błąd: Brak miejsca. max: %d, obecnie+w drodze: %d, próba zamówienia: %d.', 
                                                   @max_units, (@current_stock + @pending_stock), (@num_packs * @pack_size));
        RAISERROR(@msg, 16, 1);
        RETURN;
    END

    -- finito - złóż zamówienie
    INSERT INTO order_parts (offer_id, order_date, pack_quantity, order_delivered)
    VALUES (@offer_id, GETDATE(), @num_packs, NULL);
END;
GO


CREATE OR ALTER PROCEDURE sp_adjust_part_inventory
    @part_id INT,
    @quantity_change INT -- może być ujemne!!
AS
BEGIN
    SET NOCOUNT ON;
    
    -- nie może zejść poniżej 0!!
    IF EXISTS (
        SELECT 1 FROM inventory_parts 
        WHERE part_id = @part_id AND (available_units + @quantity_change) < 0
    )
    BEGIN
        RAISERROR('Błąd: Operacja spowodowałaby ujemny stan magazynowy.', 16, 1);
        RETURN;
    END

    UPDATE inventory_parts
    SET available_units = available_units + @quantity_change
    WHERE part_id = @part_id;
END;
GO

-- ==========================================
-- Managment area
-- ==========================================


CREATE PROCEDURE sp_add_new_client
    @email NVARCHAR(150),
    @phone NVARCHAR(12),
    @city NVARCHAR(100),
    @address NVARCHAR(150),
    @city_code NVARCHAR(10),
    @is_company BIT, -- 1 = firma, 0 = osoba prywatna
    -- pola opcjonalne zależne od typu
    @company_name NVARCHAR(255) = NULL,
    @nip NVARCHAR(10) = NULL,
    @first_name NVARCHAR(100) = NULL,
    @last_name NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        -- walidacja danych zależnych od wybranego typu klienta
        IF @is_company = 1 AND (@company_name IS NULL OR @nip IS NULL)
        BEGIN
            RAISERROR('Dla klienta firmowego wymagane są nazwa firmy i NIP.', 16, 1);
            RETURN;
        END

        IF @is_company = 0 AND (@first_name IS NULL OR @last_name IS NULL)
        BEGIN
            RAISERROR('Dla klienta indywidualnego wymagane są imię i nazwisko.', 16, 1);
            RETURN;
        END

        -- tabela wspólna
        INSERT INTO clients (email, phone, city, address, city_code)
        VALUES (@email, @phone, @city, @address, @city_code);

        DECLARE @new_client_id INT = SCOPE_IDENTITY();

        -- wstawienie do klientó indywidualnych lub firmowych
        IF @is_company = 1
        BEGIN
            INSERT INTO clients_company (client_id, company_name, nip)
            VALUES (@new_client_id, @company_name, @nip);
        END
        ELSE
        BEGIN
            INSERT INTO clients_individual (client_id, first_name, last_name)
            VALUES (@new_client_id, @first_name, @last_name);
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


CREATE OR ALTER PROCEDURE sp_update_client_data
    @client_id INT,
    @email NVARCHAR(150) = NULL,
    @phone NVARCHAR(12) = NULL,
    @city NVARCHAR(100) = NULL,
    @address NVARCHAR(150) = NULL,
    @city_code NVARCHAR(10) = NULL,

    @company_name NVARCHAR(255) = NULL,
    @nip NVARCHAR(10) = NULL,
    @first_name NVARCHAR(100) = NULL,
    @last_name NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        -- dane wspólne dla typów klientów
        UPDATE clients
        SET email = ISNULL(@email, email),
            phone = ISNULL(@phone, phone),
            city = ISNULL(@city, city),
            address = ISNULL(@address, address),
            city_code = ISNULL(@city_code, city_code)
        WHERE client_id = @client_id;

        -- (jeśli klient to firma)
        IF EXISTS (SELECT 1 FROM clients_company WHERE client_id = @client_id)
        BEGIN
            UPDATE clients_company
            SET company_name = ISNULL(@company_name, company_name),
                nip = ISNULL(@nip, nip)
            WHERE client_id = @client_id;
        END
        -- (jeśli klient to osoba prywatna)
        ELSE IF EXISTS (SELECT 1 FROM clients_individual WHERE client_id = @client_id)
        BEGIN
            UPDATE clients_individual
            SET first_name = ISNULL(@first_name, first_name),
                last_name = ISNULL(@last_name, last_name)
            WHERE client_id = @client_id;
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


CREATE PROCEDURE sp_add_employee_role
    @position_name NVARCHAR(150),
    @description NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM roles WHERE possition_name = @position_name)
    BEGIN
        RAISERROR('Błąd: Rola o takiej nazwie już istnieje.', 16, 1);
        RETURN;
    END

    INSERT INTO roles (possition_name, description)
    VALUES (@position_name, @description);
END;
GO


CREATE PROCEDURE sp_add_new_employee
    @first_name NVARCHAR(100),
    @last_name NVARCHAR(100),
    @base_salary MONEY,
    @role_id INT,
    @supervisor_id INT = NULL,
    @hired_date DATE = NULL,
    @email NVARCHAR(150),
    @phone NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    IF @hired_date IS NULL
        SET @hired_date = CAST(GETDATE() AS DATE);

    -- domyślnie pracownik jest aktywny (is_active = 1)
    INSERT INTO employees (first_name, last_name, base_salary, is_active, role_id, supervisor_id, hired_date, email, phone)
    VALUES (@first_name, @last_name, @base_salary, 1, @role_id, @supervisor_id, @hired_date, @email, @phone);
END;
GO


CREATE PROCEDURE sp_update_employee
    @employee_id INT,
    @first_name NVARCHAR(100) = NULL,
    @last_name NVARCHAR(100) = NULL,
    @base_salary MONEY = NULL,
    @is_active BIT = NULL, -- zmiana która może wywoływać dodatkowe operacje!!!
    @role_id INT = NULL,
    @supervisor_id INT = NULL,
    @email NVARCHAR(150) = NULL,
    @phone NVARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        UPDATE employees
        SET first_name = ISNULL(@first_name, first_name),
            last_name = ISNULL(@last_name, last_name),
            base_salary = ISNULL(@base_salary, base_salary),
            is_active = ISNULL(@is_active, is_active),
            role_id = ISNULL(@role_id, role_id),
            supervisor_id = ISNULL(@supervisor_id, supervisor_id),
            email = ISNULL(@email, email),
            phone = ISNULL(@phone, phone)
        WHERE employee_id = @employee_id;

        -- dezaktywacja pracownika
        IF @is_active = 0
        BEGIN
            -- usuwanie jego przyszłych urlopów
            DELETE FROM employee_time_offs
            WHERE employee_id = @employee_id 
              AND start_date > CAST(GETDATE() AS DATE);

            -- zakończ (na dziś) jego trwające urlopy
            UPDATE employee_time_offs
            SET end_date = CAST(GETDATE() AS DATE)
            WHERE employee_id = @employee_id
              AND start_date <= CAST(GETDATE() AS DATE)
              AND end_date > CAST(GETDATE() AS DATE);
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


CREATE PROCEDURE sp_add_employee_time_off
    @employee_id INT,
    @start_date DATE,
    @end_date DATE,
    @reason NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    -- warunek integralnościowy!
    IF @end_date < @start_date
    BEGIN
        RAISERROR('Błąd: Data zakończenia urlopu nie może być wcześniejsza niż data rozpoczęcia.',16,1);
        RETURN;
    END

    -- czy on wg jest aktywny?
    IF EXISTS (SELECT 1 FROM employees WHERE employee_id = @employee_id AND is_active = 0)
    BEGIN
        RAISERROR('Błąd: Nie można dodać urlopu dla nieaktywnego pracownika.',16,1);
        RETURN;
    END
    
    -- czy urlop się nie nakłada na jakiś inny??
    IF EXISTS (
        SELECT 1 FROM employee_time_offs 
        WHERE employee_id = @employee_id 
          AND (
               (@start_date BETWEEN start_date AND end_date) OR 
               (@end_date BETWEEN start_date AND end_date) OR
               (start_date BETWEEN @start_date AND @end_date)
          )
    )
    BEGIN
        RAISERROR('W podanym terminie pracownik ma już zaplanowany inny urlop.',16, 1);
        RETURN;
    END

    INSERT INTO employee_time_offs (employee_id, start_date, end_date, reason)
    VALUES (@employee_id, @start_date, @end_date, @reason);
END;
GO

-- ==========================================
-- Catalog area
-- ==========================================

CREATE PROCEDURE sp_upsert_product
    @product_id INT = NULL,
    @product_name NVARCHAR(255) = NULL,
    @base_price MONEY = NULL,
    @unit_space_needed INT = NULL,
    @category_id INT = NULL,
    @needed_hours INT = NULL,
    @is_active BIT = 1,
    @vat_amount DECIMAL(3,2) = 0.23,
    @base_inventory_min INT = 10,
    @base_inventory_limit INT = 100
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @current_product_id INT = @product_id;

        IF @base_inventory_limit < @base_inventory_min
        BEGIN
            RAISERROR('Błąd: Podaj poprawne wartości limitów magazynowych', 16, 1);
            ROLLBACK; RETURN;
        END

        -- update/insert w tabeli products
        IF @product_id IS NOT NULL AND EXISTS (SELECT 1 FROM products WHERE product_id = @product_id)
        BEGIN
            UPDATE products SET
                product_name = ISNULL(@product_name, product_name),
                base_price = ISNULL(@base_price, base_price),
                unit_space_needed = ISNULL(@unit_space_needed, unit_space_needed),
                category_id = ISNULL(@category_id, category_id),
                needed_hours = ISNULL(@needed_hours, needed_hours),
                is_active = ISNULL(@is_active, is_active)
            WHERE product_id = @product_id;

            DECLARE @current_inventory_min INT, @current_inventory_limit INT;
            SELECT @current_inventory_min = ip.min_units, @current_inventory_limit=ip.max_units FROM inventory_products AS ip
            WHERE ip.product_id=@product_id;

            IF @current_inventory_limit <> @base_inventory_limit
            BEGIN
                UPDATE inventory_products SET max_units=@base_inventory_limit WHERE product_id=@product_id;
            END
            IF @current_inventory_min <> @base_inventory_min
            BEGIN
                UPDATE inventory_products SET min_units=@base_inventory_min WHERE product_id=@product_id;
            END
        END
        ELSE
        BEGIN
            -- warunki integralności dla nowego produktu
            IF @product_name IS NULL OR @base_price IS NULL OR @base_price < 0 OR @category_id IS NULL OR @needed_hours IS NULL OR @vat_amount is NULL
            BEGIN
                RAISERROR('Błąd: Podaj poprawną nazwę, cenę, kategorię i roboczogodziny dla nowego produktu.', 16, 1);
                ROLLBACK; RETURN;
            END

            INSERT INTO products (product_name, base_price, unit_space_needed, category_id, needed_hours, is_active)
            VALUES (@product_name, @base_price, ISNULL(@unit_space_needed, 1), @category_id, @needed_hours, @is_active);
            
            SET @current_product_id = SCOPE_IDENTITY();

            -- wpis do magazynu dla nowego produktu
            INSERT INTO inventory_products (product_id, available_units, min_units, max_units)
            VALUES (@current_product_id, 0, @base_inventory_min, @base_inventory_limit);

            DECLARE @found_vat_id INT;
            
            -- szukamy id stawki w tabeli vat
            SELECT TOP 1 @found_vat_id = vat_id FROM vat WHERE amount = @vat_amount;

            IF @found_vat_id IS NULL
            BEGIN
                INSERT INTO vat (amount) VALUES (@vat_amount);
                SET @found_vat_id = SCOPE_IDENTITY();
            END

            INSERT INTO products_vat (product_id, vat_id, start_date, end_date)
            VALUES (@current_product_id, @found_vat_id, CAST(GETDATE() AS DATE), NULL);

        END

        COMMIT TRANSACTION;
        SELECT @current_product_id AS product_id;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


CREATE PROCEDURE sp_update_product_vat
    @product_id INT,
    @new_vat_amount DECIMAL(3,2)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @new_vat_id INT;

        -- znajdź lub dodaj jak trzeba do słownika nową stawkę vat
        SELECT TOP 1 @new_vat_id = vat_id FROM vat WHERE amount = @new_vat_amount;
        
        IF @new_vat_id IS NULL
        BEGIN
            INSERT INTO vat (amount) VALUES (@new_vat_amount);
            SET @new_vat_id = SCOPE_IDENTITY();
        END

        -- zakończenie stawki (poprzedniej) dla tego produktu
        UPDATE products_vat 
        SET end_date = CAST(GETDATE() AS DATE)
        WHERE product_id = @product_id 
          AND end_date IS NULL 
          AND vat_id <> @new_vat_id;

        IF NOT EXISTS (SELECT 1 FROM products_vat WHERE product_id = @product_id AND vat_id = @new_vat_id AND end_date IS NULL)
        BEGIN
            INSERT INTO products_vat (product_id, vat_id, start_date, end_date)
            VALUES (@product_id, @new_vat_id, CAST(GETDATE() AS DATE), NULL);
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


CREATE PROCEDURE sp_upsert_product_recipe
    @product_id INT,
    @part_id INT,
    @quantity_needed INT
AS
BEGIN
    SET NOCOUNT ON;
    
    IF EXISTS (SELECT 1 FROM product_recipes WHERE product_id = @product_id AND part_id = @part_id)
    BEGIN
        UPDATE product_recipes 
        SET quantity_needed = @quantity_needed
        WHERE product_id = @product_id AND part_id = @part_id;
    END
    ELSE
    BEGIN
        INSERT INTO product_recipes (product_id, part_id, quantity_needed)
        VALUES (@product_id, @part_id, @quantity_needed);
    END
END;
GO


CREATE PROCEDURE sp_add_product_category
    @name NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    
    IF EXISTS (SELECT 1 FROM categories_for_product WHERE name = @name)
    BEGIN
        RAISERROR('Błąd: Kategoria o tej nazwie już istnieje.', 16, 1);
        RETURN;
    END

    INSERT INTO categories_for_product (name)
    VALUES (@name);
END;
GO


-- ==========================================
-- Production area
-- ==========================================

CREATE PROCEDURE sp_upsert_production
    @production_id INT = NULL,
    @product_id INT = NULL,
    @quantity INT = NULL,
    @work_place_id INT = NULL,
    @supervisor_id INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @production_id IS NOT NULL AND EXISTS (SELECT 1 FROM productions WHERE production_id = @production_id)
    BEGIN
        UPDATE productions SET
            product_id = ISNULL(@product_id, product_id),
            quantity = ISNULL(@quantity, quantity),
            work_place_id = ISNULL(@work_place_id, work_place_id),
            supervisor_id = ISNULL(@supervisor_id, supervisor_id)
        WHERE production_id = @production_id;
    END
    ELSE
    BEGIN
        IF @product_id IS NULL OR @quantity IS NULL OR @supervisor_id IS NULL
        BEGIN
            RAISERROR('Błąd: Nowa produkcja wymaga product_id, quantity i supervisor_id.', 16, 1);
            RETURN;
        END
        
        INSERT INTO productions (product_id, quantity, work_place_id, supervisor_id)
        VALUES (@product_id, @quantity, @work_place_id, @supervisor_id);
        
        -- status 1 - planowana
        INSERT INTO production_status (production_id, status_id, start_date, planned_end_date)
        VALUES (SCOPE_IDENTITY(), 1, GETDATE(), DATEADD(day, 2, GETDATE()));
    END
END;
GO


CREATE PROCEDURE sp_upsert_employee_to_production
    @production_id INT,
    @employee_id INT,
    @hours_logged INT = 0
AS
BEGIN
    IF EXISTS (SELECT 1 FROM production_team_assignments WHERE production_id = @production_id AND employee_id = @employee_id)
    BEGIN
        UPDATE production_team_assignments SET hours_logged = @hours_logged 
        WHERE production_id = @production_id AND employee_id = @employee_id;
    END
    ELSE
    BEGIN
        INSERT INTO production_team_assignments (production_id, employee_id, hours_logged)
        VALUES (@production_id, @employee_id, @hours_logged);
    END
END;
GO


CREATE PROCEDURE sp_remove_employee_from_production
    @production_id INT,
    @employee_id INT
AS
BEGIN
    DELETE FROM production_team_assignments 
    WHERE production_id = @production_id AND employee_id = @employee_id;
END;
GO


CREATE PROCEDURE sp_replace_production_employee
    @production_id INT,
    @old_employee_id INT,
    @new_employee_id INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        IF NOT EXISTS (
            SELECT 1 
            FROM production_team_assignments 
            WHERE production_id = @production_id AND employee_id = @old_employee_id
        )
        BEGIN
            RAISERROR('Błąd: Wskazany pracownik o id: %d nie jest przypisany do produkcji o id: %d.', 16, 1, @old_employee_id, @production_id);
            ROLLBACK; RETURN;
        END

        -- czy nowy pracownik nie jest już tam przypisany!!
        IF EXISTS (
            SELECT 1 
            FROM production_team_assignments 
            WHERE production_id = @production_id AND employee_id = @new_employee_id
        )
        BEGIN
            RAISERROR('Błąd: Nowy pracownik o id: %d jest już przypisany do tej produkcji.', 16, 1, @new_employee_id);
            ROLLBACK; RETURN;
        END

        -- podmianka -> usunięcie starego -> dodanie nowego
        INSERT INTO production_team_assignments (production_id, employee_id, hours_logged)
        SELECT @production_id, @new_employee_id, hours_logged
        FROM production_team_assignments
        WHERE production_id = @production_id AND employee_id = @old_employee_id;

        DELETE FROM production_team_assignments 
        WHERE production_id = @production_id AND employee_id = @old_employee_id;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


CREATE OR ALTER PROCEDURE sp_start_production
    @production_id INT,
    @planned_end_date DATETIME = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRANSACTION;
    BEGIN TRY
        -- produkcja nie została już rozpoczęta lub zakończona?
        IF EXISTS (SELECT 1 FROM production_status WHERE production_id = @production_id AND status_id >= 2 AND end_date IS NULL)
        BEGIN
            RAISERROR('Błąd: Produkcja jest już w toku lub została zakończona.', 16, 1);
            ROLLBACK; RETURN;
        END

        -- sprawdzenie dostępności wymaganych części
        IF EXISTS (
            SELECT 1 
            FROM product_recipes pr
            JOIN productions p ON p.product_id = pr.product_id
            JOIN inventory_parts ip ON ip.part_id = pr.part_id
            WHERE p.production_id = @production_id
              AND ip.available_units < (pr.quantity_needed * p.quantity)
        )
        BEGIN
            RAISERROR('Błąd: Niewystarczająca ilość części w magazynie.', 16, 1);
            ROLLBACK; RETURN;
        END

        -- logika planned_end_date
        IF @planned_end_date IS NULL
        BEGIN
            DECLARE @days_needed INT;
            
            SELECT @days_needed = CEILING((CAST(p.quantity AS FLOAT) * ISNULL(prod.needed_hours, 1)) / 24.0)
            FROM productions p
            JOIN products prod ON p.product_id = prod.product_id
            WHERE p.production_id = @production_id;

            SET @planned_end_date = DATEADD(day, ISNULL(@days_needed, 1), GETDATE());
        END
        ELSE
        BEGIN
            -- walidacja podanej daty: czy planowany koniec nie jest w przeszłości?
            IF @planned_end_date <= GETDATE()
            BEGIN
                RAISERROR('Błąd: Planowana data zakończenia nie może być wcześniejsza niż obecny czas.', 16, 1);
                ROLLBACK; RETURN;
            END
        END

        -- odjęcie części z magazynu
        UPDATE ip
        SET ip.available_units = ip.available_units - (pr.quantity_needed * p.quantity)
        FROM inventory_parts ip
        JOIN product_recipes pr ON ip.part_id = pr.part_id
        JOIN productions p ON p.product_id = pr.product_id
        WHERE p.production_id = @production_id;

        -- zakończenie poprzedniego stanu (powinien  być np. wstrzymany lub planowany)
        UPDATE production_status 
        SET end_date = GETDATE() 
        WHERE production_id = @production_id AND end_date IS NULL;

        -- dodanie nowego statusu In Production (ID 2)
        INSERT INTO production_status (production_id, status_id, start_date, planned_end_date)
        VALUES (
            @production_id, 
            2, 
            GETDATE(), 
            @planned_end_date
        );

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


CREATE PROCEDURE sp_finish_production
    @production_id INT,
    @final_status_id INT = 5 -- ID statusu "Completed"
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        -- statusy końcowe
        IF @final_status_id NOT BETWEEN 5 AND 6
        BEGIN
            RAISERROR('Błąd: Podany status nie jest końcowy.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF EXISTS (
            SELECT 1 
            FROM production_status 
            WHERE production_id = @production_id 
              AND status_id BETWEEN 5 AND 6
        )
        BEGIN
            RAISERROR('Błąd: Ta produkcja została już wcześniej zakończona lub anulowana.', 16, 1);
            ROLLBACK TRANSACTION; RETURN;
        END

        IF @final_status_id=5
        BEGIN
            UPDATE ip
            SET ip.available_units = ip.available_units + p.quantity
            FROM inventory_products ip
            JOIN productions p ON p.product_id = ip.product_id
            WHERE p.production_id = @production_id;
        END

        -- update trwających statusów
        UPDATE production_status SET end_date = GETDATE() WHERE production_id = @production_id AND end_date IS NULL;
        
        INSERT INTO production_status (production_id, status_id, start_date, planned_end_date, end_date)
        VALUES (@production_id, @final_status_id, GETDATE(), GETDATE(), GETDATE());

        -- usunięcie przydziałów pracowników
        DELETE FROM production_team_assignments WHERE production_id = @production_id;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


CREATE PROCEDURE sp_add_work_place
    @description NVARCHAR(255)
AS
BEGIN
    INSERT INTO work_places (work_place_description) VALUES (@description);
END;
GO

-- ==========================================
-- Order area
-- ==========================================

CREATE PROCEDURE sp_confirm_order
    @order_id INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM order_details WHERE order_id = @order_id)
        BEGIN
            RAISERROR('Błąd: Nie można zatwierdzić pustego zamówienia.', 16, 1);
            ROLLBACK; RETURN;
        END

        -- odejmij ze stanu - safe bo transakcja!!
        UPDATE ip
        SET ip.available_units = ip.available_units - od.quantity
        FROM inventory_products ip
        JOIN order_details od ON ip.product_id = od.product_id
        WHERE od.order_id = @order_id;

        -- czy mamy tyle na stanie??
        IF EXISTS (SELECT 1 FROM inventory_products WHERE available_units < 0)
        BEGIN
            RAISERROR('Błąd: Niewystarczająca ilość produktu w magazynie.', 16, 1);
            ROLLBACK; RETURN;
        END

        -- status_for_order o id 2 - Ready for Shipment
        INSERT INTO order_status (order_id, status_id, start_date, planned_end_date, end_date)
        VALUES (@order_id, 2, GETDATE(), GETDATE(), GETDATE());

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


CREATE PROCEDURE sp_upsert_order
    @order_id INT = NULL,
    @shipper_id INT = NULL,
    @delivery_city NVARCHAR(100) = NULL,
    @delivery_address NVARCHAR(150) = NULL,
    @delivery_city_code NVARCHAR(10) = NULL,
    @supervisor_id INT = NULL,
    @order_discount DECIMAL(3,2) = NULL,
    @client_id INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @order_id IS NOT NULL AND EXISTS (SELECT 1 FROM orders WHERE order_id = @order_id)
    BEGIN
        UPDATE orders SET
            shipper_id = ISNULL(@shipper_id, shipper_id),
            delivery_city = ISNULL(@delivery_city, delivery_city),
            delivery_address = ISNULL(@delivery_address, delivery_address),
            delivery_city_code = ISNULL(@delivery_city_code, delivery_city_code),
            supervisor_id = ISNULL(@supervisor_id, supervisor_id),
            order_discount = ISNULL(@order_discount, order_discount),
            client_id = ISNULL(@client_id, client_id)
        WHERE order_id = @order_id;
    END
    ELSE
    BEGIN
        IF @shipper_id IS NULL OR @client_id IS NULL OR @supervisor_id IS NULL
        BEGIN
            RAISERROR('Błąd: Nowe zamówienie wymaga shipper_id, client_id i supervisor_id.', 16, 1);
            RETURN;
        END
        INSERT INTO orders (shipper_id, order_date, delivery_city, delivery_address, supervisor_id, order_discount, client_id, delivery_city_code)
        VALUES (@shipper_id, GETDATE(), @delivery_city, @delivery_address, @supervisor_id, ISNULL(@order_discount, 0), @client_id, @delivery_city_code);
        
        SELECT SCOPE_IDENTITY() AS NewOrderID;
    END
END;
GO


CREATE OR ALTER PROCEDURE sp_add_order_detail_with_overflow
    @order_id INT,
    @product_id INT,
    @quantity INT,
    @unit_price MONEY = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        -- dane o cenie i o stanie magazynowym produktu
        IF @unit_price IS NULL 
            SELECT @unit_price = base_price FROM products WHERE product_id = @product_id;

        DECLARE @max_units INT, @current_stock INT;
        SELECT @max_units = max_units, @current_stock = available_units 
        FROM inventory_products WHERE product_id = @product_id;

        -- limit dla zamówienia - 90% przestrzeni magazynowej
        DECLARE @storage_limit INT = @max_units * 0.9;
        DECLARE @available_space INT = @storage_limit - @current_stock;
        
        IF @available_space < 0 SET @available_space = 0;

        DECLARE @to_insert_now INT, @overflow_qty INT;

        IF @quantity <= @available_space
        BEGIN
            SET @to_insert_now = @quantity;
            SET @overflow_qty = 0;
        END
        ELSE
        BEGIN
            SET @to_insert_now = @available_space;
            SET @overflow_qty = @quantity - @available_space;
        END

        -- insert lub update w bieżącym zamówieniu
        IF @to_insert_now > 0
        BEGIN
            IF EXISTS (SELECT 1 FROM order_details WHERE order_id = @order_id AND product_id = @product_id)
            BEGIN
                UPDATE order_details SET quantity = quantity + @to_insert_now 
                WHERE order_id = @order_id AND product_id = @product_id;
            END
            ELSE
            BEGIN
                INSERT INTO order_details (order_id, product_id, quantity, unit_price)
                VALUES (@order_id, @product_id, @to_insert_now, @unit_price);
            END
        END

        -- nadmiar! - do nowego zamówienia
        IF @overflow_qty > 0
        BEGIN
            DECLARE @new_order_id INT;
            -- dane zamówienia są takie same!
            INSERT INTO orders (shipper_id, order_date, delivery_city, delivery_address, supervisor_id, order_discount, client_id, delivery_city_code)
            SELECT shipper_id, GETDATE(), delivery_city, delivery_address, supervisor_id, order_discount, client_id, delivery_city_code
            FROM orders WHERE order_id = @order_id;
            
            SET @new_order_id = SCOPE_IDENTITY();

            -- rekurencyjny rozkład :((
            EXEC sp_add_order_detail_with_overflow @new_order_id, @product_id, @overflow_qty, @unit_price;
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO


CREATE PROCEDURE sp_delete_order_detail
    @order_id INT,
    @product_id INT
AS
BEGIN
    DELETE FROM order_details WHERE order_id = @order_id AND product_id = @product_id;
END;
GO


CREATE PROCEDURE sp_upsert_shipper
    @shipper_id INT = NULL,
    @company_name NVARCHAR(255) = NULL,
    @email VARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM shippers WHERE shipper_id = @shipper_id OR email = @email)
    BEGIN
        UPDATE shippers 
        SET company_name = ISNULL(@company_name, company_name),
            email = ISNULL(@email, email)
        WHERE shipper_id = @shipper_id OR email = @email;
    END
    ELSE
    BEGIN
        IF @company_name IS NULL OR @email IS NULL
        BEGIN
            RAISERROR('Błąd: Przy tworzeniu nowego przewoźnika podaj nazwę i email.', 16, 1);
            RETURN;
        END
        INSERT INTO shippers (company_name, email) VALUES (@company_name, @email);
    END
END;
GO


CREATE PROCEDURE sp_upsert_payment
    @payment_id INT = NULL,
    @order_id INT = NULL,
    @amount MONEY = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @payment_id IS NOT NULL AND EXISTS (SELECT 1 FROM payments WHERE payment_id = @payment_id)
    BEGIN
        UPDATE payments SET
            amount = ISNULL(@amount, amount),
            payment_date = GETDATE()
        WHERE payment_id = @payment_id;
    END
    ELSE
    BEGIN
        IF @order_id IS NULL OR @amount IS NULL
        BEGIN
            RAISERROR('Błąd: Nowa płatność wymaga order_id i kwoty.', 16, 1);
            RETURN;
        END
        INSERT INTO payments (order_id, amount, payment_date)
        VALUES (@order_id, @amount, GETDATE());
    END
END;
GO


CREATE PROCEDURE sp_manage_order_status
    @order_id INT,
    @status_id INT = NULL,
    @status_name NVARCHAR(30) = NULL,
    @start_date DATETIME = NULL,
    @new_end_date DATETIME = NULL,
    @planned_end_date DATETIME = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    -- pobieranie status_id po nazwie, jeśli id nie zostało podane
    IF @status_id IS NULL AND @status_name IS NOT NULL
    BEGIN
        SELECT @status_id = status_id FROM status_for_order WHERE status_name = @status_name;
    END

    -- mamy stany od 1 do 6 ale do 2 możemy tylko procedurą zatwierdzającą
    IF @status_id IS NULL OR @status_id NOT BETWEEN 1 AND 6 OR @status_id = 2
    BEGIN
        RAISERROR('Błąd: Nieprawidłowy status. Dopuszczalne ID to 1, 3, 4, 5, 6.', 16, 1);
        RETURN;
    END

    -- (Jeśli podano @start_date, zamykamy istniejący wpis)
    IF @start_date IS NOT NULL
    BEGIN
        UPDATE order_status 
        SET end_date = ISNULL(@new_end_date, GETDATE())
        WHERE order_id = @order_id 
          AND status_id = @status_id 
          AND start_date = @start_date;

        IF @@ROWCOUNT = 0
            RAISERROR('Błąd: Nie znaleziono dokładnie takiego wpisu do aktualizacji.', 16, 1);
        
        RETURN;
    END

    -- nowy wpis + walidacja nakładania się terminów
    DECLARE @now DATETIME = GETDATE();
    
    IF EXISTS (
        SELECT 1 FROM order_status
        WHERE order_id = @order_id
          AND status_id = @status_id
          AND @now BETWEEN start_date AND planned_end_date
          AND end_date IS NULL
    )
    BEGIN
        RAISERROR('Błąd: Nowa data startowa koliduje z istniejącym, aktywnym wpisem o tym samym statusie.', 16, 1);
        RETURN;
    END

    -- zakończenie poprzednich statusów (end_date IS NULL)
    UPDATE order_status 
    SET end_date = @now 
    WHERE order_id = @order_id AND end_date IS NULL;

    -- nowy status
    INSERT INTO order_status (order_id, status_id, start_date, planned_end_date)
    VALUES (@order_id, @status_id, @now, ISNULL(@planned_end_date, DATEADD(day, 3, @now)));

END;
GO
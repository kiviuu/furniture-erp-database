-- ==========================================
-- Parts area
-- ==========================================

CREATE VIEW v_inventory_parts_status AS
SELECT 
    ip.part_id,
    p.part_name,
    ip.available_units,
    ip.min_units,
    ip.max_units,
    CASE 
        WHEN ip.available_units < ip.min_units THEN 'UWAGA: Poniżej minimum!'
        ELSE 'Stan OK'
    END AS status_uwagi
FROM inventory_parts ip
JOIN parts p ON ip.part_id = p.part_id;
GO


CREATE VIEW v_supplier_offers_detail AS
SELECT 
    so.offer_id,
    p.part_name,
    s.company_name AS supplier_name,
    so.price,
    so.delivery_days,
    so.pack_size
FROM supplier_offers so
JOIN suppliers s ON so.supplier_id = s.supplier_id
JOIN parts p ON so.part_id = p.part_id;
GO


CREATE VIEW v_order_parts_status AS
SELECT 
    op.order_part_id,
    p.part_name,
    op.pack_quantity,
    so.pack_size as 'parts_in_pack',
    CASE 
        WHEN op.order_delivered IS NULL THEN 'Nie dostarczone'
        ELSE 'Dostarczone'
    END AS status_dostawy,
    -- Planowana data to data zamówienia + dni z oferty
    DATEADD(day, so.delivery_days, op.order_date) AS planned_delivery_date,
    op.order_delivered AS actual_delivery_date
FROM order_parts op
JOIN supplier_offers so ON op.offer_id = so.offer_id
JOIN parts p ON so.part_id = p.part_id;
GO


CREATE VIEW v_delivery_delays AS
SELECT 
    op.order_part_id,
    p.part_name,
    s.company_name AS supplier_name,
    DATEADD(day, so.delivery_days, op.order_date) AS planned_delivery_date,
    op.order_delivered AS actual_delivery_date,
    DATEDIFF(day, DATEADD(day, so.delivery_days, op.order_date), ISNULL(op.order_delivered, GETDATE())) AS delay_days,
    CASE 
        WHEN op.order_delivered IS NULL THEN 'Zaległe (nie dostarczone)'
        ELSE 'Dostarczone po terminie'
    END AS delay_type
FROM order_parts op
JOIN supplier_offers so ON op.offer_id = so.offer_id
JOIN suppliers s ON so.supplier_id = s.supplier_id
JOIN parts p ON so.part_id = p.part_id
WHERE (op.order_delivered > DATEADD(day, so.delivery_days, op.order_date))
   OR (op.order_delivered IS NULL AND DATEADD(day, so.delivery_days, op.order_date) < GETDATE());
GO


CREATE VIEW v_supplier_summary AS
SELECT 
    s.company_name,
    SUM(so.price * op.pack_quantity) AS total_value,
    AVG(CAST(DATEDIFF(day, DATEADD(day, so.delivery_days, op.order_date), ISNULL(op.order_delivered, GETDATE())) AS FLOAT)) AS avg_delay,
    COUNT(op.order_part_id) AS total_orders,
    SUM(CASE WHEN ISNULL(op.order_delivered, GETDATE()) > DATEADD(day, so.delivery_days, op.order_date) THEN 1 ELSE 0 END) AS delayed_orders_count
FROM suppliers s
JOIN supplier_offers so ON s.supplier_id = so.supplier_id
JOIN order_parts op ON so.offer_id = op.offer_id
GROUP BY s.supplier_id, s.company_name;
GO


CREATE FUNCTION fn_part_offers_by_deadline (@part_id INT, @deadline DATE)
RETURNS TABLE
AS
RETURN (
    SELECT 
        p.part_name,
        s.company_name,
        so.price,
        so.delivery_days,
        DATEADD(day, so.delivery_days, GETDATE()) AS potential_delivery_date
    FROM supplier_offers so
    JOIN parts p ON so.part_id = p.part_id
    JOIN suppliers s ON so.supplier_id = s.supplier_id
    WHERE so.part_id = @part_id
      AND (@deadline IS NULL OR DATEADD(day, so.delivery_days, GETDATE()) <= @deadline)
);
GO


CREATE FUNCTION fn_get_supplier_offers_by_name_or_id (
    @supplier_info NVARCHAR(255)
)
RETURNS TABLE
AS
RETURN (
    SELECT 
        s.supplier_id,
        s.company_name,
        p.part_name,
        so.price,
        so.delivery_days,
        so.pack_size
    FROM supplier_offers so
    JOIN suppliers s ON so.supplier_id = s.supplier_id
    JOIN parts p ON so.part_id = p.part_id
    WHERE 
        CAST(s.supplier_id AS NVARCHAR) = @supplier_info 
        OR s.company_name LIKE '%' + @supplier_info + '%'
);
GO


CREATE FUNCTION fn_get_late_orders_up_to_date (@deadline_date DATE)
RETURNS TABLE
AS
RETURN (
    SELECT 
        op.order_part_id,
        p.part_name,
        s.company_name AS supplier_name,
        op.order_date,
        DATEADD(day, so.delivery_days, op.order_date) AS planned_delivery_date,
        op.order_delivered AS actual_delivery_date,
        DATEDIFF(day, DATEADD(day, so.delivery_days, op.order_date), ISNULL(op.order_delivered, GETDATE())) AS delay_days,
        CASE 
            WHEN op.order_delivered IS NULL THEN 'Zaległe (nie dostarczone)'
            ELSE 'Dostarczone po terminie'
        END AS status_opoznienia
    FROM order_parts op
    JOIN supplier_offers so ON op.offer_id = so.offer_id
    JOIN suppliers s ON so.supplier_id = s.supplier_id
    JOIN parts p ON so.part_id = p.part_id
    WHERE 
        DATEADD(day, so.delivery_days, op.order_date) <= @deadline_date
        AND (
            op.order_delivered > DATEADD(day, so.delivery_days, op.order_date)
            OR (op.order_delivered IS NULL AND DATEADD(day, so.delivery_days, op.order_date) < GETDATE())
        )
);
GO


-- ==========================================
-- Managment area
-- ==========================================


CREATE VIEW v_client_company_stats AS
SELECT 
    cc.company_name,
    cc.nip,
    COUNT(o.order_id) AS total_orders_count,
    SUM(od.quantity * od.unit_price * (1 - o.order_discount)) AS total_orders_value,
    AVG(od.quantity * od.unit_price * (1 - o.order_discount)) AS average_order_value,
    MAX(o.order_date) AS last_order_date
FROM clients_company cc
JOIN orders o ON cc.client_id = o.client_id
JOIN order_details od ON o.order_id = od.order_id
GROUP BY cc.client_id, cc.company_name, cc.nip;
GO


CREATE VIEW v_client_individual_stats AS
SELECT 
    ci.first_name,
    ci.last_name,
    COUNT(o.order_id) AS total_orders_count,
    SUM(od.quantity * od.unit_price * (1 - o.order_discount)) AS total_orders_value,
    AVG(od.quantity * od.unit_price * (1 - o.order_discount)) AS average_order_value,
    MAX(o.order_date) AS last_order_date
FROM clients_individual ci
JOIN orders o ON ci.client_id = o.client_id
JOIN order_details od ON o.order_id = od.order_id
GROUP BY ci.client_id, ci.first_name, ci.last_name;
GO


CREATE OR ALTER VIEW v_employee_total_time_off_days AS
SELECT 
    e.employee_id,
    e.first_name,
    e.last_name,
    SUM(DATEDIFF(day, eto.start_date, eto.end_date) + 1) AS total_days_off
FROM employees e
JOIN employee_time_offs eto ON e.employee_id = eto.employee_id
GROUP BY e.employee_id, e.first_name, e.last_name;
GO


CREATE VIEW v_current_and_future_time_offs AS
SELECT 
    e.first_name,
    e.last_name,
    eto.start_date,
    eto.end_date,
    DATEDIFF(day, eto.start_date, eto.end_date) + 1 AS duration_days,
    eto.reason
FROM employee_time_offs eto
JOIN employees e ON eto.employee_id = e.employee_id
WHERE eto.end_date >= CAST(GETDATE() AS DATE);
GO


CREATE VIEW v_client_contact_book AS
SELECT 
    c.client_id,
    CASE 
        WHEN cc.company_name IS NOT NULL THEN cc.company_name 
        ELSE ci.first_name + ' ' + ci.last_name 
    END AS client_display_name,
    c.email,
    c.phone,
    c.city,
    c.address,
    CASE WHEN cc.company_name IS NOT NULL THEN 'Firma' ELSE 'Indywidualny' END AS client_type
FROM clients c
LEFT JOIN clients_company cc ON c.client_id = cc.client_id
LEFT JOIN clients_individual ci ON c.client_id = ci.client_id;
GO


CREATE FUNCTION fn_get_employee_future_time_offs (
    @search_val NVARCHAR(150)
)
RETURNS TABLE
AS
RETURN (
    SELECT 
        e.first_name,
        e.last_name,
        eto.start_date,
        eto.end_date,
        DATEDIFF(day, eto.start_date, eto.end_date) + 1 AS duration_days,
        eto.reason
    FROM employee_time_offs eto
    JOIN employees e ON eto.employee_id = e.employee_id
    WHERE (CAST(e.employee_id AS NVARCHAR) = @search_val OR e.email = @search_val)
      AND eto.end_date >= CAST(GETDATE() AS DATE)
);
GO


-- ==========================================
-- Catalog area
-- ==========================================


CREATE VIEW v_product_category_performance AS
WITH PartPrices AS (
    SELECT 
        part_id, 
        AVG(price) AS avg_part_price
    FROM supplier_offers
    GROUP BY part_id
),
CategoryCosts AS (
    SELECT 
        p.category_id,
        od.order_id,
        (od.quantity * pr.quantity_needed * pp.avg_part_price) AS line_part_cost,
        (od.quantity * od.unit_price * (1 - o.order_discount)) AS line_revenue
    FROM products p
    JOIN order_details od ON p.product_id = od.product_id
    JOIN orders o ON od.order_id = o.order_id
    JOIN product_recipes pr ON p.product_id = pr.product_id
    JOIN PartPrices pp ON pr.part_id = pp.part_id
)
SELECT 
    cp.category_id,
    cp.name AS category_name,
    SUM(cc.line_revenue) AS total_sales_value,
    (SELECT SUM(od2.quantity * pr2.quantity_needed) 
     FROM order_details od2 
     JOIN products p2 ON od2.product_id = p2.product_id 
     JOIN product_recipes pr2 ON p2.product_id = pr2.product_id
     WHERE p2.category_id = cp.category_id) AS total_parts_consumed,
    SUM(cc.line_part_cost) AS total_estimated_parts_cost,
    SUM(cc.line_revenue) - SUM(cc.line_part_cost) AS net_income_after_parts
FROM categories_for_product cp
LEFT JOIN CategoryCosts cc ON cp.category_id = cc.category_id
GROUP BY cp.category_id, cp.name;
GO


CREATE VIEW v_product_sales_summary AS
SELECT 
    p.product_id,
    p.product_name,
    SUM(od.quantity) AS total_units_sold,
    SUM(od.quantity * od.unit_price * (1 - o.order_discount)) AS total_sales_value
FROM products p
LEFT JOIN order_details od ON p.product_id = od.product_id
LEFT JOIN orders o ON od.order_id = o.order_id
GROUP BY p.product_id, p.product_name;
GO


CREATE VIEW v_product_last_order AS
SELECT 
    p.product_id,
    p.product_name,
    MAX(o.order_date) AS last_order_date
FROM products p
JOIN order_details od ON p.product_id = od.product_id
JOIN orders o ON od.order_id = o.order_id
GROUP BY p.product_id, p.product_name;
GO


CREATE VIEW v_inventory_products_status AS
SELECT 
    ip.product_id,
    p.product_name,
    ip.available_units,
    ip.min_units,
    ip.max_units,
    CASE 
        WHEN ip.available_units < ip.min_units THEN 'UWAGA: Poniżej minimum!'
        WHEN ip.available_units = 0 THEN 'BRAK NA STANIE'
        ELSE 'Stan OK'
    END AS stock_alert
FROM inventory_products ip
JOIN products p ON ip.product_id = p.product_id;
GO


CREATE VIEW v_product_profitability_analysis AS
WITH AvgPartPrices AS (
    SELECT 
        part_id, 
        AVG(price) AS avg_price
    FROM supplier_offers
    GROUP BY part_id
),
ProductPartsCosts AS (
    SELECT 
        pr.product_id,
        SUM(pr.quantity_needed * ISNULL(ap.avg_price, 0)) AS total_parts_cost
    FROM product_recipes pr
    LEFT JOIN AvgPartPrices ap ON pr.part_id = ap.part_id
    GROUP BY pr.product_id
)
SELECT 
    p.product_id,
    p.product_name,
    p.base_price AS product_sale_price,
    ISNULL(ppc.total_parts_cost, 0) AS total_parts_cost,
    p.base_price - ISNULL(ppc.total_parts_cost, 0) AS gross_profit_margin,
    CASE 
        WHEN p.base_price > 0 THEN 
            ((p.base_price - ISNULL(ppc.total_parts_cost, 0)) / p.base_price) * 100 
        ELSE 0 
    END AS margin_percentage
FROM products p
LEFT JOIN ProductPartsCosts ppc ON p.product_id = ppc.product_id;
GO


CREATE FUNCTION fn_get_revenue_report (
    @year INT,
    @month INT,         -- NULL = raport roczny
    @by_categories BIT = 1, -- 1 = grupuj kategoriami, 0 = grupuj produktami
    @by_weeks BIT = 1      -- 1 = rozbij na tygodnie
)
RETURNS TABLE
AS
RETURN (
    SELECT
        CASE WHEN @by_categories = 1 THEN c.category_id ELSE p.product_id END AS group_id,
        CASE WHEN @by_categories = 1 THEN c.name ELSE p.product_name END AS group_name,
        YEAR(o.order_date) AS report_year,
        -- podano miesiąc - pokauzjemy, jeśli null to nulle
        CASE WHEN @month IS NOT NULL THEN MONTH(o.order_date) ELSE NULL END AS report_month,
        -- flaga tygodni = 1 - pokazujemy
        CASE WHEN @by_weeks = 1 THEN DATEPART(week, o.order_date) ELSE NULL END AS report_week,
        SUM(od.quantity) AS total_units_sold,
        SUM(od.quantity * od.unit_price * (1 - o.order_discount)) AS total_revenue,
        COUNT(DISTINCT o.order_id) AS number_of_orders
    FROM products p
    JOIN order_details od ON p.product_id = od.product_id
    JOIN orders o ON od.order_id = o.order_id
    JOIN categories_for_product c ON p.category_id = c.category_id
    WHERE YEAR(o.order_date) = @year
      AND (@month IS NULL OR MONTH(o.order_date) = @month)
    GROUP BY 
        -- Dynamiczne grupowanie po ID i Nazwie
        CASE WHEN @by_categories = 1 THEN c.category_id ELSE p.product_id END,
        CASE WHEN @by_categories = 1 THEN c.name ELSE p.product_name END,
        -- Stałe grupowanie po roku
        YEAR(o.order_date),
        -- Dynamiczne grupowanie czasu:
        -- Jeśli wybrano konkretny miesiąc, grupujemy po nim.
        CASE WHEN @month IS NOT NULL THEN MONTH(o.order_date) ELSE NULL END,
        -- Jeśli włączono tygodnie, dodajemy tydzień do grupowania. W przeciwnym razie NULL
        CASE WHEN @by_weeks = 1 THEN DATEPART(week, o.order_date) ELSE NULL END
);
GO


CREATE OR ALTER FUNCTION fn_production_cost_profit_report (
    @group_by_category BIT = 1, -- 1: Wyniki per Kategoria, 0: Wyniki per Produkt (jednostkowo)
    @period_type INT = 2,        -- 0: Rok, 1: Kwartał, 2: Miesiąc, 3: Tydzień
    @work_hour_price FLOAT = 0
)
RETURNS TABLE
AS
RETURN
(
    WITH PartPrices AS (
        SELECT 
            part_id, 
            AVG(price) AS avg_part_price
        FROM supplier_offers
        GROUP BY part_id
    ),
    BaseData AS (
        SELECT 
            p.product_id,
            p.product_name,
            cp.category_id,
            cp.name AS category_name,
            o.order_date,
            od.quantity,
            (od.quantity * p.needed_hours) as total_needed_working_hours,
            (od.quantity * (
                ISNULL((SELECT SUM(pr.quantity_needed * pp.avg_part_price) 
                        FROM product_recipes pr 
                        JOIN PartPrices pp ON pr.part_id = pp.part_id 
                        WHERE pr.product_id = p.product_id), 0) 
                + (p.needed_hours * @work_hour_price)
            )) AS total_production_cost,
            (od.quantity * od.unit_price * (1 - ISNULL(o.order_discount, 0))) AS line_revenue
        FROM products p
        JOIN categories_for_product cp ON p.category_id = cp.category_id
        JOIN order_details od ON p.product_id = od.product_id
        JOIN orders o ON od.order_id = o.order_id
    )
    SELECT 
        -- ID Kategorii lub ID Produktu
        CASE 
            WHEN @group_by_category = 1 THEN CAST(category_id AS VARCHAR) 
            ELSE CAST(product_id AS VARCHAR) 
        END AS [ID],
        
        -- Nazwa Kategorii lub Nazwa Produktu
        CASE 
            WHEN @group_by_category = 1 THEN category_name 
            ELSE product_name 
        END AS [Name],
        
        YEAR(order_date) AS [Year],
        
        CASE 
            WHEN @period_type = 1 THEN 'Q' + CAST(DATEPART(QUARTER, order_date) AS VARCHAR)
            WHEN @period_type = 2 THEN FORMAT(order_date, 'MMMM', 'pl-PL')
            WHEN @period_type = 3 THEN 'Week ' + CAST(DATEPART(WEEK, order_date) AS VARCHAR)
            ELSE 'Annual'
        END AS [Period_Label],

        SUM(quantity) AS [Total_Units],
        SUM(total_needed_working_hours) as [Total_needed_working_hours],
        ROUND(SUM(line_revenue), 2) AS [Total_Sales],
        ROUND(SUM(total_production_cost), 2) AS [Total_Production_Costs],
        
        -- Średni koszt wytworzenia jednostki w danym okresie
        CASE 
            WHEN SUM(quantity) = 0 THEN 0 
            ELSE ROUND(SUM(total_production_cost) / SUM(quantity), 2) 
        END AS [Avg_Unit_Cost],
        
        ROUND(SUM(line_revenue) - SUM(total_production_cost), 2) AS [Net_Profit]

    FROM BaseData
    GROUP BY 
        CASE 
            WHEN @group_by_category = 1 THEN CAST(category_id AS VARCHAR) 
            ELSE CAST(product_id AS VARCHAR) 
        END,
        CASE 
            WHEN @group_by_category = 1 THEN category_name 
            ELSE product_name 
        END,
        YEAR(order_date),
        CASE 
            WHEN @period_type = 1 THEN 'Q' + CAST(DATEPART(QUARTER, order_date) AS VARCHAR)
            WHEN @period_type = 2 THEN FORMAT(order_date, 'MMMM', 'pl-PL')
            WHEN @period_type = 3 THEN 'Week ' + CAST(DATEPART(WEEK, order_date) AS VARCHAR)
            ELSE 'Annual'
        END,
        CASE 
            WHEN @period_type = 1 THEN CAST(DATEPART(QUARTER, order_date) AS VARCHAR)
            WHEN @period_type = 2 THEN CAST(MONTH(order_date) AS VARCHAR)
            WHEN @period_type = 3 THEN CAST(DATEPART(WEEK, order_date) AS VARCHAR)
            ELSE '0'
        END
);
GO

create or alter function fn_production_costs (
    @group_by_category BIT = 1, -- 1: Wyniki per Kategoria, 0: Wyniki per Produkt (jednostkowo)
    @period_type INT = 2,        -- 0: Rok, 1: Kwartał, 2: Miesiąc, 3: Tydzień
    @work_hour_price FLOAT = 0
)
returns table as
return
(
    select ID,Name,Year,Period_Label,Total_Units,Total_needed_working_hours,Total_Production_Costs from fn_production_cost_profit_report(
        @group_by_category,
        @period_type,
        @work_hour_price
    )
);
GO


-- ==========================================
-- Production area
-- ==========================================


CREATE VIEW v_work_place_status AS
WITH CurrentProduction AS (
    SELECT 
        p.work_place_id,
        p.production_id,
        pr.product_name,
        ps.start_date,
        ps.planned_end_date,
        p.supervisor_id,
        e.first_name + ' ' + e.last_name AS supervisor_name
    FROM productions p
    JOIN products pr ON p.product_id = pr.product_id
    JOIN production_status ps ON p.production_id = ps.production_id
    JOIN Employees as e on e.employee_id=p.supervisor_id
    WHERE ps.status_id = 2        -- 'In Production'
      AND ps.end_date IS NULL     -- Jeszcze nie zakończona
)
SELECT 
    wp.work_place_id,
    wp.work_place_description,
    cp.production_id,
    cp.product_name AS current_product,
    cp.start_date,
    cp.planned_end_date AS estimated_free_date,
    cp.supervisor_id,
    cp.supervisor_name,
    CASE 
        WHEN cp.production_id IS NOT NULL THEN 'Zajęte'
        ELSE 'Wolne'
    END AS workplace_status
FROM work_places wp
LEFT JOIN CurrentProduction cp ON wp.work_place_id = cp.work_place_id;
GO


CREATE VIEW v_product_production_frequency AS
SELECT 
    p.product_id,
    pr.product_name,
    COUNT(p.production_id) AS production_orders_count,
    SUM(p.quantity) AS total_quantity_produced
FROM productions p
JOIN products pr ON p.product_id = pr.product_id
GROUP BY p.product_id, pr.product_name;
GO


CREATE VIEW v_production_delay_details AS
SELECT 
    p.production_id,
    pr.product_name,
    p.quantity,
    ps.start_date,
    ps.planned_end_date,
    ps.end_date AS actual_end_date,
    CASE 
        WHEN ps.end_date IS NOT NULL AND ps.end_date > ps.planned_end_date 
             THEN DATEDIFF(day, ps.planned_end_date, ps.end_date)
        WHEN ps.end_date IS NULL AND GETDATE() > ps.planned_end_date 
             THEN DATEDIFF(day, ps.planned_end_date, GETDATE())
        ELSE 0
    END AS delay_days,
    p.supervisor_id,
    p.work_place_id,
    CASE 
        WHEN (ps.end_date IS NOT NULL AND ps.end_date > ps.planned_end_date) 
             OR (ps.end_date IS NULL AND GETDATE() > ps.planned_end_date) THEN 'Opóźnienie'
        WHEN ps.end_date IS NULL AND ps.status_id = 2 THEN 'W produkcji'
        ELSE 'W terminie / Planowo'
    END AS status_delay
FROM productions p
JOIN products pr ON p.product_id = pr.product_id
JOIN production_status ps ON p.production_id = ps.production_id;
GO


CREATE VIEW v_supervisor_performance_delays AS
SELECT 
    e.employee_id,
    e.first_name + ' ' + e.last_name AS supervisor_name,
    COUNT(p.production_id) AS total_supervised,
    SUM(CASE 
        WHEN (ps.end_date IS NOT NULL AND ps.end_date > ps.planned_end_date) 
             OR (ps.end_date IS NULL AND GETDATE() > ps.planned_end_date) THEN 1 
        ELSE 0 
    END) AS count_of_delayed_productions
FROM employees e
JOIN productions p ON e.employee_id = p.supervisor_id
JOIN production_status ps ON p.production_id = ps.production_id
GROUP BY e.employee_id, e.first_name, e.last_name;
GO


CREATE VIEW v_work_place_usage_stats AS
SELECT 
    wp.work_place_id,
    wp.work_place_description,
    COUNT(p.production_id) AS total_productions_handled
FROM work_places wp
LEFT JOIN productions p ON wp.work_place_id = p.work_place_id
GROUP BY wp.work_place_id, wp.work_place_description;
GO


CREATE VIEW v_employee_availability_calendar AS
WITH CurrentWork AS (
 -- jeżeli pracownik pracuje, to kiedy kończ?
    SELECT 
        pta.employee_id,
        MAX(ps.planned_end_date) AS busy_until
    FROM production_team_assignments pta
    JOIN production_status ps ON pta.production_id = ps.production_id
    WHERE ps.status_id = 2 AND ps.end_date IS NULL
    GROUP BY pta.employee_id
),
NextTimeOff AS (
    -- najbliższy urlop
    SELECT 
        employee_id,
        MIN(start_date) AS next_off_start
    FROM employee_time_offs
    WHERE start_date >= GETDATE()
    GROUP BY employee_id
)
SELECT 
    e.employee_id AS [Employee ID],
    e.first_name + ' ' + e.last_name AS [Full Name],
    e.email,
    r.possition_name AS [Role],
    cw.busy_until AS [Available From],
    nto.next_off_start AS [Free Until (Next Time Off)],
    CASE 
        WHEN cw.busy_until IS NOT NULL THEN 'Working'
        ELSE 'Available Now'
    END AS [Current State]
FROM employees e
JOIN roles r ON e.role_id = r.role_id
LEFT JOIN CurrentWork cw ON e.employee_id = cw.employee_id
LEFT JOIN NextTimeOff nto ON e.employee_id = nto.employee_id
WHERE e.is_active = 1 
  AND e.role_id BETWEEN 1 AND 3;
GO



CREATE FUNCTION fn_get_production_team (
    @target_production_id INT
)
RETURNS TABLE
AS
RETURN (
    SELECT 
        p.production_id,
        pr.product_name,
        e.employee_id,
        e.first_name + ' ' + e.last_name AS employee_full_name,
        r.possition_name AS employee_role,
        pta.hours_logged,
        -- Dane kierownika produkcji
        p.supervisor_id AS production_supervisor_id,
        sup.first_name + ' ' + sup.last_name AS production_supervisor_name
    FROM productions p
    JOIN products pr ON p.product_id = pr.product_id
    JOIN production_team_assignments pta ON p.production_id = pta.production_id
    JOIN employees e ON pta.employee_id = e.employee_id
    JOIN roles r ON e.role_id = r.role_id
    JOIN employees sup ON p.supervisor_id = sup.employee_id
    WHERE p.production_id = @target_production_id
);
GO


CREATE FUNCTION fn_get_employee_production_assignments (
    @employee_info NVARCHAR(255)
)
RETURNS TABLE
AS
RETURN (
    SELECT 
        e.employee_id,
        e.first_name + ' ' + e.last_name AS employee_name,
        e.email,
        p.production_id,
        pr.product_name,
        p.quantity AS quantity_to_make,
        s.status_name AS production_current_status,
        pta.hours_logged,
        p.supervisor_id,
        CONCAT(e2.first_name,' ',e2.last_name) as production_supervisor_name,
        e2.email as production_supervisor_email
    FROM employees e
    JOIN production_team_assignments pta ON e.employee_id = pta.employee_id
    JOIN productions p ON pta.production_id = p.production_id
    JOIN products pr ON p.product_id = pr.product_id
    JOIN production_status ps ON p.production_id = ps.production_id
    JOIN status_for_production s ON ps.status_id = s.status_id
    JOIN employees as e2 on e2.employee_id=p.supervisor_id
    WHERE 
        (CAST(e.employee_id AS NVARCHAR) = @employee_info OR e.email = @employee_info)
        AND ps.end_date IS NULL
);
GO


CREATE OR ALTER FUNCTION fn_production_cost_report (
    @group_by_category BIT = 1, -- 1: wg kategorii, 0: ogółem
    @period_type INT = 2        -- 0: Rok, 1: Kwartał, 2: Miesiąc
)
RETURNS TABLE
AS
RETURN
(
    WITH PartPrices AS (
        SELECT 
            part_id, 
            e)AVG(pric AS avg_part_price
        FROM supplier_offers
        GROUP BY part_id
    ),
    BaseData AS (
        SELECT 
            p.category_id,
            cp.name AS category_name,
            o.order_date,
            od.quantity,
            (od.quantity * pr.quantity_needed * pp.avg_part_price) AS line_part_cost,
            (od.quantity * od.unit_price * (1 - ISNULL(o.order_discount, 0))) AS line_revenue
        FROM products p
        JOIN categories_for_product cp ON p.category_id = cp.category_id
        JOIN order_details od ON p.product_id = od.product_id
        JOIN orders o ON od.order_id = o.order_id
        JOIN product_recipes pr ON p.product_id = pr.product_id
        JOIN PartPrices pp ON pr.part_id = pp.part_id
    )
    SELECT 
        CASE WHEN @group_by_category = 1 THEN CAST(category_id AS VARCHAR) ELSE 'ALL' END AS [ID],
        CASE WHEN @group_by_category = 1 THEN category_name ELSE 'Wszystkie Kategorie' END AS [Category_Name],
        
        YEAR(order_date) AS [Year],
        
        CASE 
            WHEN @period_type = 1 THEN 'Q' + CAST(DATEPART(QUARTER, order_date) AS VARCHAR)
            WHEN @period_type = 2 THEN FORMAT(order_date, 'MMMM', 'pl-PL')
            ELSE 'Annual'
        END AS [Period_Label],

        SUM(quantity) AS [Total_Units],
        ROUND(SUM(line_revenue), 2) AS [Total_Sales],
        ROUND(SUM(line_part_cost), 2) AS [Total_Est_Costs],
        
        CASE 
            WHEN SUM(quantity) = 0 THEN 0 
            ELSE ROUND(SUM(line_part_cost) / SUM(quantity), 2) 
        END AS [Avg_Unit_Cost],
        
        ROUND(SUM(line_revenue) - SUM(line_part_cost), 2) AS [Net_Income]

    FROM BaseData
    GROUP BY 
        CASE WHEN @group_by_category = 1 THEN CAST(category_id AS VARCHAR) ELSE 'ALL' END,
        CASE WHEN @group_by_category = 1 THEN category_name ELSE 'Wszystkie Kategorie' END,
        YEAR(order_date),
        -- Logika grupowania czasu
        CASE 
            WHEN @period_type = 1 THEN 'Q' + CAST(DATEPART(QUARTER, order_date) AS VARCHAR)
            WHEN @period_type = 2 THEN FORMAT(order_date, 'MMMM', 'pl-PL')
            ELSE 'Annual'
        END,
        CASE 
            WHEN @period_type = 1 THEN CAST(DATEPART(QUARTER, order_date) AS VARCHAR)
            WHEN @period_type = 2 THEN CAST(MONTH(order_date) AS VARCHAR)
            ELSE '0'
        END
);
GO


-- ==========================================
-- Order area
-- ==========================================


CREATE VIEW v_daily_order_stats AS
SELECT 
    CAST(o.order_date AS DATE) AS report_date,
    COUNT(DISTINCT o.order_id) AS total_orders_placed,
    SUM(od.quantity * od.unit_price * (1 - o.order_discount)) AS value_placed_today,
    (SELECT COUNT(DISTINCT os2.order_id) 
     FROM order_status os2 
     JOIN status_for_order s2 ON os2.status_id = s2.status_id 
     WHERE s2.status_name = 'Completed' 
       AND CAST(os2.end_date AS DATE) = CAST(o.order_date AS DATE)) AS orders_completed_today,
    (SELECT SUM(od2.quantity * od2.unit_price * (1 - o2.order_discount))
     FROM order_details od2
     JOIN orders o2 ON od2.order_id = o2.order_id
     JOIN order_status os2 ON o2.order_id = os2.order_id
     JOIN status_for_order s2 ON os2.status_id = s2.status_id
     WHERE s2.status_name = 'Completed' 
       AND CAST(os2.end_date AS DATE) = CAST(o.order_date AS DATE)) AS value_completed_today
FROM orders o
JOIN order_details od ON o.order_id = od.order_id
GROUP BY CAST(o.order_date AS DATE);
GO


CREATE VIEW v_order_financial_summary AS
SELECT 
    o.order_id,
    s.status_name AS current_status,
    SUM(od.quantity * od.unit_price * (1 - o.order_discount)) AS total_net_value,
    SUM((od.quantity * od.unit_price * (1 - o.order_discount)) * (1 + ISNULL(v.amount, 0))) AS total_gross_value
FROM orders o
JOIN order_details od ON o.order_id = od.order_id
JOIN order_status os ON o.order_id = os.order_id
JOIN status_for_order s ON os.status_id = s.status_id
LEFT JOIN products_vat pv ON od.product_id = pv.product_id 
    AND o.order_date >= pv.start_date 
    AND (pv.end_date IS NULL OR o.order_date <= pv.end_date)
LEFT JOIN vat v ON pv.vat_id = v.vat_id
WHERE os.order_status_id = (SELECT MAX(order_status_id) FROM order_status WHERE order_id = o.order_id)
GROUP BY o.order_id, s.status_name;
GO


CREATE VIEW v_active_delayed_orders AS
SELECT 
    o.order_id,
    o.order_date,
    os.planned_end_date AS current_deadline,
    s.status_name AS current_status,
    DATEDIFF(day, os.planned_end_date, GETDATE()) AS days_overdue
FROM orders o
JOIN order_status os ON o.order_id = os.order_id
JOIN status_for_order s ON os.status_id = s.status_id
WHERE os.order_status_id = (SELECT MAX(os2.order_status_id) FROM order_status os2 WHERE os2.order_id = o.order_id)
  AND s.status_name NOT IN ('Completed', 'Suspended', 'Cancelled', 'Return')
  AND os.end_date IS NULL
  AND os.planned_end_date < GETDATE();
GO


CREATE VIEW v_orders_scheduled_today AS
SELECT 
    o.order_id,
    o.client_id,
    s.status_name,
    os.start_date AS status_started_at
FROM orders o
JOIN order_status os ON o.order_id = os.order_id
JOIN status_for_order s ON os.status_id = s.status_id
WHERE os.order_status_id = (SELECT MAX(os2.order_status_id) FROM order_status os2 WHERE os2.order_id = o.order_id)
  AND CAST(os.start_date AS DATE) = CAST(GETDATE() AS DATE);
GO


CREATE VIEW v_total_orders_scheduled_per_day AS
SELECT 
    CAST(os.planned_end_date AS DATE) AS planned_date,
    COUNT(DISTINCT os.order_id) AS total_orders_to_finish
FROM order_status os
WHERE os.order_status_id = (SELECT MAX(os2.order_status_id) FROM order_status os2 WHERE os2.order_id = os.order_id)
  AND os.end_date IS NULL -- Tylko trwające etapy
GROUP BY CAST(os.planned_end_date AS DATE);
GO


CREATE VIEW v_critical_orders_due_today AS
SELECT 
    o.order_id,
    COALESCE(cc.company_name, ci.first_name + ' ' + ci.last_name) AS client_name,
    os.planned_end_date,
    s.status_name
FROM orders o
JOIN order_status os ON o.order_id = os.order_id
JOIN status_for_order s ON os.status_id = s.status_id
LEFT JOIN clients_company cc ON o.client_id = cc.client_id
LEFT JOIN clients_individual ci ON o.client_id = ci.client_id
WHERE os.order_status_id = (SELECT MAX(os2.order_status_id) FROM order_status os2 WHERE os2.order_id = o.order_id)
  AND CAST(os.planned_end_date AS DATE) = CAST(GETDATE() AS DATE)
  AND s.status_name NOT IN ('Completed', 'Cancelled');
GO

CREATE FUNCTION fn_get_client_purchase_history (
    @client_info NVARCHAR(255), -- ID klienta LUB jego email
    @date_from DATE,
    @date_to DATE
)
RETURNS TABLE
AS
RETURN (
    SELECT 
        o.client_id,
        c.email AS client_email,
        o.order_id,
        o.order_date,
        p.product_name,
        od.quantity,
        od.unit_price,
        o.order_discount,
        (od.quantity * od.unit_price * (1 - o.order_discount)) AS final_line_value
    FROM orders o
    JOIN clients c ON o.client_id = c.client_id
    JOIN order_details od ON o.order_id = od.order_id
    JOIN products p ON od.product_id = p.product_id
    WHERE 
        (
            CAST(o.client_id AS NVARCHAR) = @client_info 
            OR 
            c.email = @client_info
        )
        AND CAST(o.order_date AS DATE) BETWEEN @date_from AND @date_to
);
GO


CREATE FUNCTION fn_estimate_order_delivery (@order_id INT)
RETURNS DATETIME
AS
BEGIN
    DECLARE @final_date DATETIME;
    DECLARE @shipping_buffer INT = 2; -- dni od zakończenia zamówienia do jego wysłania
    DECLARE @total_work_places INT;

    SELECT @total_work_places = COUNT(*) FROM work_places; -- ile mamy stanowisk?

    SELECT @final_date = MAX(ItemCompletionDate)
    FROM (
        SELECT 
            od.product_id,
            CASE 
                -- scenario 1: wszystko na stanie
                WHEN ip.available_units >= od.quantity THEN GETDATE()

                -- scneario 2: nie na stanie, ale zaplanowane lub w produkcji (status 1 i 2)
                WHEN EXISTS (SELECT 1 FROM productions p 
                             JOIN production_status ps ON p.production_id = ps.production_id
                             WHERE p.product_id = od.product_id AND ps.end_date IS NULL AND ps.status_id IN (1,2))
                    THEN (
                        SELECT 
                            CASE 
                            -- jeżeli w produkcji to bieżemy planowane zakończenie tego statusu
                            -- jeżeli zaplanowane to planowaną datę zakończenia etapu planned + czas na wykonanie 
                                WHEN ps.status_id = 2 THEN ps.planned_end_date 
                                WHEN ps.status_id = 1 THEN DATEADD(HOUR, p_info.needed_hours * p.quantity, GETDATE())
                                ELSE ps.planned_end_date 
                            END
                        FROM production_status ps 
                        JOIN productions p ON ps.production_id = p.production_id
                        WHERE p.product_id = od.product_id AND ps.end_date IS NULL AND ps.status_id IN (1,2)
                    )

                -- scenario 3: nie ma w planned anie w In Production więc trzeba oszacowac kiedy dodana produkcja będzie zrealizowana
                -- w tym wypadku: suma godzin na produkcjie o statusie 1 i 2 / ilość stanowisk / 24
                ELSE 
                    DATEADD(DAY, 
                        -- 1. Obliczanie kolejki (backlog) na stanowiskach
                        ISNULL((
                            SELECT 
                                CEILING(
                                    (SUM(p_q.quantity * prod_q.needed_hours) / CAST(@total_work_places AS FLOAT)) / 24.0
                                )
                            FROM productions p_q
                            JOIN products prod_q ON p_q.product_id = prod_q.product_id
                            JOIN production_status ps_q ON p_q.production_id = ps_q.production_id
                            WHERE ps_q.status_id IN (1, 2) AND ps_q.end_date IS NULL
                        ), 0) +
                        --  + czas oczekiwania na wymagane części, jeżeli ich brakuje
                        ISNULL((
                            SELECT MAX(so.delivery_days)
                            FROM product_recipes pr
                            JOIN inventory_parts inv_p ON pr.part_id = inv_p.part_id
                            JOIN (SELECT part_id, MIN(delivery_days) as delivery_days FROM supplier_offers GROUP BY part_id) so ON pr.part_id = so.part_id
                            WHERE pr.product_id = od.product_id AND inv_p.available_units < (pr.quantity_needed * od.quantity)
                        ), 0) +
                        --  + czas potrzebny na produkcję
                        CEILING((CAST(od.quantity AS FLOAT) * ISNULL(p_info.needed_hours, 1)) / 24.0),
                        GETDATE()
                    )
            END AS ItemCompletionDate
        FROM order_details od
        LEFT JOIN inventory_products ip ON od.product_id = ip.product_id
        LEFT JOIN products p_info ON od.product_id = p_info.product_id
        WHERE od.order_id = @order_id
    ) AS ItemEstimates;

    RETURN DATEADD(DAY, @shipping_buffer, @final_date);
END;
GO


-- ==========================================
-- Extra for UI area
-- ==========================================


CREATE VIEW v_ui_product_categories AS
SELECT 
    category_id, 
    name AS category_name
FROM categories_for_product;
GO


CREATE VIEW v_ui_part_categories AS
SELECT 
    category_id, 
    name AS category_name
FROM categories_for_part;
GO


CREATE VIEW v_ui_employee_roles AS
SELECT 
    role_id, 
    possition_name, 
    description
FROM roles;
GO


CREATE VIEW v_ui_production_statuses AS
SELECT 
    status_id, 
    status_name
FROM status_for_production;
GO


CREATE VIEW v_ui_order_statuses AS
SELECT 
    status_id, 
    status_name
FROM status_for_order;
GO
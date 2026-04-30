-- =============================================
2 -- 1. INDEKSY UNIKALNE (Integralnosc danych)
3 -- =============================================
4
5 -- Slowniki kategorii
6 CREATE UNIQUE INDEX categories_for_part_idx_1 ON categories_for_part (name ASC);
7 CREATE UNIQUE INDEX categories_for_product_idx_1 ON categories_for_product (name ASC);
8
9 -- Klienci i Firmy (unikalne dane kontaktowe/identyfikacyjne)
10 CREATE UNIQUE INDEX clients_idx_1 ON clients (phone ASC, email ASC);
11 CREATE UNIQUE INDEX clients_company_idx_1 ON clients_company (company_name ASC, nip ASC);
12
13 -- Pracownicy i Role
14 CREATE UNIQUE INDEX employees_idx_1 ON employees (email ASC, phone ASC); 
15 CREATE UNIQUE INDEX roles_idx_1 ON roles (possition_name ASC);
16
17 -- Dostawcy i Przewoznicy
18 CREATE UNIQUE INDEX shippers_idx_1 ON shippers (company_name ASC);
19 CREATE UNIQUE INDEX suppliers_idx_1 ON suppliers (company_name ASC, email ASC);
20
21 -- Slowniki statusow
22 CREATE UNIQUE INDEX status_for_order_idx_1 ON status_for_order (status_name ASC);
23 CREATE UNIQUE INDEX status_for_production_idx_1 ON status_for_production (status_name ASC
);
24
25 -- =============================================
26 -- 2. INDEKSY WYDAJNOSCIOWE (Optymalizacja)
27 -- =============================================
28
29 CREATE INDEX IX_ProductRecipes_ProductId ON product_recipes(product_id);
30 -- Przyspiesza wyszukiwanie receptury dla danego produktu (JOIN products-recipes)
31
32 CREATE INDEX IX_Orders_OrderDate ON orders(order_date) INCLUDE(client_id, order_discount)
;
33 -- Optymalizuje raportowanie sprzedazy wg dat (przyspiesza widoki statystyczne)
34
35 CREATE INDEX IX_ProductionStatus_StartDate ON production_status(start_date) INCLUDE(
production_id);
36 -- Przyspiesza filtrowanie produkcji po dacie rozpoczecia (np. w kalendarzu)
# Baza danych ERP/MRP dla firmy produkcyjno-usługowej (meble)

Relacyjna baza danych zaprojektowana dla firmy z branży meblarskiej, obsługująca pełny przepływ danych biznesowych: od klientów i zamówień, przez magazyn i dostawy, aż po produkcję, pracowników, płatności i raportowanie.  
Projekt obejmuje 29 tabel, 28 widoków oraz rozbudowaną logikę biznesową zaimplementowaną w postaci funkcji, wyzwalaczy i procedur składowanych.

## Cel projektu

Celem projektu było stworzenie spójnej bazy danych wspierającej realne procesy w firmie produkcyjno-usługowej:
- obsługę klientów indywidualnych i firmowych,
- realizację zamówień,
- kontrolę stanów magazynowych,
- planowanie i nadzorowanie produkcji,
- obsługę dostawców,
- analizę rentowności i opóźnień,
- zarządzanie pracownikami i dostępnością zasobów.

## Najważniejsze obszary systemu

### Obsługa klientów i zamówień
Baza rozróżnia klientów firmowych i indywidualnych, przechowuje dane kontaktowe, historię zamówień, statusy realizacji oraz informacje o płatnościach i dostawach.

### Magazyn i produkty
Projekt zawiera katalog produktów i części, kategorie słownikowe, receptury BOM, stany magazynowe oraz historię stawek VAT dla produktów. Dzięki temu można kontrolować zarówno surowce, jak i wyroby gotowe.

### Produkcja
System obejmuje zlecenia produkcyjne, statusy produkcji, przypisania pracowników do zleceń oraz stanowiska pracy. Uwzględnia też opóźnienia i planowanie produkcji.

### Dostawcy i zakupy
W bazie znajdują się dostawcy, oferty dostawców, zamówienia części oraz mechanizmy pozwalające analizować opóźnienia i skuteczność dostaw.

### Pracownicy i organizacja pracy
Projekt zawiera tabelę pracowników, role, nieobecności oraz widoki związane z dostępnością i obciążeniem pracą.

## Co wyróżnia ten projekt

- normalizacja danych i spójny model relacyjny,
- szerokie użycie kluczy obcych i ograniczeń integralności,
- logika biznesowa w bazie danych,
- automatyzacja procesów magazynowych i produkcyjnych,
- widoki analityczne i raportowe,
- historia statusów zamówień i produkcji,
- podejście zbliżone do systemu ERP/MRP.

## Logika biznesowa

W projekcie zaimplementowano:
- **funkcje** do wyszukiwania i raportowania,
- **wyzwalacze** do automatyzacji działań,
- **procedury składowane** do bezpiecznych operacji CRUD i workflow.

Przykładowe mechanizmy:
- automatyczna aktualizacja stanów magazynowych,
- automatyczne planowanie produkcji przy niskim stanie produktów,
- obsługa zamówień części,
- rejestracja i analiza opóźnień,
- zestawienia finansowe i operacyjne.

## Warstwa raportowa

Projekt zawiera 28 widoków, które wspierają analizę i pracę operacyjną. Obejmują m.in.:
- stany magazynowe,
- ofertę dostawców,
- opóźnienia dostaw,
- statystyki klientów,
- sprzedaż produktów,
- rentowność,
- wykorzystanie stanowisk pracy,
- dostępność pracowników,
- terminowość zamówień i produkcji.

## Przykładowe zastosowanie

1. Klient składa zamówienie.
2. System zapisuje pozycje zamówienia i kontroluje status realizacji.
3. Jeśli stan magazynowy jest niewystarczający, uruchamiane są procesy uzupełniania lub planowania produkcji.
4. Zamówienie przechodzi kolejne etapy realizacji.
5. Dane trafiają do widoków analitycznych i raportowych.


## Zawartość repozytorium

- schemat bazy danych,
- definicje tabel i ograniczeń,
- relacje między tabelami,
- widoki raportowe,
- funkcje, wyzwalacze i procedury składowane,
- dane generowane do testów,
- role i indeksy.

---

## Podsumowanie

**ERP/MRP database dla firmy meblarskiej** to projekt pokazujący pełne podejście do projektowania systemu bazodanowego: od modelu danych, przez integrację procesów operacyjnych, aż po raportowanie i automatyzację.
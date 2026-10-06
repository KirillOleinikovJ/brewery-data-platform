# Projektübersicht

Die Datenplattform verarbeitet Verkaufs-, Produkt- und Wetterdaten in einer gemeinsamen Datenpipeline.

Für aggregierte Verkaufsanalysen werden ausschließlich abgeschlossene Bestellungen berücksichtigt.

Die Daten werden in PostgreSQL nach Raw-, Staging- und Mart-Schichten organisiert.


# Datenquellen

Die Verkaufs- und Produktdaten stammen aus CSV-Dateien und werden in PostgreSQL geladen.

Die Wetterdaten werden über die Open-Meteo REST API abgerufen.

Die Wetterdaten werden anhand des Datums mit den Verkaufsdaten verknüpft.


# Raw Layer

Die Rohdaten werden in den Tabellen raw.sales, raw.products und raw.weather gespeichert.


# Staging Layer

Die Staging-Schicht bereinigt ungültige Werte, entfernt Duplikate und vereinheitlicht Datentypen.

Doppelte Verkaufsdatensätze werden anhand der sale_id mithilfe von ROW_NUMBER() entfernt.

Verkaufsdatensätze mit einer Menge kleiner oder gleich null werden während der Datenbereinigung ausgeschlossen.

Fehlende Werte in customer_type werden in der Staging-Schicht durch den Wert unknown ersetzt.

Verkaufsdatensätze werden nur übernommen, wenn die product_id einem bekannten Produkt entspricht.


# Mart Layer

Die Tabelle mart.dim_products enthält die bereinigten Produktattribute.

Die Tabelle mart.fact_sales enthält einzelne bereinigte Verkaufsdatensätze und den berechneten Umsatz pro Verkauf.

Die Tabelle mart.daily_sales enthält tägliche Verkaufskennzahlen pro Produkt für abgeschlossene Bestellungen.

Die Tabelle mart.product_performance enthält aggregierte Leistungskennzahlen für einzelne Produkte.

Die Tabelle mart.region_sales enthält aggregierte Verkaufskennzahlen nach Kundenregion.

Die Tabelle mart.daily_sales_weather kombiniert tägliche Verkaufskennzahlen mit Wetterdaten.


# Umsatzberechnung

Der Umsatz wird als quantity multipliziert mit unit_price_eur und dem Faktor eins minus discount_pct berechnet.


# Airflow

Apache Airflow orchestriert die Datenpipeline von der Rohdatenaufnahme bis zur Erstellung der Mart-Tabellen.

Die Verkaufs- und Produktdaten sowie die Wetterdaten werden in getrennten Pipeline-Zweigen verarbeitet und anschließend zusammengeführt.

Am Ende der Pipeline wird geprüft, ob die wichtigsten Raw-, Staging- und Mart-Tabellen Daten enthalten.


# FastAPI

FastAPI stellt die aufbereiteten Daten über REST-Endpunkte wie /regions, /products/performance, /sales/daily, /sales-weather, /summary und /ask bereit.


# RAG

Der RAG-Assistent verwendet multilingual-e5-small für Embeddings, pgvector für die semantische Suche und Qwen über Ollama für die Generierung deutscher Antworten.
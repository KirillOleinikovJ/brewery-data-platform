# Brewery Data Platform & RAG Assistant

End-to-end data engineering project for processing brewery sales, product, and weather data.

The project combines ETL pipelines, PostgreSQL data modeling, Apache Airflow orchestration, REST APIs, and a local Retrieval-Augmented Generation (RAG) assistant based on embeddings, pgvector, and a local LLM.

---

## Architecture

```text
Sales CSV ────────┐
                  │
Products CSV ─────┼────> PostgreSQL RAW
                  │             │
Open-Meteo API ──┘             ▼
                            STAGING
                               │
                               ▼
                              MART
                         ┌──────┴──────┐
                         ▼             ▼
                     FastAPI          RAG
                                       │
                              multilingual-e5
                                       │
                                    pgvector
                                       │
                                   Retrieval
                                       │
                                     Qwen
                                       │
                                    Ollama
```

---

## Tech Stack

- Python
- PostgreSQL
- SQL
- Apache Airflow
- Docker
- FastAPI
- SQLAlchemy
- REST APIs
- pgvector
- Sentence Transformers
- `intfloat/multilingual-e5-small`
- Ollama
- Qwen2.5
- RAG

---

## Data Pipeline

The project uses a layered PostgreSQL architecture.

### Raw Layer

Stores source data before transformation.

Tables:

- `raw.sales`
- `raw.products`
- `raw.weather`

Sales and product data are loaded from CSV files.

Weather data is retrieved from the Open-Meteo REST API.

### Staging Layer

The staging layer cleans and standardizes the source data.

Main transformations include:

- duplicate removal
- data type conversion
- invalid quantity filtering
- invalid price filtering
- discount validation
- product ID validation
- missing customer type handling
- order status validation
- sales channel validation

Tables:

- `staging.sales`
- `staging.products`
- `staging.weather`

### Mart Layer

The mart layer contains analytics-ready datasets.

Tables:

- `mart.dim_products`
- `mart.fact_sales`
- `mart.dim_date`
- `mart.daily_sales`
- `mart.product_performance`
- `mart.region_sales`
- `mart.daily_sales_weather`

Only completed orders are used for the main sales aggregations.

---

## Apache Airflow

Apache Airflow orchestrates the ETL pipeline.

The DAG contains separate sales/product and weather branches that are processed independently and later joined in the analytical mart layer.

```text
Sales + Products
       │
       ▼
      RAW
       │
       ▼
    STAGING
       │
       ▼
      MART
       │
       ├──────────────┐
       │              │
       │              ▼
       │      mart.daily_sales_weather
       │              ▲
       │              │
Weather API           │
       │              │
       ▼              │
      RAW             │
       │              │
       ▼              │
    STAGING ──────────┘
```

The pipeline:

- initializes the required database schemas
- loads sales and product data
- retrieves weather data from Open-Meteo
- creates staging tables
- creates analytical mart tables
- combines sales and weather data
- validates that the main pipeline tables contain data

---

## FastAPI

The analytical data is exposed through a REST API.

| Method | Endpoint | Description |
|---|---|---|
| GET | `/health` | API health check |
| GET | `/regions` | Regional sales metrics |
| GET | `/regions/{region}` | Metrics for a specific region |
| GET | `/products/performance` | Product performance metrics |
| GET | `/sales/daily` | Daily sales with optional date filters |
| GET | `/sales-weather` | Combined sales and weather data |
| GET | `/summary` | Main business KPIs |
| POST | `/ask` | RAG-based question answering |

Swagger UI:

```text
http://127.0.0.1:8002/docs
```

---

## RAG Assistant

The project includes a local Retrieval-Augmented Generation pipeline.

The knowledge base is stored in:

```text
data/project_knowledge.md
```

### Ingestion

```text
Markdown document
        │
        ▼
Text chunks
        │
        ▼
multilingual-e5-small
        │
        ▼
384-dimensional embeddings
        │
        ▼
PostgreSQL + pgvector
```

The ingestion script reads the knowledge document, creates embeddings, and stores each chunk together with its source in `rag.chunks`.

### Retrieval and Generation

When a user asks a question:

```text
Question
   │
   ▼
Query embedding
   │
   ▼
pgvector similarity search
   │
   ▼
Top 3 relevant chunks
   │
   ▼
Context + original question
   │
   ▼
Qwen2.5 through Ollama
   │
   ▼
German answer
```

The `/ask` endpoint also returns the retrieved sources and similarity scores.

Example request:

```json
{
  "question": "Woher kommen die Wetterdaten?"
}
```

Example response:

```json
{
  "question": "Woher kommen die Wetterdaten?",
  "answer": "Die Wetterdaten stammen aus der Open-Meteo REST API.",
  "sources": [
    {
      "source": "project_knowledge.md",
      "content": "Die Wetterdaten werden über die Open-Meteo REST API abgerufen.",
      "similarity": 0.91
    }
  ]
}
```

---

## Screenshots

### Airflow Pipeline

![Airflow DAG](screenshots/airflow_dag.png)

### FastAPI Endpoints

![FastAPI Swagger](screenshots/swagger_endpoints.png)

### RAG Assistant

![RAG Response](screenshots/rag_response.png)

---

## Project Structure

```text
brauer/
│
├── airflow/
│   ├── dags/
│   │   └── brewery_pipeline.py
│   └── docker-compose.yaml
│
├── api/
│   └── main.py
│
├── data/
│   ├── products.csv
│   ├── sales_raw.csv
│   └── project_knowledge.md
│
├── rag/
│   ├── __init__.py
│   ├── ingest.py
│   └── service.py
│
├── screenshots/
│   ├── airflow_dag.png
│   ├── swagger_endpoints.png
│   └── rag_response.png
│
├── sql/
│   ├── 01_data_quality_sales.sql
│   ├── 02_data_staging.sql
│   ├── 03_create_mart.sql
│   ├── 04_weather.sql
│   └── 05_mart_weather.sql
│
├── db.py
├── .env.example
├── .gitignore
├── requirements.txt
└── README.md
```

---

## Local Setup

### 1. Clone the repository

```bash
git clone https://github.com/KirillOleinikovJ/brewery-data-platform.git
cd brewery-data-platform
```

### 2. Create a virtual environment

Windows PowerShell:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
```

Install dependencies:

```powershell
pip install -r requirements.txt
```

### 3. Configure environment variables

Copy `.env.example` to `.env` and configure your local credentials.

Example:

```env
DATA_DB_URL=postgresql+psycopg://postgres:YOUR_PASSWORD@localhost:5432/brauer_db
VECTOR_DB_URL=postgresql+psycopg://postgres:YOUR_PASSWORD@localhost:5433/brauer_vector
OLLAMA_URL=http://localhost:11434/api/generate
OLLAMA_MODEL=qwen2.5:3b
```

---

## PostgreSQL + pgvector

The analytical PostgreSQL database is expected on port `5432`.

The vector database can be started with Docker:

```powershell
docker run -d --name brauer-pgvector `
  -e POSTGRES_USER=postgres `
  -e POSTGRES_PASSWORD=YOUR_PASSWORD `
  -e POSTGRES_DB=brauer_vector `
  -p 5433:5432 `
  -v brauer_pgvector_data:/var/lib/postgresql `
  pgvector/pgvector:pg18
```

Enable pgvector:

```sql
CREATE EXTENSION IF NOT EXISTS vector;
```

Create the RAG schema and table:

```sql
CREATE SCHEMA IF NOT EXISTS rag;

CREATE TABLE IF NOT EXISTS rag.chunks (
    id BIGSERIAL PRIMARY KEY,
    source TEXT NOT NULL,
    content TEXT NOT NULL,
    embedding VECTOR(384) NOT NULL
);
```

---

## RAG Knowledge Ingestion

Load the knowledge document into pgvector:

```powershell
python -m rag.ingest
```

The script:

- reads `project_knowledge.md`
- splits the document into chunks
- generates embeddings
- stores the chunks and embeddings in PostgreSQL

---

## Ollama

Install Ollama and download the local model:

```powershell
ollama pull qwen2.5:3b
```

Check installed models:

```powershell
ollama list
```

---

## Run FastAPI

```powershell
python -m uvicorn api.main:app --port 8002
```

Open Swagger UI:

```text
http://127.0.0.1:8002/docs
```

---

## Run Airflow

From the Airflow directory:

```powershell
cd airflow
docker compose up -d
```

Airflow UI:

```text
http://localhost:8080
```

The DAG expects an Airflow PostgreSQL connection named:

```text
brewery_postgres
```

---

## Data Quality

The project contains SQL checks for:

- duplicate IDs
- NULL values
- invalid quantities
- invalid prices
- discount ranges
- invalid status values
- invalid sales channels
- foreign key mismatches
- weather date duplicates
- invalid precipitation values

The Airflow DAG also performs a final runtime validation to ensure that the main raw, staging, and mart tables contain data.

---

## Project Goals

This project demonstrates:

- end-to-end data pipeline development
- SQL transformations
- layered data modeling
- data quality checks
- workflow orchestration
- REST API development
- external API integration
- Docker-based infrastructure
- semantic vector search
- Retrieval-Augmented Generation
- local LLM integration

---

## Notes

- Sales and product data are synthetic and used for demonstration purposes.
- Weather data is retrieved from Open-Meteo.
- Secrets and local credentials are excluded from the repository through `.gitignore`.
- The project is designed as a portfolio project for data engineering, analytics, and AI-related working student roles.

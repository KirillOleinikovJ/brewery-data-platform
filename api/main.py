from datetime import date

from fastapi import FastAPI
from pydantic import BaseModel
from sqlalchemy import text

from db import engine
from rag.service import answer_question


app = FastAPI(
    title="Brewery Data Platform API",
    version="1.0.0"
)


class QuestionRequest(BaseModel):
    question: str


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/regions")
def get_regions():
    query = text("""
        SELECT *
        FROM mart.region_sales
        ORDER BY total_revenue_eur DESC;
    """)

    with engine.connect() as conn:
        result = conn.execute(query)
        rows = result.mappings().all()

    return [dict(row) for row in rows]


@app.get("/regions/{region}")
def get_region(region: str):
    query = text("""
        SELECT *
        FROM mart.region_sales
        WHERE customer_region = :region;
    """)

    with engine.connect() as conn:
        result = conn.execute(
            query,
            {"region": region}
        )
        rows = result.mappings().all()

    return [dict(row) for row in rows]


@app.get("/products/performance")
def get_product_performance():
    query = text("""
        SELECT *
        FROM mart.product_performance
        ORDER BY total_revenue_eur DESC;
    """)

    with engine.connect() as conn:
        result = conn.execute(query)
        rows = result.mappings().all()

    return [dict(row) for row in rows]


@app.get("/sales/daily")
def get_daily_sales(
    start: date | None = None,
    end: date | None = None
):
    query = text("""
        SELECT *
        FROM mart.daily_sales
        WHERE (
            CAST(:start AS DATE) IS NULL
            OR sale_date >= CAST(:start AS DATE)
        )
        AND (
            CAST(:end AS DATE) IS NULL
            OR sale_date <= CAST(:end AS DATE)
        )
        ORDER BY sale_date;
    """)

    with engine.connect() as conn:
        result = conn.execute(
            query,
            {
                "start": start,
                "end": end
            }
        )
        rows = result.mappings().all()

    return [dict(row) for row in rows]


@app.get("/sales-weather")
def get_sales_weather():
    query = text("""
        SELECT *
        FROM mart.daily_sales_weather
        ORDER BY sale_date, product_id;
    """)

    with engine.connect() as conn:
        result = conn.execute(query)
        rows = result.mappings().all()

    return [dict(row) for row in rows]


@app.get("/summary")
def get_summary():
    query = text("""
        SELECT
            SUM(total_revenue_eur) AS total_revenue_eur,
            SUM(total_quantity) AS total_quantity,
            SUM(sales_count) AS sales_count,
            COUNT(DISTINCT product_id) AS products_count
        FROM mart.daily_sales;
    """)

    with engine.connect() as conn:
        result = conn.execute(query)
        row = result.mappings().one()

    return dict(row)


@app.post("/ask")
def ask_question(request: QuestionRequest):
    result = answer_question(request.question)

    return {
        "question": request.question,
        "answer": result["answer"],
        "sources": result["sources"]
    }
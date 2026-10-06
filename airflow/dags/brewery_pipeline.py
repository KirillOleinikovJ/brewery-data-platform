from datetime import datetime

from airflow.sdk import dag, task


# ============================================================
# Project configuration
# ============================================================

POSTGRES_CONN_ID = "brewery_postgres"

RAW_SALES_PATH = "/opt/airflow/data/sales_raw.csv"
RAW_PRODUCTS_PATH = "/opt/airflow/data/products.csv"

STAGING_SALES_SQL = "/opt/airflow/sql/02_data_staging.sql"
MART_SALES_SQL = "/opt/airflow/sql/03_create_mart.sql"
STAGING_WEATHER_SQL = "/opt/airflow/sql/04_weather.sql"
MART_WEATHER_SQL = "/opt/airflow/sql/05_mart_weather.sql"


# ============================================================
# Helper functions
# ============================================================

def get_postgres_engine():
    """
    Create a SQLAlchemy engine using the PostgreSQL
    connection configured in Airflow.
    """
    from airflow.sdk.bases.hook import BaseHook

    hook = BaseHook.get_hook(conn_id=POSTGRES_CONN_ID)

    return hook.get_sqlalchemy_engine()


def execute_sql_file(file_path):
    """
    Read a SQL file, split it into individual statements,
    and execute them inside one transaction.
    """
    from pathlib import Path

    import sqlparse
    from sqlalchemy import text

    engine = get_postgres_engine()

    sql_content = Path(file_path).read_text(
        encoding="utf-8"
    )

    statements = sqlparse.split(sql_content)

    with engine.begin() as connection:
        for statement in statements:
            if statement.strip():
                connection.execute(
                    text(statement)
                )


# ============================================================
# DAG definition
# ============================================================

@dag(
    dag_id="brewery_pipeline",
    schedule=None,
    start_date=datetime(2026, 1, 1),
    catchup=False,
)
def brewery_pipeline():

    # ========================================================
    # DATABASE INITIALIZATION
    # ========================================================

    @task
    def initialize_database():
        """
        Create the PostgreSQL schemas required by the pipeline
        if they do not already exist.
        """
        from sqlalchemy import text

        engine = get_postgres_engine()

        with engine.begin() as connection:
            connection.execute(
                text("CREATE SCHEMA IF NOT EXISTS raw")
            )
            connection.execute(
                text("CREATE SCHEMA IF NOT EXISTS staging")
            )
            connection.execute(
                text("CREATE SCHEMA IF NOT EXISTS mart")
            )

        print("Database schemas initialized successfully")


    # ========================================================
    # WEATHER PIPELINE
    # ========================================================

    @task
    def extract_weather():
        """
        Extract historical daily weather data
        from the Open-Meteo API.
        """
        import requests

        url = "https://archive-api.open-meteo.com/v1/archive"

        params = {
            "latitude": 49.95,
            "longitude": 11.58,
            "start_date": "2025-09-01",
            "end_date": "2026-08-31",
            "daily": [
                "temperature_2m_mean",
                "temperature_2m_max",
                "temperature_2m_min",
                "precipitation_sum",
                "weather_code",
            ],
            "timezone": "Europe/Berlin",
        }

        response = requests.get(
            url,
            params=params,
            timeout=30,
        )

        response.raise_for_status()

        daily = response.json()["daily"]

        print(
            f"Weather records received: {len(daily['time'])}"
        )

        return daily


    @task
    def prepare_weather(daily):
        """
        Convert weather API data into tabular records
        that can be passed through Airflow XCom.
        """
        import pandas as pd

        weather_df = pd.DataFrame(daily)

        weather_df = weather_df.rename(
            columns={
                "time": "weather_date"
            }
        )

        print(
            f"Prepared weather rows: {len(weather_df)}"
        )

        return weather_df.to_dict(
            orient="records"
        )


    @task
    def load_raw_weather(prepared_data):
        """
        Load weather data into raw.weather.
        """
        import pandas as pd

        weather_df = pd.DataFrame(
            prepared_data
        )

        engine = get_postgres_engine()

        weather_df.to_sql(
            name="weather",
            con=engine,
            schema="raw",
            if_exists="replace",
            index=False,
        )

        print(
            f"Loaded {len(weather_df)} rows into raw.weather"
        )


    @task
    def create_staging_weather():
        """
        Execute the SQL transformation
        for staging.weather.
        """
        execute_sql_file(
            STAGING_WEATHER_SQL
        )

        print(
            "Weather staging SQL executed successfully"
        )


    # ========================================================
    # SALES / PRODUCTS PIPELINE
    # ========================================================

    @task
    def load_raw_sales():
        """
        Load the raw sales CSV file into raw.sales.
        """
        import pandas as pd

        sales_df = pd.read_csv(
            RAW_SALES_PATH
        )

        engine = get_postgres_engine()

        sales_df.to_sql(
            name="sales",
            con=engine,
            schema="raw",
            if_exists="replace",
            index=False,
        )

        print(
            f"Loaded {len(sales_df)} rows into raw.sales"
        )


    @task
    def load_raw_products():
        """
        Load the products CSV file into raw.products.
        """
        import pandas as pd

        products_df = pd.read_csv(
            RAW_PRODUCTS_PATH
        )

        engine = get_postgres_engine()

        products_df.to_sql(
            name="products",
            con=engine,
            schema="raw",
            if_exists="replace",
            index=False,
        )

        print(
            f"Loaded {len(products_df)} rows into raw.products"
        )


    @task
    def create_staging_sales_products():
        """
        Execute SQL transformations for
        staging.sales and staging.products.
        """
        execute_sql_file(
            STAGING_SALES_SQL
        )

        print(
            "Sales/products staging SQL executed successfully"
        )


    @task
    def create_mart_sales():
        """
        Build the analytical MART tables
        from staging sales and product data.
        """
        execute_sql_file(
            MART_SALES_SQL
        )

        print(
            "Sales MART SQL executed successfully"
        )


    # ========================================================
    # SALES + WEATHER MART
    # ========================================================

    @task
    def create_mart_weather():
        """
        Combine sales and weather data
        into mart.daily_sales_weather.
        """
        execute_sql_file(
            MART_WEATHER_SQL
        )

        print(
            "Sales/weather MART SQL executed successfully"
        )


    # ========================================================
    # PIPELINE VALIDATION
    # ========================================================

    @task
    def validate_pipeline():
        """
        Validate that the main pipeline tables contain data.
        Fail the task if a required table is empty.
        """
        from sqlalchemy import text

        engine = get_postgres_engine()

        tables = [
            "raw.sales",
            "raw.products",
            "raw.weather",
            "staging.sales",
            "staging.products",
            "staging.weather",
            "mart.daily_sales",
            "mart.daily_sales_weather",
        ]

        with engine.connect() as connection:
            for table in tables:

                count = connection.execute(
                    text(
                        f"SELECT COUNT(*) FROM {table}"
                    )
                ).scalar_one()

                print(
                    f"{table}: {count} rows"
                )

                if count == 0:
                    raise ValueError(
                        f"Validation failed: {table} is empty"
                    )

        print(
            "Pipeline validation completed successfully"
        )


    # ========================================================
    # TASK DEPENDENCIES
    # ========================================================

    initialize = initialize_database()


    # Sales/products branch
    load_sales = load_raw_sales()
    load_products = load_raw_products()

    staging_sales_products = (
        create_staging_sales_products()
    )

    mart_sales = create_mart_sales()

    initialize >> [
        load_sales,
        load_products,
    ]

    [
        load_sales,
        load_products,
    ] >> staging_sales_products >> mart_sales


    # Weather branch
    weather_data = extract_weather()

    prepared_weather = prepare_weather(
        weather_data
    )

    load_weather = load_raw_weather(
        prepared_weather
    )

    staging_weather = (
        create_staging_weather()
    )

    initialize >> load_weather

    load_weather >> staging_weather


    # Final integration
    mart_weather = create_mart_weather()

    validation = validate_pipeline()

    [
        mart_sales,
        staging_weather,
    ] >> mart_weather >> validation


brewery_pipeline()
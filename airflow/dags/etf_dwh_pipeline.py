import sys
sys.path.insert(0, '/opt/airflow/elt')

from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator
from elt_script import run_etl

default_args = {
    "owner": "airflow",
    "retries": 2,
    "retry_delay": timedelta(minutes=5),
    "email_on_failure": False,
}

with DAG(
    dag_id="etf_dwh_pipeline",
    description="ETF DWH: Alpha Vantage -> raw -> DBT Star Schema -> Reports",
    default_args=default_args,
    start_date=datetime(2024, 1, 1),
    schedule="0 22 * * 1-5",
    catchup=False,
    tags=["dwh", "etf", "alphavantage"],
) as dag:

    extract_and_load_raw = PythonOperator(
        task_id="extract_and_load_raw",
        python_callable=run_etl,
    )

    dbt_staging = BashOperator(
        task_id="dbt_staging",
        bash_command="cd /opt/dbt && dbt run --select staging --profiles-dir /opt/dbt",
    )

    dbt_facts = BashOperator(
        task_id="dbt_facts",
        bash_command="cd /opt/dbt && dbt run --select fact_etf_prices --profiles-dir /opt/dbt",
    )

    dbt_reports = BashOperator(
        task_id="dbt_reports",
        bash_command="cd /opt/dbt && dbt run --select report_daily_performance report_volatility_ranking report_etf_correlation --profiles-dir /opt/dbt",
    )

    dbt_test = BashOperator(
        task_id="dbt_test",
        bash_command="cd /opt/dbt && dbt test --profiles-dir /opt/dbt",
    )

    extract_and_load_raw >> dbt_staging >> dbt_facts >> dbt_reports >> dbt_test

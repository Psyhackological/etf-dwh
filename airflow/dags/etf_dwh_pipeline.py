from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator
import subprocess
import sys

default_args = {
    "owner": "airflow",
    "retries": 2,
    "retry_delay": timedelta(minutes=5),
    "email_on_failure": False,
}


def run_elt():
    result = subprocess.run(
        [sys.executable, "/opt/airflow/elt/elt_script.py"],
        capture_output=True,
        text=True,
    )
    print(result.stdout)
    if result.returncode != 0:
        raise RuntimeError(f"ELT failed:\n{result.stderr}")


with DAG(
    dag_id="etf_dwh_pipeline",
    description="ETF DWH: Alpha Vantage -> raw -> DBT Star Schema -> Reports",
    default_args=default_args,
    start_date=datetime(2024, 1, 1),
    schedule_interval="0 22 * * 1-5",
    catchup=False,
    tags=["dwh", "etf", "alphavantage"],
) as dag:

    t1_extract_load = PythonOperator(
        task_id="extract_and_load_raw",
        python_callable=run_elt,
    )

    t2_dbt_staging = BashOperator(
        task_id="dbt_staging",
        bash_command="cd /opt/dbt && dbt run --select staging --profiles-dir /opt/dbt",
    )

    t4_dbt_facts = BashOperator(
        task_id="dbt_facts",
        bash_command="cd /opt/dbt && dbt run --select fact_etf_prices --profiles-dir /opt/dbt",
    )

    t5_dbt_reports = BashOperator(
        task_id="dbt_reports",
        bash_command="cd /opt/dbt && dbt run --select report_daily_performance report_volatility_ranking report_etf_correlation --profiles-dir /opt/dbt",
    )

    t6_dbt_test = BashOperator(
        task_id="dbt_test",
        bash_command="cd /opt/dbt && dbt test --profiles-dir /opt/dbt",
    )

    t1_extract_load >> t2_dbt_staging >> t4_dbt_facts >> t5_dbt_reports >> t6_dbt_test


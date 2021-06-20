from airflow import DAG
from airflow.operators.bash_operator import BashOperator
from datetime import datetime, timedelta

default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'start_date': datetime(2021, 1, 15),
}

dag = DAG(  'test_dag',
            schedule_interval='0 0 * * *' ,
            catchup=False,
            default_args=default_args
            )

t1 = BashOperator(
    task_id='test_task',
    bash_command='date',
    dag=dag
)

t1
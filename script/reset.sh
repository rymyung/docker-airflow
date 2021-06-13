echo "============ stop containers"
docker stop docker-airflow_webserver_1
docker stop docker-airflow_flower_1
docker stop docker-airflow_scheduler_1
docker stop docker-airflow_worker_1
docker stop docker-airflow_init_1
docker stop docker-airflow_redis_1
docker stop docker-airflow_postgres_1

echo "============ remove containers"
docker rm docker-airflow_webserver_1
docker rm docker-airflow_flower_1
docker rm docker-airflow_scheduler_1
docker rm docker-airflow_worker_1
docker rm docker-airflow_init_1
docker rm docker-airflow_redis_1
docker rm docker-airflow_postgres_1

echo "============ remove image"
docker rmi sist/airflow:2.1.0
docker build -t sist/airflow:2.1.0 .

echo "============ remove & create directory"
rm -r airflow
rm -r pgdata

mkdir airflow
mkdir pgdata

echo "============ check containers"
docker ps -a

#echo "============ check images"
#docker images

echo "============ done"

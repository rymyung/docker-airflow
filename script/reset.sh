echo "============ stop containers"
docker stop docker-airflow_airflow-scheduler_1
docker stop docker-airflow_airflow-worker_1
docker stop docker-airflow_airflow-webserver_1
docker stop docker-airflow_flower_1
docker stop docker-airflow_airflow-init_1
docker stop docker-airflow_postgres_1
docker stop docker-airflow_redis_1

echo "============ remove containers"
docker rm docker-airflow_airflow-scheduler_1
docker rm docker-airflow_airflow-worker_1
docker rm docker-airflow_airflow-webserver_1
docker rm docker-airflow_flower_1
docker rm docker-airflow_airflow-init_1
docker rm docker-airflow_postgres_1
docker rm docker-airflow_redis_1

#echo "============ remove image"
#docker rmi docker-airflow_webserver

echo "============ remove & create directory"
rm -r airflow
rm -r pgdata

mkdir airflow
mkdir pgdata

echo "============ check containers"
docker ps -a

echo "============ check images"
docker images

echo "============ done"

FROM python:3.8-slim-buster

ARG AIRFLOW_VERSION=2.1.0
ARG AIRFLOW_USER_HOME=/airflow
ENV AIRFLOW_HOME=${AIRFLOW_USER_HOME}

RUN apt-get update
RUN apt-get -y install gcc
RUN apt-get -y install g++
RUN apt-get -y install vim
RUN apt-get -y install libpq-dev
RUN pip install --upgrade pip setuptools wheel
RUN pip install numpy
RUN pip install Cython
RUN pip install pendulum
RUN pip install --no-use-pep517 pandas
RUN pip install --no-use-pep517 apache-airflow==2.1.0
RUN pip install psycopg2
RUN pip install celery
RUN pip install flower
RUN pip install redis
RUN mkdir airflow

COPY ./script/entrypoint.sh /entrypoint.sh

EXPOSE 8080 5555

WORKDIR ${AIRFLOW_USER_HOME}

RUN useradd airflow_user
RUN chown -R airflow_user ${AIRFLOW_USER_HOME}
RUN chmod 777 /entrypoint.sh

ENTRYPOINT ["sh", "/entrypoint.sh"]
CMD ["webserver"]
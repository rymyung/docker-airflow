FROM python:3.8-slim-buster

ARG AIRFLOW_VERSION=2.1.0
ARG AIRFLOW_USER_HOME=/airflow
ENV AIRFLOW_HOME=${AIRFLOW_USER_HOME}

RUN apt-get update
RUN apt-get -y install gcc
RUN apt-get -y install g++
RUN apt-get -y install vim
RUN apt-get -y install procps
RUN apt-get -y install netcat
RUN apt-get -y install libpq-dev
RUN apt-get -y install libsasl2-dev
RUN pip install --upgrade pip setuptools wheel
RUN pip install numpy
RUN pip install Cython
RUN pip install pendulum
RUN pip install celery
RUN pip install flower
RUN pip install redis
RUN pip install sasl
RUN pip install thrift_sasl
RUN pip install --no-use-pep517 pandas
RUN pip install --no-use-pep517 apache-airflow[hive,druid,slack,postgres,celery,ssh,slack]==2.1.0
RUN pip install psycopg2
RUN mkdir airflow

COPY ./script/entrypoint.sh /entrypoint.sh

WORKDIR ${AIRFLOW_USER_HOME}

RUN groupadd -g 200 puser
RUN useradd -r -u 200 -g puser puser
RUN chown -R puser ${AIRFLOW_USER_HOME}
#RUN chmod puser ${AIRFLOW_USER_HOME}

USER puser

ENTRYPOINT ["bash", "/entrypoint.sh"]


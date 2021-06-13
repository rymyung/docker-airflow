#!/bin/bash
TRY_LOOP="100"
# Global defaults and back-compat
: "${AIRFLOW_HOME:="/airflow"}"
: "${AIRFLOW__CORE__EXECUTOR:=${EXECUTOR:-Sequential}Executor}"
#: "${AIRFLOW__CORE__FERNET_KEY:=${FERNET_KEY:=$(python -c "from cryptography.fernet import Fernet; FERNET_KEY = Fernet.generate_key().decode(); print(FERNET_KEY)")}}"


# Load DAGs examples (default: Yes)
if [[ -z "$AIRFLOW__CORE__LOAD_EXAMPLES" && "${LOAD_EX:=n}" == n ]]; then
  AIRFLOW__CORE__LOAD_EXAMPLES=False
fi

export \
  AIRFLOW_HOME \
  AIRFLOW__CORE__EXECUTOR \
  AIRFLOW__CORE__LOAD_EXAMPLES \
  AIRFLOW__CORE__SQL_ALCHEMY_CONN \
  AIRFLOW__CELERY__BROKER_URL \
  AIRFLOW__CELERY__RESULT_BACKEND \


create_airflow_user() {
  airflow users create \
  --username "$AF_USER_NAME" \
  --firstname "$AF_USER_FIRST_NAME" \
  --lastname "$AF_USER_LAST_NAME" \
  --role "$AF_USER_ROLE" \
  --email "$AF_USER_EMAIL" \
  --password "$AF_USER_PASSWORD"
}

# Other executors than SequentialExecutor drive the need for an SQL database, here PostgreSQL is used
if [ "$AIRFLOW__CORE__EXECUTOR" != "SequentialExecutor" ]; then
  # Check if the user has provided explicit Airflow configuration concerning the database
  if [ -z "$AIRFLOW__CORE__SQL_ALCHEMY_CONN" ]; then
    
    # Default values corresponding to the default compose files
    : "${POSTGRES_HOST:="postgres"}"
    : "${POSTGRES_PORT:="5432"}"
    : "${POSTGRES_USER:="sist_admin"}"
    : "${POSTGRES_PASSWORD:="admin"}"
    : "${POSTGRES_DB:="airflow_si_dev"}"
    AIRFLOW__CORE__SQL_ALCHEMY_CONN="postgresql+psycopg2://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRESDB}"
    export AIRFLOW__CORE__SQL_ALCHEMY_CONN

    # Check if the user has provided explicit Airflow configuration for the broker's connection to the database
    if [ "$AIRFLOW__CORE__EXECUTOR" = "CeleryExecutor" ]; then
      AIRFLOW__CELERY__RESULT_BACKEND="db+postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRESDB}"
      export AIRFLOW__CELERY__RESULT_BACKEND
    fi
  else
    if [[ "$AIRFLOW__CORE__EXECUTOR" == "CeleryExecutor" && -z "$AIRFLOW__CELERY__RESULT_BACKEND" ]]; then
      >&2 printf '%s\n' "FATAL: if you set AIRFLOW__CORE__SQL_ALCHEMY_CONN manually with CeleryExecutor you must also set AIRFLOW__CELERY__RESULT_BACKEND"
      exit 1
    fi

    # Derive useful variables from the AIRFLOW__ variables provided explicitly by the user
    #POSTGRES_ENDPOINT=$(echo -n "$AIRFLOW__CORE__SQL_ALCHEMY_CONN" | cut -d '/' -f3 | sed -e 's,.*@,,') # example : 0.0.0.0
    #POSTGRES_HOST=$(echo -n "$POSTGRES_ENDPOINT" | cut -d ':' -f1) # 
    #POSTGRES_PORT=$(echo -n "$POSTGRES_ENDPOINT" | cut -d ':' -f2)
  fi

fi


if [ -z "$AIRFLOW__CELERY__BROKER_URL" ]; then
  # Default values corresponding to the default compose files
  : "${REDIS_PROTO:="redis://"}"
  : "${REDIS_HOST:="redis"}"
  : "${REDIS_PORT:="6379"}"
  : "${REDIS_PASSWORD:=""}"
  : "${REDIS_DBNUM:="1"}"

  # When Redis is secured by basic auth, it does not handle the username part of basic auth, only a token
  if [ -n "$REDIS_PASSWORD" ]; then
    REDIS_PREFIX=":${REDIS_PASSWORD}@"
  else
    REDIS_PREFIX=
  fi

  AIRFLOW__CELERY__BROKER_URL="redis://redis:6379/0"
  export AIRFLOW__CELERY__BROKER_URL
fi


case "$1" in
  webserver)
    airflow version
    airflow db init
    create_airflow_user
    sleep 10
    if [ "$AIRFLOW__CORE__EXECUTOR" = "LocalExecutor" ] || [ "$AIRFLOW__CORE__EXECUTOR" = "SequentialExecutor" ]; then
      # With the "Local" and "Sequential" executors it should all run in one container.
      airflow scheduler &
    fi
    exec airflow webserver
    ;;
  worker)
    # Give the webserver time to run initdb.
    sleep 60
    exec airflow "$@" 
    ;;
  scheduler)
    # Give the webserver time to run initdb.
    sleep 60
    exec airflow "$@"
    ;;
  flower)
    sleep 60
    exec airflow "$@"
    ;;
  *)
    # The command is something like bash, not an airflow subcommand. Just run it in the right environment.
    exec "$@"
    ;;
esac
#!/bin/bash

AIRFLOW_COMMAND="${1:-}"


function run_check_with_retries {
    local cmd
    cmd="${1}"
    local countdown
    countdown="${CONNECTION_CHECK_MAX_COUNT}"

    while true
    do
        set +e
        local last_check_result
        local res
        last_check_result=$(eval "${cmd} 2>&1")
        res=$?
        set -e
        if [[ ${res} == 0 ]]; then
            echo
            break
        else
            echo -n "."
            countdown=$((countdown-1))
        fi
        if [[ ${countdown} == 0 ]]; then
            echo
            echo "ERROR! Maximum number of retries (${CONNECTION_CHECK_MAX_COUNT}) reached."
            echo
            echo "Last check result:"
            echo "$ ${cmd}"
            echo "${last_check_result}"
            echo
            exit 1
        else
            sleep "${CONNECTION_CHECK_SLEEP_TIME}"
        fi
    done
}

function run_nc() {
    # Checks if it is possible to connect to the host using netcat.
    #
    # We want to avoid misleading messages and perform only forward lookup of the service IP address.
    # Netcat when run without -n performs both forward and reverse lookup and fails if the reverse
    # lookup name does not match the original name even if the host is reachable via IP. This happens
    # randomly with docker-compose in GitHub Actions.
    # Since we are not using reverse lookup elsewhere, we can perform forward lookup in python
    # And use the IP in NC and add '-n' switch to disable any DNS use.
    # Even if this message might be harmless, it might hide the real reason for the problem
    # Which is the long time needed to start some services, seeing this message might be totally misleading
    # when you try to analyse the problem, that's why it's best to avoid it,
    local host="${1}"
    local port="${2}"
    local ip
    ip=$(python -c "import socket; print(socket.gethostbyname('${host}'))")
    nc -zvvn "${ip}" "${port}"
}

function wait_for_connection {
    # Waits for Connection to the backend specified via URL passed as first parameter
    # Detects backend type depending on the URL schema and assigns
    # default port numbers if not specified in the URL.
    # Then it loops until connection to the host/port specified can be established
    # It tries `CONNECTION_CHECK_MAX_COUNT` times and sleeps `CONNECTION_CHECK_SLEEP_TIME` between checks
    local connection_url
    connection_url="${1}"
    local detected_backend=""
    local detected_host=""
    local detected_port=""

    # Auto-detect DB parameters
    # Examples:
    #  postgres://YourUserName:password@YourHostname:5432/YourDatabaseName
    #  postgres://YourUserName:password@YourHostname:5432/YourDatabaseName
    #  postgres://YourUserName:@YourHostname:/YourDatabaseName
    #  postgres://YourUserName@YourHostname/YourDatabaseName
    [[ ${connection_url} =~ ([^:]*)://([^:@]*):?([^@]*)@?([^/:]*):?([0-9]*)/([^\?]*)\??(.*) ]] && \
        detected_backend=${BASH_REMATCH[1]} &&
        # Not used USER match
        # Not used PASSWORD match
        detected_host=${BASH_REMATCH[4]} &&
        detected_port=${BASH_REMATCH[5]} &&
        # Not used SCHEMA match
        # Not used PARAMS match

    echo BACKEND="${BACKEND:=${detected_backend}}"
    readonly BACKEND

    if [[ -z "${detected_port=}" ]]; then
        if [[ ${BACKEND} == "postgres"* ]]; then
            detected_port=5432
        elif [[ ${BACKEND} == "mysql"* ]]; then
            detected_port=3306
        elif [[ ${BACKEND} == "redis"* ]]; then
            detected_port=6379
        elif [[ ${BACKEND} == "amqp"* ]]; then
            detected_port=5672
        fi
    fi

    detected_host=${detected_host:="localhost"}

    # Allow the DB parameters to be overridden by environment variable
    echo DB_HOST="${DB_HOST:=${detected_host}}"
    readonly DB_HOST

    echo DB_PORT="${DB_PORT:=${detected_port}}"
    readonly DB_PORT
    run_check_with_retries "run_nc ${DB_HOST@Q} ${DB_PORT@Q}"
}


wait_for_airflow_db() {
    # Check if Airflow has a command to check the connection to the database.
    if ! airflow db check --help >/dev/null 2>&1; then
        run_check_with_retries "airflow db check"
    else
        # Verify connections to the Airflow DB by guessing the database address based on environment variables,
        # then uses netcat to check that the host is reachable.
        # This is only used by Airflow 1.10+ as there are no built-in commands to check the db connection.
        local connection_url
        if [[ -n "${AIRFLOW__CORE__SQL_ALCHEMY_CONN_CMD=}" ]]; then
            connection_url="$(eval "${AIRFLOW__CORE__SQL_ALCHEMY_CONN_CMD}")"
        else
            # if no DB configured - use sqlite db by default
            connection_url="${AIRFLOW__CORE__SQL_ALCHEMY_CONN:="sqlite:///${AIRFLOW_HOME}/airflow.db"}"
        fi
        # SQLite doesn't require a remote connection, so we don't have to wait.
        if [[ ${connection_url} != sqlite* ]]; then
            wait_for_connection "${connection_url}"
        fi
    fi
}


create_airflow_user() {
  airflow users create \
     --username "${_AIRFLOW_USER_USERNAME="admin"}" \
     --firstname "${_AIRFLOW_USER_FIRSTNAME="Airflow"}" \
     --lastname "${_AIRFLOW_USER_LASTNAME="Admin"}" \
     --email "${_AIRFLOW_USER_EMAIL="airflowadmin@example.com"}" \
     --role "${_AIRFLOW_USER_ROLE="Admin"}" \
     --password "${_AIRFLOW_USER_PASSWORD="admin"}"
}

init_db() {
  #airflow db init
  airflow db upgrade
}


CONNECTION_CHECK_MAX_COUNT=${CONNECTION_CHECK_MAX_COUNT:=20}
readonly CONNECTION_CHECK_MAX_COUNT


CONNECTION_CHECK_SLEEP_TIME=${CONNECTION_CHECK_SLEEP_TIME:=5}
readonly CONNECTION_CHECK_SLEEP_TIME


if [[ "${CONNECTION_CHECK_MAX_COUNT}" -gt "0" ]]; then
    wait_for_airflow_db
fi



if [[ -n "${_AIRFLOW_DB_INIT=}" ]] ; then
  echo "Start db initialization."
  init_db
  echo "Finish db initialization."
fi


if [[ -n "${_AIRFLOW_USER_CREATE=}" ]] ; then
  echo "Create airflow user."
  create_airflow_user
  echo "Finish creating airflow user."
fi


exec "airflow" "${@}"

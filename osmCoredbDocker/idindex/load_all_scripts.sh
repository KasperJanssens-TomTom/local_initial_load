#!/bin/bash
set -ex

function show_usage {
  echo
  echo "Usage: $0 [OPTION]"
  echo "run scripts"
  echo
  echo "  --database=NAME        [Required] Database name where the direct load will be performed"
  echo "  --port=PORT        [Required] Database name where the direct load will be performed"
  echo "  --user=USER          [Required] User for authorization to the destination database"
  echo "  --db_pwd=DB_PWD [Required] Password for authorization to the destination database"
  echo "  --user=USER          [Required] User for authorization to the destination database"
  echo "  -help, --help              Show this help"
  exit 1
}


if [ $# -eq 0 ]; then
  echo "There are mandatory parameters"
  show_usage
fi

for i in "$@"; do
  case $i in
  --database=*)
    DATABASE="${i#*=}"
    shift
    ;;
  --user=*)
    USER="${i#*=}"
    shift
    ;;
  --port=*)
    PORT="${i#*=}"
    shift
    ;;
  --db_pwd=*)
    DB_PWD="${i#*=}"
    shift
    ;;
  -help | --help)
    show_usage
    ;;
  *)
    echo "unknown option: ${i#*=}"
    show_usage
    ;;
  esac
done

PGPASSWORD="${DB_PWD}" psql -h localhost -U "${USER}" -p "${PORT}" -d "${DATABASE}" -f 001_create_insert_all_stored_proc.sql
PGPASSWORD="${DB_PWD}" psql -h localhost -U "${USER}" -p "${PORT}" -d "${DATABASE}" -f 002_create_insert_index_data_stored_proc.sql
PGPASSWORD="${DB_PWD}" psql -h localhost -U "${USER}" -p "${PORT}" -d "${DATABASE}" -f 003_create_index_schema.sql
PGPASSWORD="${DB_PWD}" psql -h localhost -U "${USER}" -p "${PORT}" -d "${DATABASE}" -f 004_grant_permissions.sql
PGPASSWORD="${DB_PWD}" psql -h localhost -U "${USER}" -p "${PORT}" -d "${DATABASE}" -f 005_prepare_index_table.sql
PGPASSWORD="${DB_PWD}" psql -h localhost -U "${USER}" -p "${PORT}" -d "${DATABASE}" -f 006_run_store_proc.sql #this runs it for the first table, feature
PGPASSWORD="${DB_PWD}" psql -h localhost -U "${USER}" -p "${PORT}" -d "${DATABASE}" -f 006_run_store_proc.sql # this runs it for the second table, attributes
PGPASSWORD="${DB_PWD}" psql -h localhost -U "${USER}" -p "${PORT}" -d "${DATABASE}" -f 007_create_localizer.sql
PGPASSWORD="${DB_PWD}" psql -h localhost -U "${USER}" -p "${PORT}" -d "${DATABASE}" -f 008_create_db_connection_settings.sql
PGPASSWORD="${DB_PWD}" psql -h localhost -U "${USER}" -p "${PORT}" -d "${DATABASE}" -f 009_create_dictionary.sql

#!/usr/bin/env bash
set -eo pipefail # Fail on errors

# following params has to be tweaked according to aurora db size, TODO do this automatically?
readonly DEFAULT_FAKE_PARALLELISM=10  # 10 - safe value for large chunks of data, 60 tested on r5.8xlarge, 120 works fine on r5.24xlarge
readonly MAX_PARALLEL_MAINTENANCE_WORKERS=4 # 8 tested fine on r5.24xlarge
readonly MAINTENANCE_WORK_MEM='4 GB' # 8 workers and 8 GB should work fine on r5.24xlarge, on r5.8xlarge it exhausted the memory while creating indexes


echo "$0 $@" > last_parameters
date '+%d/%m/%Y %H:%M:%S' > start_time_mrr

# Loads data into MRRs database.

function show_usage {
  echo
  echo "Usage: $0 [OPTION]"
  echo "Performs Direct Load with predefined parameters"
  echo
  echo "  --database=NAME        [Required] Database name where the direct load will be performed"
  echo "  --mrr-schema=NAME          [Required] MRR Schema name where the direct load will be performed"
  echo "  --user=USER          [Required] User for authorization to the destination database"
  echo "  --mrr-s3-bucket       [Required] Name of the bucket containing MRR csv data"
  echo "  --mrr-s3-path         [Optional] Location on S3 containing MRR csv data, by default it points to the root of the bucket"
  echo "  --layer-name          [Required] Layer name used for partitioning"
  echo "  --parallelism=N	[Optional] Number of parallel imports for data tables (it executes N files at once and then waits for all of them). Defaults to ${DEFAULT_FAKE_PARALLELISM}."
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
  --mrr-schema=*)
    SCHEMA="${i#*=}"
    shift
    ;;
  --user=*)
    USER="${i#*=}"
    shift
    ;;
  --mrr-s3-bucket=*)
    BUCKET="${i#*=}"
    shift
    ;;
  --mrr-s3-path=*)
    MRR_S3_PATH="${i#*=}"
    [[ "${MRR_S3_PATH}" != */ ]] && MRR_S3_PATH="${MRR_S3_PATH}/"
    [[ "${MRR_S3_PATH}" == /* ]] && MRR_S3_PATH="${MRR_S3_PATH:1}"
    [[ "${MRR_S3_PATH}" == / ]] && MRR_S3_PATH=""
    shift
    ;;
  --parallelism=*)
    FAKE_PARALLELISM="${i#*=}"
    shift
    ;;
  --layer-name=*)
    LAYER_NAME="${i#*=}"
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

[ -z "$DATABASE" ] && {
  echo "Database is a mandatory parameter"
  show_usage
}
[ -z "$USER" ] && {
  echo "User is a mandatory parameter"
  show_usage
}
[ -z "$FAKE_PARALLELISM" ] && { FAKE_PARALLELISM="${DEFAULT_FAKE_PARALLELISM}"; }

readonly PARENT_TABLE="id2id"
readonly LAYER_TABLE="${PARENT_TABLE}_${LAYER_NAME}"
#TODO add param
HOST="mrr-svc.cb3buifqsmt3.eu-west-1.rds.amazonaws.com"
readonly MRR_S3_SOURCE="s3://${BUCKET}/${MRR_S3_PATH}"

export PGPASSWORD="metarelations"

function logging {
    operation=$1
    while IFS= read -r line; do
        printf '%s%s %s\n' "[$(date +'%Y-%m-%d %H:%M:%S.%3N')]" "${operation:+[$operation]}" "${line}";
    done
}

function psql {
  command psql -v ON_ERROR_STOP=1 "$@"
}

function create-mrr-partitions {
  echo '--- Starting create-mrr-partitions ---'

  psql -h "${HOST}" -U "${USER}" -d "${DATABASE}" <<< "CREATE EXTENSION IF NOT EXISTS aws_s3 CASCADE;
  CREATE TABLE \"${SCHEMA}\".\"${LAYER_TABLE}\" (LIKE \"${SCHEMA}\".\"${PARENT_TABLE}\") PARTITION BY hash (key_a, key_b);"

  for i in 0 1 2 3 4 5 6 7 ; do
    psql -h "${HOST}" -U "${USER}" -d "${DATABASE}" <<< "CREATE TABLE \"${SCHEMA}\".\"${i}_${LAYER_TABLE}\" PARTITION OF \"${SCHEMA}\".\"${LAYER_TABLE}\" FOR VALUES WITH (MODULUS 8, REMAINDER ${i}) WITH (autovacuum_enabled = false, toast.autovacuum_enabled = false);" &
  done
  wait

  echo '--- Finished create-mrr-partitions ---'
}

function load-file {
  _FILE=$1

  aws s3 cp ${MRR_S3_SOURCE}${_FILE} ${MRR_S3_SOURCE}${_FILE} --content-encoding gzip --content-type application/octet-stream --metadata-directive REPLACE
  psql -h "${HOST}" -d "${DATABASE}" -U "${USER}" <<< "SET max_parallel_maintenance_workers = ${MAX_PARALLEL_MAINTENANCE_WORKERS}; SET maintenance_work_mem TO '${MAINTENANCE_WORK_MEM}';
  SELECT aws_s3.table_import_from_s3(
     '${LAYER_TABLE}',
     '',
     '(format csv, DELIMITER ''|'', HEADER true)',
     aws_commons.create_s3_uri('${BUCKET}', '${MRR_S3_PATH}${_FILE}', 'eu-west-1')
  );"

}

function load-mrr() {
  # load mrr table from partitioned files
  echo "load mrr"
  FILE_PREFIX="id-mapping"
  TABLE="id2id"

  _start=$(date +%s)

  matched_files=$(aws s3 ls "${MRR_S3_SOURCE}"id-mapping | rev | cut -d" " -f1 | rev)
  if [ -z "$matched_files" ]; then
    echo "For $TABLE matched no files"
  else
    for FILENAME in $matched_files; do
      echo "loading $FILENAME"
      load-file "${FILENAME}" "${USER}" "${DATABASE}" "${MDS_SCHEMA}" $TABLE > output_$TABLE &
      tasks=$((tasks + 1))

      if [ "$tasks" -ge "${FAKE_PARALLELISM}" ]; then
        wait
        tasks=0
      fi
    done
    wait
  fi

  _end=$(date +%s)
  echo "--- Finished ${TABLE} in $((_end - _start)) seconds ---"

}

function add-constraints {
  for i in 0 1 2 3 4 5 6 7; do
    psql -h "${HOST}" -U "${USER}" -d "${DATABASE}" <<< "SET max_parallel_maintenance_workers = ${MAX_PARALLEL_MAINTENANCE_WORKERS}; SET maintenance_work_mem TO '${MAINTENANCE_WORK_MEM}';
    ALTER TABLE \"${SCHEMA}\".\"${i}_${LAYER_TABLE}\" ADD CONSTRAINT \"${i}_${LAYER_NAME}_published\" EXCLUDE USING btree (layer_name WITH =, key_a WITH =, key_b WITH =, relation_name WITH =, branch WITH =, child_version WITH =) WHERE (published IS TRUE);" &
  done
  wait
}

function add-indexes {
   for i in 0 1 2 3 4 5 6 7; do
      (
           psql -h "${HOST}" -U "${USER}" -d "${DATABASE}" <<< "SET max_parallel_maintenance_workers = ${MAX_PARALLEL_MAINTENANCE_WORKERS}; SET maintenance_work_mem TO '${MAINTENANCE_WORK_MEM}'; CREATE INDEX IF NOT EXISTS \"${i}_${LAYER_NAME}_key_a\" ON \"${SCHEMA}\".\"${i}_${LAYER_TABLE}\" USING btree (key_a, relation_name, branch, child_version)"
           psql -h "${HOST}" -U "${USER}" -d "${DATABASE}" <<< "SET max_parallel_maintenance_workers = ${MAX_PARALLEL_MAINTENANCE_WORKERS}; SET maintenance_work_mem TO '${MAINTENANCE_WORK_MEM}'; CREATE INDEX IF NOT EXISTS \"${i}_${LAYER_NAME}_ext_id\" ON \"${SCHEMA}\".\"${i}_${LAYER_TABLE}\" USING btree (external_id)"
           psql -h "${HOST}" -U "${USER}" -d "${DATABASE}" <<< "SET max_parallel_maintenance_workers = ${MAX_PARALLEL_MAINTENANCE_WORKERS}; SET maintenance_work_mem TO '${MAINTENANCE_WORK_MEM}'; CREATE INDEX IF NOT EXISTS \"${i}_${LAYER_NAME}_bv_pub\" ON \"${SCHEMA}\".\"${i}_${LAYER_TABLE}\" USING btree (branch, child_version, published)"
           psql -h "${HOST}" -U "${USER}" -d "${DATABASE}" <<< "SET max_parallel_maintenance_workers = ${MAX_PARALLEL_MAINTENANCE_WORKERS}; SET maintenance_work_mem TO '${MAINTENANCE_WORK_MEM}'; CREATE INDEX IF NOT EXISTS \"${i}_${LAYER_NAME}_key_b\" ON \"${SCHEMA}\".\"${i}_${LAYER_TABLE}\" USING btree (key_b, relation_name, branch, child_version)"
           psql -h "${HOST}" -U "${USER}" -d "${DATABASE}" <<< "SET max_parallel_maintenance_workers = ${MAX_PARALLEL_MAINTENANCE_WORKERS}; SET maintenance_work_mem TO '${MAINTENANCE_WORK_MEM}'; CREATE UNIQUE INDEX IF NOT EXISTS \"${i}_${LAYER_NAME}_uk\" ON \"${SCHEMA}\".\"${i}_${LAYER_TABLE}\" USING btree (layer_name, key_a, key_b, relation_name, branch, child_version) WHERE (published = true)"
      ) #&
   done
#   wait

#  
   psql -h "${HOST}" -U "${USER}" -d "${DATABASE}" <<< "CREATE UNIQUE INDEX \"${LAYER_NAME}_uk\" ON ONLY \"${SCHEMA}\".\"${LAYER_TABLE}\" USING btree (layer_name, key_a, key_b, relation_name, branch, child_version) WHERE (published = true)" #&
   psql -h "${HOST}" -U "${USER}" -d "${DATABASE}" <<< "CREATE INDEX \"${LAYER_NAME}_key_a\" ON ONLY \"${SCHEMA}\".\"${LAYER_TABLE}\" USING btree (key_a, relation_name, branch, child_version)" #&
   psql -h "${HOST}" -U "${USER}" -d "${DATABASE}" <<< "CREATE INDEX \"${LAYER_NAME}_ext_id\" ON ONLY \"${SCHEMA}\".\"${LAYER_TABLE}\" USING btree (external_id)" #&
   psql -h "${HOST}" -U "${USER}" -d "${DATABASE}" <<< "CREATE INDEX \"${LAYER_NAME}_bv_pub\" ON ONLY \"${SCHEMA}\".\"${LAYER_TABLE}\" USING btree (branch, child_version, published)" #&
   psql -h "${HOST}" -U "${USER}" -d "${DATABASE}" <<< "CREATE INDEX \"${LAYER_NAME}_key_b\" ON ONLY \"${SCHEMA}\".\"${LAYER_TABLE}\" USING btree (key_b, relation_name, branch, child_version)" #&
#   wait
}

function attach-partition {
  psql -h "${HOST}" -U "${USER}" -d "${DATABASE}" <<< "SET max_parallel_maintenance_workers = ${MAX_PARALLEL_MAINTENANCE_WORKERS}; SET maintenance_work_mem TO '${MAINTENANCE_WORK_MEM}';
ALTER TABLE \"${SCHEMA}\".\"${LAYER_TABLE}\" ADD CONSTRAINT \"p_${LAYER_NAME}_check\" CHECK (layer_name = '${LAYER_NAME}'::text) NOT VALID;
-- does not work on RDS: UPDATE pg_catalog.pg_constraint SET convalidated = 't' WHERE contype = 'c' AND convalidated = 'f' AND connamespace = to_regnamespace('${SCHEMA}')::oid;
ALTER TABLE \"${SCHEMA}\".\"${PARENT_TABLE}\" ATTACH PARTITION \"${SCHEMA}\".\"${LAYER_TABLE}\" FOR VALUES IN ('${LAYER_NAME}');
ALTER TABLE \"${SCHEMA}\".\"${LAYER_TABLE}\" DROP CONSTRAINT \"p_${LAYER_NAME}_check\";
"
  for i in 0 1 2 3 4 5 6 7 ; do
    psql -h "${HOST}" -U "${USER}" -d "${DATABASE}" <<< "ALTER TABLE \"${SCHEMA}\".\"${i}_${LAYER_TABLE}\" SET (autovacuum_enabled = true, toast.autovacuum_enabled = true);" &
  done
  wait

}

function cleanup {
  echo "----start cleanup----"
  psql -h "${HOST}" -U "${USER}" -d "${DATABASE}" <<< "ALTER TABLE id2id DETACH PARTITION ${LAYER_TABLE};"
  psql -h "${HOST}" -U "${USER}" -d "${DATABASE}" <<< "DROP TABLE ${LAYER_TABLE};"
  echo "----end cleanup----"
}

#cleanup |& logging "cleanup"
create-mrr-partitions |& logging "create-mrr-partitions"
# adding exclusion constraint before loading data seems to be faster, than creating it afterwards (7h vs 11h of OSM Routing world scope/r5.8xlarge)
add-constraints |& logging "add-constraints"
load-mrr |& logging "load-mrr"
add-indexes |& logging "add-indexes"
attach-partition |& logging "attach-partition"
# TODO analyze?
wait

date '+%d/%m/%Y %H:%M:%S' > end_time_mrr

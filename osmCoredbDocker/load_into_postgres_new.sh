#!/usr/bin/env bash
set -eo pipefail # Fail on errors

# Constants
readonly DEFAULT_FAKE_PARALLELISM=48
echo "$0 $@" > last_parameters
date '+%d/%m/%Y %H:%M:%S' > start_time

# Loads data into SMDS. This script is designed to be run on the instance that hosts the target database.
function show_usage {
  echo
  echo "Usage: $0 [OPTION]"
  echo "Performs Direct Load with predefined parameters"
  echo
  echo "  --database=NAME        [Required] Database name where the direct load will be performed"
  echo "  --port=PORT        [Required] Database name where the direct load will be performed"
  echo "  --mds-schema=NAME          [Required] MDS Schema name where the direct load will be performed"
  echo "  --user=USER          [Required] User for authorization to the destination database"
  echo "  --db_pwd=DB_PWD [Required] Password for authorization to the destination database"
  echo "  --smds-s3-source          [Required] Location on S3 containing SMDS csv data, optional if --skip-smds is specified"
  echo "  --owner=NAME          [Optional] Owner of the SMDS relations, defaults to mds"
  echo "  --load-id=NAME         [Required] UUID used to identify load action"
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
  --port=*)
    PORT="${i#*=}"
    shift
    ;;
  --mds-schema=*)
    MDS_SCHEMA="${i#*=}"
    shift
    ;;
  --user=*)
    USER="${i#*=}"
    shift
    ;;
  --db_pwd=*)
    DB_PWD="${i#*=}"
    shift
    ;;
  --smds-s3-source=*)
    SMDS_S3_SOURCE="${i#*=}"
    [[ "${SMDS_S3_SOURCE}" != */ ]] && SMDS_S3_SOURCE="${SMDS_S3_SOURCE}/"
    shift
    ;;
  --owner=*)
    OWNER="${i#*=}"
    shift
    ;;
  --load-id=*)
    LOAD_ID="${i#*=}"
    shift
    ;;
  --parallelism=*)
    FAKE_PARALLELISM="${i#*=}"
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
[ -z "$MDS_SCHEMA" ] && {
  echo "MDS Schema is a mandatory parameter"
  show_usage
}
[ -z "$USER" ] && {
  echo "User is a mandatory parameter"
  show_usage
}
[ -z "$SMDS_S3_SOURCE" ] && {
  echo "SMDS S3 source is a mandatory parameter"
  show_usage
}
[ -z "$LOAD_ID" ] &&  {
  echo "Load Id is a mandatory parameter"
  show_usage
}
[ -z "$OWNER" ] && { OWNER="mds"; }
[ -z "$FAKE_PARALLELISM" ] && { FAKE_PARALLELISM="${DEFAULT_FAKE_PARALLELISM}"; }

tempdir="./tmp/${LOAD_ID}/input_csv"
SMDS_SOURCES="${tempdir}/smds/"

function logging {
    operation=$1
    while IFS= read -r line; do
        printf '%s%s %s\n' "[$(date +'%Y-%m-%d %H:%M:%S.%3N')]" "${operation:+[$operation]}" "${line}";
    done
}

function psql {
  command psql -v ON_ERROR_STOP=1 "$@"
}

function ensure-mds-schema-and-tables {
  echo '--- Starting ensure-mds-schema-and-tables ---'
  sed "s/%SCHEMA%/$MDS_SCHEMA/g" configuration_scripts/create_mds_schema.sql | sed "s/%OWNER%/$OWNER/g" | PGPASSWORD="${DB_PWD}" psql -p "${PORT}" -h localhost  -d "${DATABASE}" -U "$USER" -a
  echo '--- Finished ensure-mds-schema-and-tables ---'
}

function create-mds-indexes-after-loading {
  echo '--- Starting create-mds-indexes ---'
  _start=$(date +%s)
  while read -ru 10 query; do
    PGPASSWORD="${DB_PWD}" psql -d "$DATABASE" -h localhost -U "$USER" -a -v schema="${MDS_SCHEMA}" <<< "$query" &
  done 10<configuration_scripts/create_mds_indexes.sql
  wait
  _end=$(date +%s)
  echo "--- Finished create-mds-indexes in $((_end - _start)) seconds ---"
}
function create-mds-indexes-for-partitioned-tables {
  echo '--- Starting create-mds-indexes-for-partitioned-tables ---'
  _start=$(date +%s)
  for partition_suffix in 0 1 2 3 4 5 6 7 8 9 a b c d e f; do
    (
      PGPASSWORD="${DB_PWD}" psql -p "${PORT}" -d "$DATABASE" -h localhost -U "$USER" -a -e -c "ALTER TABLE ONLY ${MDS_SCHEMA}.feature_p${partition_suffix} ADD CONSTRAINT feature_p${partition_suffix}_pkey PRIMARY KEY (id);"
      PGPASSWORD="${DB_PWD}" psql -p "${PORT}" -d "$DATABASE" -h localhost -U "$USER" -a -e -c "ALTER TABLE ONLY ${MDS_SCHEMA}.association_p${partition_suffix} ADD CONSTRAINT association_p${partition_suffix}_pkey PRIMARY KEY (id);"
      PGPASSWORD="${DB_PWD}" psql -p "${PORT}" -d "$DATABASE" -h localhost -U "$USER" -a -e -c "CREATE INDEX feature_p${partition_suffix}_geometry_idx ON ${MDS_SCHEMA}.feature_p${partition_suffix} USING gist (geometry_index);"
    ) &
  done;
  wait
  _end=$(date +%s)
  echo "--- Finished create-mds-indexes-for-partitioned-tables in $((_end-_start)) seconds ---"
}

function load-file {
  _FILE=$1
  _USER=$2
  _DATABASE=$3
  _SCHEMA=$4
  _TABLE=$5
  if [ -f "${_FILE}" ]; then
    zcat "${_FILE}" | PGPASSWORD="${DB_PWD}" psql -p "${PORT}" -h localhost -U "${_USER}" -d "${_DATABASE}" -c "\COPY ""${_SCHEMA}"".""${_TABLE}"" FROM STDIN DELIMITER '|' CSV" >/dev/null && echo "[$(date +'%Y-%m-%d %H:%M:%S.%3N')][${_TABLE}] ${_FILE} OK!" >> "./output_$TABLE"
  else
    echo "File not found: ${_FILE}"
    return 1
  fi
}

function load-smds {
  echo '--- Starting load-smds ---'
  _allstart=$(date +%s)
  # load feature and attributes tables from partitioned files
  for TABLE in feature attributes feature_property_entry association association_property_entry; do
    ( load-mds-table "${TABLE}" ) &
  done
  wait
  _allend=$(date +%s)
  echo "--- Finished all data tables in $((_allend - _allstart)) seconds ---"
  # load other tables from single files
  tasks=0
  _start=$(date +%s)
  for TABLE in dictionary model_versions; do
    FILE=${SMDS_SOURCES}other/part-00000/${TABLE}".csv.gz"
    load-file "${FILE}" "${USER}" "${DATABASE}" "${MDS_SCHEMA}" $TABLE &
    tasks=$((tasks + 1))
    if [ "$tasks" -ge "${FAKE_PARALLELISM}" ]; then
      wait
      tasks=0
    fi
  done
  wait
  _end=$(date +%s)
  echo "--- Finished single-file tables in $((_end - _start)) seconds ---"
  echo '--- Finished load-smds ---'
}

function load-mds-table {
  TABLE=$1
  _start=$(date +%s)
  matched_files="$(find "${SMDS_SOURCES}" -maxdepth 4 -regex "^.*/${TABLE}+\.csv\.gz")"
  if [ -z "$matched_files" ]; then
    echo "For $TABLE matched no files"
  else
    matched_files_array=( $matched_files )
    _to_do="${#matched_files_array[@]}"
    echo "For $TABLE matched ${_to_do} files"
    _in_progress=0
    _done=0
    for FILENAME in $matched_files; do
      load-file "${FILENAME}" "${USER}" "${DATABASE}" "${MDS_SCHEMA}" "${TABLE}" &
      _in_progress=$((_in_progress + 1))
      _done=$((_done + 1))
      # wait sending after $FAKE_PARALLELISM tasks, otherwise we will fill up maximum connections in postgres
      # divide by 5 - number of tables loaded in parallel
      if [ "$_in_progress" -ge "$(( FAKE_PARALLELISM / 5 ))" ]; then
        echo "[${TABLE}][progress] ${_done}/${_to_do}..."
        wait
        _in_progress=0
      fi
    done
    wait
  fi
  _end=$(date +%s)
  echo "--- Finished ${TABLE} in $((_end - _start)) seconds ---"
}

function create-mds-constraints {
  echo '--- Starting create-mds-constraints ---'
  _start=$(date +%s)
  while read -ru 10 query; do
    PGPASSWORD="${DB_PWD}" psql -p "${PORT}" -d "$DATABASE" -h localhost -U "$USER" -a -v schema="${MDS_SCHEMA}" <<< "$query" &
  done 10<create_mds_constraints.sql
  wait
  _end=$(date +%s)
  echo "--- Finished create-mds-constraints in $((_end - _start)) seconds ---"
}

function restore-smds-params {
  echo -n 'Restoring SMDS parameters... '
  prefix_command=""
  if [ "$(id -un)" != "postgres" ]; then
    if sudo -u postgres -v 2> /dev/null ; then
      prefix_command="sudo -inu postgres"
    else
      echo "FAILED... needs to be done with postgres user, but couldn't execute the command"
      return 1
    fi
  fi
  # not through -c "command", as it starts the transaction block
  echo "ALTER system RESET ALL;" | $prefix_command psql -U "postgres" -a > /dev/null && echo 'OK'
  data_dir="$($prefix_command psql -Atc 'SHOW data_directory;')"
  $prefix_command pg_ctl -t 3600 -D "$data_dir" restart
}

function tweak-smds-params {
  echo "skipping param tweaks for now"
  #echo -n 'Setting SMDS parameters for optimal performance... '
  #prefix_command=""
  #if [ "$(id -un)" != "postgres" ]; then
  #  if sudo -u postgres -v 2> /dev/null ; then
  #    prefix_command="sudo -inu postgres"
  #  else
  #    echo "FAILED... needs to be done with postgres user, but couldn't execute the command"
  #    return 1
  #  fi
  #fi
  ## script passed through redirect - sudo -inu does not keep current dir
  #$prefix_command psql -U "postgres" -a < "tweak_db_params.sql" > /dev/null  && echo 'OK'
  #data_dir="$($prefix_command psql -Atc 'SHOW data_directory;')"
  #$prefix_command  pg_ctl -t 3600 -D "$data_dir" restart
  #trap 'restore-smds-params' EXIT
}

echo "-- CSV files will be copied to ${tempdir} --"
{
  if [[ -d "${SMDS_SOURCES}" ]] ; then
    echo "Directory '$SMDS_SOURCES' already exist, please remove it before going further"
    exit 1
  fi
  mkdir -p "$SMDS_SOURCES"
  aws s3 cp "$SMDS_S3_SOURCE" "$SMDS_SOURCES" --recursive --exclude "*idmapping.csv.gz" --exclude "*_SUCCESS"
}
echo '--- Finished file copy process---'
tweak-smds-params
ensure-mds-schema-and-tables |& logging "ensure-mds-schema-and-tables"
wait
load-smds |& logging "load-smds"
# wait for completion of all subprocesses (parallel load scripts) spawned by this script
wait
create-mds-constraints |& logging "create-mds-constraints"
create-mds-indexes-for-partitioned-tables |& logging "create-mds-indexes-for-partitioned-tables"
create-mds-indexes-after-loading |& logging "create-mds-indexes"
wait
# cleanup
rm -r "$SMDS_SOURCES"
date '+%d/%m/%Y %H:%M:%S' > end_time

#!/usr/bin/env bash
set -eo pipefail # Fail on errors

# Constants
readonly DEFAULT_FAKE_PARALLELISM=48

echo "$0 $@" > last_parameters
date '+%d/%m/%Y %H:%M:%S' > start_time

# Loads data into SMDS and idindex. This script is designed to be run on the instance that hosts the target database.

function show_usage {
  echo
  echo "Usage: $0 [OPTION]"
  echo "Performs Direct Load with predefined parameters"
  echo
  echo "  --database=NAME        [Required] Database name where the direct load will be performed"
  echo "  --mds-schema=NAME          [Required] MDS Schema name where the direct load will be performed"
  echo "  --idindex-schema=NAME        [Optional] Schema name where the idindex will be loaded, defaults to the value of the --schema parameter"
  echo "  --user=USER          [Required] User for authorization to the destination database"
  echo "  --smds-s3-source          [Required] Location on S3 containing SMDS csv data, optional if --skip-smds is specified"
  echo "  --idindex-s3-source          [Required] Location on S3 containing IdIndex csv data, optional if --skip-idindex is specified"
  echo "  --load-id=NAME         [Required] UUID used to identify load action"
  echo "  --layer-name          [Required] Layer name used for partitioning"
  echo "  --idindex-database=NAME        [Optional] Database name where idindex will be loaded, defaults to the value of the --database parameter"
  echo "  --idindex-user=USER        [Optional] User for authorization to the idindex database, defaults to the value of the --user parameter"
  echo "  --skip-smds          [Optional] Skip operations related to SMDS. If this flag is specified, database, schema and user parameters can be used as idindex parameters"
  echo "  --skip-idindex          [Optional] Skip operations related to IdIndex"
  echo "  --owner=NAME          [Optional] Owner of the SMDS relations, defaults to mds"
  echo "  --idindex-owner=NAME          [Optional] Owner of the id-index relations, defaults to cpp"
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
  --mds-schema=*)
    MDS_SCHEMA="${i#*=}"
    shift
    ;;
  --idindex-schema=*)
    IDINDEX_SCHEMA="${i#*=}"
    shift
    ;;
  --user=*)
    USER="${i#*=}"
    shift
    ;;
  --smds-s3-source=*)
    SMDS_S3_SOURCE="${i#*=}"
    [[ "${SMDS_S3_SOURCE}" != */ ]] && SMDS_S3_SOURCE="${SMDS_S3_SOURCE}/"
    shift
    ;;
  --idindex-s3-source=*)
    IDINDEX_S3_SOURCE="${i#*=}"
    [[ "${IDINDEX_S3_SOURCE}" != */ ]] && IDINDEX_S3_SOURCE="${IDINDEX_S3_SOURCE}/"
    shift
    ;;
  --load-id=*)
    LOAD_ID="${i#*=}"
    shift
    ;;
  --idindex-database=*)
    IDINDEX_DATABASE="${i#*=}"
    shift
    ;;
  --idindex-user=*)
    IDINDEX_USER="${i#*=}"
    shift
    ;;
  --skip-smds)
    SKIP_SMDS=true
    shift
    ;;
  --skip-idindex)
    SKIP_IDINDEX=true
    shift
    ;;
  --owner=*)
    OWNER="${i#*=}"
    shift
    ;;
  --parallelism=*)
    FAKE_PARALLELISM="${i#*=}"
    shift
    ;;
  --idindex-owner=*)
    IDINDEX_OWNER="${i#*=}"
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
[ -z "$MDS_SCHEMA" ] && [[ ! $SKIP_SMDS ]] && {
  echo "MDS Schema is a mandatory parameter"
  show_usage
}
[ -z "$IDINDEX_SCHEMA" ] && [[ ! $SKIP_IDINDEX ]] && {
  echo "IdIndex Schema is a mandatory parameter"
  show_usage
}
[ -z "$USER" ] && {
  echo "User is a mandatory parameter"
  show_usage
}
[ -z "$SMDS_S3_SOURCE" ] && [[ ! $SKIP_SMDS ]] && {
  echo "SMDS S3 source is a mandatory parameter"
  show_usage
}
[ -z "$IDINDEX_S3_SOURCE" ] && [[ ! $SKIP_IDINDEX ]] && {
  echo "IdIndex S3 source is a mandatory parameter"
  show_usage
}
[ -z "$LOAD_ID" ] &&  {
  echo "Load Id is a mandatory parameter"
  show_usage
}

[ -z "$IDINDEX_DATABASE" ] && { IDINDEX_DATABASE=$DATABASE; }
[ -z "$IDINDEX_USER" ] && { IDINDEX_USER=$USER; }
[ -z "$OWNER" ] && { OWNER="mds"; }
[ -z "$IDINDEX_OWNER" ] && { IDINDEX_OWNER="cpp"; }
[ -z "$FAKE_PARALLELISM" ] && { FAKE_PARALLELISM="${DEFAULT_FAKE_PARALLELISM}"; }

#tempdir="/var/lib/pgsql/${LOAD_ID}/input_csv"
tempdir=/home/dejaegel/Documents/bitbucket/direct-load-api/direct-load-service/scripts/src/main/resources/input_csv
SMDS_SOURCES="${tempdir}/smds/"
IDINDEX_SOURCES="${tempdir}/idindex/"

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
  #sed "s/%SCHEMA%/$MDS_SCHEMA/g" create_mds_schema.sql | sed "s/%OWNER%/$OWNER/g" | psql -d "$DATABASE" -U "$USER" -a
  echo '--- Finished ensure-mds-schema-and-tables ---'
}

function create-idindex-trigger {
  echo '--- Starting create-idindex-trigger ---'
  #sed "s/%SCHEMA%/$IDINDEX_SCHEMA/g" create_idindex_trigger.sql | sed "s/%OWNER%/$IDINDEX_OWNER/g" | psql -d "$IDINDEX_DATABASE" -U "$USER" -a
  echo '--- Finished create-idindex-trigger ---'
}

function ensure-idindex-schema-and-tables {
  echo '--- Starting ensure-idindex-schema-and-tables ---'
  echo CREATING INHERITANCE TABLES

  INDEX_KEY=$IDINDEX_SCHEMA.index_key
  INDEX_VALUE=$IDINDEX_SCHEMA.index_value

  # subpartitioning by hash of key_a is optional - it enables very efficient, parallel index creation on I3 instances, but it may have no benefit on Aurora
  psql -d "${IDINDEX_DATABASE}" -U "${USER}" -e -c "CREATE SCHEMA IF NOT EXISTS ""${IDINDEX_SCHEMA}""; ALTER SCHEMA ${IDINDEX_SCHEMA} OWNER TO ${IDINDEX_OWNER};"
  psql -d "${IDINDEX_DATABASE}" -U "${USER}" -e -c "CREATE TABLE IF NOT EXISTS ""${INDEX_KEY}"" (entityid uuid NOT NULL, value_id integer NOT NULL); ALTER TABLE ${INDEX_KEY} OWNER TO ${IDINDEX_OWNER};"
  psql -d "${IDINDEX_DATABASE}" -U "${USER}" -e -c "CREATE TABLE IF NOT EXISTS ""${INDEX_VALUE}"" (value_id integer NOT NULL GENERATED BY DEFAULT AS IDENTITY ( INCREMENT 1 START 1 MINVALUE 1 MAXVALUE 2147483647 CACHE 1 ), version bigint NOT NULL, branch uuid NOT NULL, dbid character varying(4) COLLATE pg_catalog.""default"", CONSTRAINT index_value_pkey PRIMARY KEY (value_id), CONSTRAINT index_value_version_branch_dbid_key UNIQUE (version, branch, dbid)); ALTER TABLE ${INDEX_VALUE} OWNER TO ${IDINDEX_OWNER};"
  psql -d "${IDINDEX_DATABASE}" -U "${USER}" -e -c "GRANT USAGE ON SCHEMA  ""${IDINDEX_SCHEMA}"" TO cpp_ro; GRANT SELECT ON ALL TABLES IN SCHEMA ""${IDINDEX_SCHEMA}"" TO cpp_ro;"


  for N in {0..15}; do
    SUFFIX=$(printf '%x' "$N")
    psql -d "${IDINDEX_DATABASE}" -U "${USER}" -e -c "CREATE TABLE IF NOT EXISTS ""${INDEX_KEY}""_""${SUFFIX}"" () INHERITS (""${IDINDEX_SCHEMA}"".index_key); ALTER TABLE ${INDEX_KEY}_${SUFFIX} OWNER TO ${IDINDEX_OWNER};"
  done
  echo '--- Finished ensure-idindex-schema-and-tables ---'
}

function create-mds-indexes-after-loading {
  echo '--- Starting create-mds-indexes ---'
  _start=$(date +%s)
  while read -ru 10 query; do
    psql -d "$DATABASE" -U "$USER" -a -v schema="${MDS_SCHEMA}" <<< "$query" &
  done 10<create_mds_indexes.sql
  wait
  _end=$(date +%s)
  echo "--- Finished create-mds-indexes in $((_end - _start)) seconds ---"
}

function create-mds-indexes-for-partitioned-tables {
  echo '--- Starting create-mds-indexes-for-partitioned-tables ---'
  _start=$(date +%s)
  for partition_suffix in 0 1 2 3 4 5 6 7 8 9 a b c d e f; do
    (
      psql -d "$DATABASE" -U "$USER" -a -e -c "ALTER TABLE ONLY ${MDS_SCHEMA}.feature_p${partition_suffix} ADD CONSTRAINT feature_p${partition_suffix}_pkey PRIMARY KEY (id);"
      psql -d "$DATABASE" -U "$USER" -a -e -c "ALTER TABLE ONLY ${MDS_SCHEMA}.association_p${partition_suffix} ADD CONSTRAINT association_p${partition_suffix}_pkey PRIMARY KEY (id);"
      psql -d "$DATABASE" -U "$USER" -a -e -c "CREATE INDEX feature_p${partition_suffix}_geometry_idx ON ${MDS_SCHEMA}.feature_p${partition_suffix} USING gist (geometry_index);"
    ) &
  done;
  wait
  _end=$(date +%s)
  echo "--- Finished create-mds-indexes-for-partitioned-tables in $((_end-_start)) seconds ---"
}

function create-idindex-indexes-after-loading {
  echo '--- Starting create-idindex-indexes ---'

  for N in {0..15}; do
    SUFFIX=$(printf '%x' "$N")
    psql -d "${IDINDEX_DATABASE}" -U "${USER}" -e -c "CREATE INDEX entity_index_${SUFFIX} ON ${IDINDEX_SCHEMA}.index_key_${SUFFIX} USING btree (entityid);"
#    psql -d "${IDINDEX_DATABASE}" -U "${USER}" -e -c "CREATE INDEX index_key_${SUFFIX}_value_id_brin ON ${IDINDEX_SCHEMA}.index_key_${SUFFIX} USING brin (value_id) WITH (pages_per_range='128');"
  done

  psql -d "${IDINDEX_DATABASE}" -U "${USER}" -e -c "CREATE UNIQUE INDEX pk_index_value ON ${IDINDEX_SCHEMA}.index_value USING btree (value_id);"

  echo '--- Finished create-idindex-indexes ---'
}

function drop-idindex-indexes-before-loading {
  echo '--- Starting drop-idindex-indexes ---'

  for N in {0..15}; do
    SUFFIX=$(printf '%x' "$N")
    psql -d "${IDINDEX_DATABASE}" -U "${USER}" -e -c "DROP INDEX IF EXISTS ${IDINDEX_SCHEMA}.index_pkey_${SUFFIX};"
    psql -d "${IDINDEX_DATABASE}" -U "${USER}" -e -c "DROP INDEX IF EXISTS ${IDINDEX_SCHEMA}.entity_index_${SUFFIX};"
    #psql -d "${IDINDEX_DATABASE}" -U "${USER}" -e -c "DROP INDEX IF EXISTS ${IDINDEX_SCHEMA}.index_key_${SUFFIX};"
  done

  #psql -d "${IDINDEX_DATABASE}" -U "${USER}" -e -c "DROP INDEX IF EXISTS ${IDINDEX_SCHEMA}.index_value_version_branch_dbid_key;"
  psql -d "${IDINDEX_DATABASE}" -U "${USER}" -e -c "DROP INDEX IF EXISTS ${IDINDEX_SCHEMA}.pk_index_value;"

  echo '--- Finished drop-idindex-indexes ---'
}

function load-file {
  _FILE=$1
  _USER=$2
  _DATABASE=$3
  _SCHEMA=$4
  _TABLE=$5

  if [ -f "${_FILE}" ]; then
    echo "Loading file: ${_FILE}"
    #zcat "${_FILE}" | psql -U "${_USER}" -d "${_DATABASE}" -c "\COPY ""${_SCHEMA}"".""${_TABLE}"" FROM STDIN DELIMITER '|' CSV HEADER" >/dev/null && echo "[$(date +'%Y-%m-%d %H:%M:%S.%3N')][${_TABLE}] ${_FILE} OK!" >> "./output_$TABLE"
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
    FILE=${SMDS_SOURCES}${TABLE}/${TABLE}".csv.gz"

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

  matched_files="$(find "${SMDS_SOURCES}" -maxdepth 3 -regex "^.*/${TABLE}\_[0-9]+\.csv\.gz")"
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

function load-idindex {
  echo '--- Starting load-idindex ---'
  _start=$(date +%s)
  load-file "${IDINDEX_SOURCES}id_index_value/index_value.csv.gz" "${IDINDEX_USER}" "${IDINDEX_DATABASE}" "${IDINDEX_SCHEMA}" "id_index_value"

  for partition_suffix1 in 0 1 2 3 4 5 6 7 8 9 a b c d e f; do
    for partition_suffix2 in 0 1 2 3 4 5 6 7 8 9 a b c d e f; do
      ( load-id-index-partition "$partition_suffix1$partition_suffix2" ) &
    done;
  done;
  wait

  _end=$(date +%s)
  echo "--- Finished load-idindex in $((_end - _start)) seconds ---"
}

function load-id-index-partition {
  PARTITION=$1
  _start=$(date +%s)

  if [ -d "${IDINDEX_SOURCES}id_index_key/id_index_key_$PARTITION" ]; then
      matched_files="$(find "${IDINDEX_SOURCES}id_index_key/id_index_key_$PARTITION"/ -maxdepth 2 -regex "^.*/index_key_[0-9]+\.csv\.gz$")"
      if [ -z "$matched_files" ]; then
        echo "For id_index partition '$PARTITION' matched no files"
      else
        matched_files_array=( $matched_files )
        _to_do="${#matched_files_array[@]}"
        echo "For id_index partition '$PARTITION' matched ${_to_do} files"

        _in_progress=0
        _done=0
        for FILENAME in $matched_files; do
          load-file "${FILENAME}" "${IDINDEX_USER}" "${IDINDEX_DATABASE}" "${IDINDEX_SCHEMA}" "index_key_${PARTITION}" &
          _in_progress=$((_in_progress + 1))
          _done=$((_done + 1))

          # wait sending after $FAKE_PARALLELISM tasks, otherwise we will fill up maximum connections in postgres
          # divide by 16 - number of partitions loaded in parallel
          if [ "$_in_progress" -ge "$(( FAKE_PARALLELISM / 16 ))" ]; then
            echo "[id_index_'$PARTITION'][progress] ${_done}/${_to_do}..."
            wait
            _in_progress=0
          fi
        done
        wait
      fi

      _end=$(date +%s)
        echo "--- Finished id_index partition '$PARTITION' in $((_end - _start)) seconds ---"
  fi
}

function create-mds-constraints {
  echo '--- Starting create-mds-constraints ---'
  _start=$(date +%s)
  while read -ru 10 query; do
    psql -d "$DATABASE" -U "$USER" -a -v schema="${MDS_SCHEMA}" <<< "$query" &
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
  echo -n 'Setting SMDS parameters for optimal performance... '
  prefix_command=""
  if [ "$(id -un)" != "postgres" ]; then
    if sudo -u postgres -v 2> /dev/null ; then
      prefix_command="sudo -inu postgres"
    else
      echo "FAILED... needs to be done with postgres user, but couldn't execute the command"
      return 1
    fi
  fi
  # script passed through redirect - sudo -inu does not keep current dir
  $prefix_command psql -U "postgres" -a < "tweak_db_params.sql" > /dev/null  && echo 'OK'
  data_dir="$($prefix_command psql -Atc 'SHOW data_directory;')"

  $prefix_command  pg_ctl -t 3600 -D "$data_dir" restart
  trap 'restore-smds-params' EXIT
}


function create-idindex-constraints {
  echo '--- Starting create-idindex-constraints ---'
  for N in {0..15}; do
    PARTITION=$(printf '%x' "$N")
    create-single-idindex-constraints "$PARTITION" &
  done
}

function create-single-idindex-constraints {
  PARTITION=$1
  TABLE_NAME="index_key_${PARTITION}"

  echo "Creating constraints for ${TABLE_NAME}"
  sed "s/%PARTITION%/$PARTITION/g" create_idindex_constraints.sql | psql -d "$IDINDEX_DATABASE" -U "$USER" -a -v schema="${IDINDEX_SCHEMA}" -v table="${TABLE_NAME}" -v partition="${PARTITION}"
}

function drop-idindex-constraints {
  echo '--- Starting drop-id-index-constraints ---'
  for N in {0..15}; do
    PARTITION=$(printf '%x' "$N")
    drop-single-idindex-constraints "$PARTITION" &
  done
}

function drop-single-idindex-constraints {
  PARTITION=$1
  TABLE_NAME="index_key_${PARTITION}"

  echo "Dropping constraints for ${TABLE_NAME}"
  sed "s/%PARTITION%/$PARTITION/g" drop_idindex_constraints.sql | psql -d "$IDINDEX_DATABASE" -U "$USER" -a -v schema="${IDINDEX_SCHEMA}" -v table="${TABLE_NAME}" -v partition="${PARTITION}"
}

echo "-- CSV files will be copied to ${tempdir} --"
[[ ! $SKIP_SMDS ]] && {
  if [[ -d "${SMDS_SOURCES}" ]] ; then
    echo "Directory '$SMDS_SOURCES' already exist, please remove it before going further"
    exit 1
  fi

  for TABLE in association feature dictionary model_versions; do
      if ! aws s3 ls "$SMDS_S3_SOURCE"$TABLE/ | grep -P "($TABLE)_*" > /dev/null ; then
          echo "S3 object ${SMDS_S3_SOURCE}$TABLE/ does not contain required *.csv.gz files for populating SMDS."
          exit 2
      fi
  done

  mkdir -p "$SMDS_SOURCES"
  aws s3 cp "$SMDS_S3_SOURCE" "$SMDS_SOURCES" --recursive --exclude "*.temp-beam*"
}

[[ ! $SKIP_IDINDEX ]] && {
  if [[ -d "${IDINDEX_SOURCES}" ]] ; then
    echo "Directory '${IDINDEX_SOURCES}' already exist, please remove it before going further"
    exit 1
  fi

  if ! aws s3 ls "${IDINDEX_S3_SOURCE}" | grep -P "(id_index_key|id_index_value)" > /dev/null ; then
    echo "S3 object ${IDINDEX_S3_SOURCE} does not contain required *.csv.gz files for populating idindex."
    exit 2
  fi

  mkdir -p "$IDINDEX_SOURCES"
  aws s3 cp "$IDINDEX_S3_SOURCE" "$IDINDEX_SOURCES" --recursive --exclude "*.temp-beam*"
}

echo '--- Finished file copy process---'

#[[ ! $SKIP_SMDS ]] && tweak-smds-params
#[[ ! $SKIP_SMDS ]] && ensure-mds-schema-and-tables |& logging "ensure-mds-schema-and-tables"
#[[ ! $SKIP_IDINDEX ]] && ensure-idindex-schema-and-tables |& logging "ensure-idindex-schema-and-tables"
#[[ ! $SKIP_IDINDEX ]] && drop-idindex-constraints |& logging "drop-idindex-constraints"
#[[ ! $SKIP_IDINDEX ]] && drop-idindex-indexes-before-loading |& logging "drop-idindex-indexes"
wait
[[ ! $SKIP_IDINDEX ]] && create-idindex-trigger |& logging "create-idindex-trigger"
[[ ! $SKIP_SMDS ]] && load-smds |& logging "load-smds"
[[ ! $SKIP_IDINDEX ]] && load-idindex |& logging "load-idindex"
# wait for completion of all subprocesses (parallel load scripts) spawned by this script
wait
#[[ ! $SKIP_SMDS ]] && create-mds-constraints |& logging "create-mds-constraints"
#[[ ! $SKIP_SMDS ]] && create-mds-indexes-for-partitioned-tables |& logging "create-mds-indexes-for-partitioned-tables"
#[[ ! $SKIP_IDINDEX ]] && create-idindex-constraints |& logging "create-idindex-constraints"
#[[ ! $SKIP_SMDS ]] && create-mds-indexes-after-loading |& logging "create-mds-indexes"
#[[ ! $SKIP_IDINDEX ]] && create-idindex-indexes-after-loading |& logging "create-idindex-indexes"
wait
# TODO analyze?

# cleanup
[[ ! $SKIP_SMDS ]] && rm -r "$SMDS_SOURCES"
[[ ! $SKIP_IDINDEX ]] && rm -r "$IDINDEX_SOURCES"

date '+%d/%m/%Y %H:%M:%S' > end_time

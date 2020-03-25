#!/usr/bin/env sh

# enable debugging
#set -x

DB_SERVER="localhost"
PROD_DATABASE="prod"
TEST_DATABASE="test"
BACKUP_DIR="/mnt/backups"
DB_SUFFIX=".fdb"
BACKUP_SUFFIX=".fbk"
BACKUP_KEEP_COUNT="20"
SYSDBA_PASSWORD_FILE="/etc/firebird/3.0/SYSDBA.password"
ISC_PASSWORD_FILE="$(dirname $0)/ISC_PASSWORD_FILE"

####################################################

# Read db user password
if [ -r "${ISC_PASSWORD_FILE}" ]
then
    # Use custom user
    # shellcheck disable=SC1090
    . "${ISC_PASSWORD_FILE}"
else
    # Use db admin user
    # shellcheck disable=SC1090
    . ${SYSDBA_PASSWORD_FILE}
fi

####################################################

# get current year, month and timestamp
DIR_YEAR=$(date +%Y)
DIR_MONTH=$(date +%m)
FILE_TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)

# Start
echo "Starting Backup of Database ${DB_SERVER}:${PROD_DATABASE}${DB_SUFFIX} at ${FILE_TIMESTAMP}"

# create directory if it does not exist
mkdir -p "${BACKUP_DIR}/${DIR_YEAR}/${DIR_MONTH}"

# Backup DB from DB-Server
if gbak -t \
    -user "${ISC_USER}" \
    -password "${ISC_PASSWORD}" \
    "${DB_SERVER}:${PROD_DATABASE}${DB_SUFFIX}" \
    "${BACKUP_DIR}/${DIR_YEAR}/${DIR_MONTH}/${FILE_TIMESTAMP}_${PROD_DATABASE}${BACKUP_SUFFIX}"
then
    echo "Successful backed up Database ${DB_SERVER}:${PROD_DATABASE}${DB_SUFFIX}"
else
    echo "Error while backing up Database ${DB_SERVER}:${PROD_DATABASE}${DB_SUFFIX}"
    exit 1
fi

### RESTORE EXAMPLE ###
#gbak -user $ISC_USER -password $ISC_PASSWORD -replace /firebird/data/2019-09-26_05-00-02_Produktion.FBK localhost:prod.fdb
if [ "$1" = "restore-test-db" ] ; then
    # Restore Backup of DB from DB-Server to Test DB
    if gbak \
        -user "${ISC_USER}" \
        -password "${ISC_PASSWORD}" \
        -replace \
        "${BACKUP_DIR}/${DIR_YEAR}/${DIR_MONTH}/${FILE_TIMESTAMP}_${PROD_DATABASE}${BACKUP_SUFFIX}" \
        "${DB_SERVER}:${TEST_DATABASE}${DB_SUFFIX}"
    then
        echo "Successful restored Database ${DB_SERVER}:${PROD_DATABASE}${DB_SUFFIX} to ${DB_SERVER}:${TEST_DATABASE}${DB_SUFFIX}"
    else
        echo "Error while restoring Database ${DB_SERVER}:${PROD_DATABASE}${DB_SUFFIX} to ${DB_SERVER}:${TEST_DATABASE}${DB_SUFFIX}"
        exit 1
    fi
fi

# Remove old backups
for fbk in $(find ${BACKUP_DIR} -type f -iname "*.fbk" | sort | head -n -${BACKUP_KEEP_COUNT})
do
    echo "Removing: ${fbk}"
    rm "${fbk}"
done

echo "Finished Backup of Database ${DB_SERVER}:${PROD_DATABASE}${DB_SUFFIX} at $(date +%Y-%m-%d_%H-%M-%S)"
exit 0

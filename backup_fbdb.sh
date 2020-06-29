#!/usr/bin/env sh

# enable debugging
#set -x

PROD_DATABASE_FILE="/var/lib/firebird/3.0/data/prod.fdb"
TEST_DATABASE_FILE="/var/lib/firebird/3.0/data/test.fdb"
BACKUP_DIR="/mnt/backups"
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

get_backup_filename() {
    local DB=$1
    # remove path
    DB=${DB##*/}
    # remove extension
    DB=${DB%.*}
    # create backup file dst path
    echo "${BACKUP_DIR}/$(date +%Y)/$(date +%m)/$(date +%Y-%m-%d_%H-%M-%S)_${DB}.fbk"
}

PROD_DATABASE_BACKUP_FILE=$(get_backup_filename ${PROD_DATABASE_FILE})

# Start
echo "$(date): Starting Backup of Database ${PROD_DATABASE_FILE}"

# create directory if it does not exist
mkdir -p "${PROD_DATABASE_BACKUP_FILE%/*}"

# Backup DB from DB-Server
if gbak \
    -user "${ISC_USER}" \
    -password "${ISC_PASSWORD}" \
    -backup_database \
    -transportable \
    "${PROD_DATABASE_FILE}" \
    "${PROD_DATABASE_BACKUP_FILE}"
then
    echo "$(date): Successful backed up Database ${PROD_DATABASE_FILE}"
else
    echo "$(date): Error while backing up Database ${PROD_DATABASE_FILE}"
    exit 1
fi

### RESTORE EXAMPLE ###
#gbak -user $ISC_USER -password $ISC_PASSWORD -replace /firebird/data/2019-09-26_05-00-02_Produktion.FBK localhost:prod.fdb
if [ "$1" = "restore-test-db" ] ; then
    # Restore Backup of DB from DB-Server to Test DB
    if gbak \
        -user "${ISC_USER}" \
        -password "${ISC_PASSWORD}" \
        -recreate_database overwrite \
        "${PROD_DATABASE_BACKUP_FILE}" \
        "${TEST_DATABASE_FILE}"
    then
        chown firebird:firebird ${TEST_DATABASE_FILE}
        echo "$(date): Successful restored Database ${PROD_DATABASE_BACKUP_FILE} to ${TEST_DATABASE_FILE}"
    else
        echo "$(date): Error while restoring Database ${PROD_DATABASE_BACKUP_FILE} to ${TEST_DATABASE_FILE}"
        exit 1
    fi
fi

# Remove old backups
for fbk in $(find ${BACKUP_DIR} -type f -iname "*.fbk" | sort | head -n -${BACKUP_KEEP_COUNT})
do
    echo "$(date): Removing: ${fbk}"
    rm "${fbk}"
done

echo "$(date): Finished Backup of Database ${PROD_DATABASE_FILE}"
exit 0

#!/bin/bash

# SPDX-FileCopyrightText: 2021 Belcan Advanced Solution
#
# SPDX-License-Identifier: MIT

set -e

if [ -z "${PROPERTIES_FILE}" ]; then
	echo "PROPERTIES_FILE not set"
	exit 1
fi
. ${PROPERTIES_FILE}

if [ -z "${RESTORE_DIR}" ]; then
	echo "RESTORE_DIR not set"
	exit 1
fi

echo "Ensure a BART restore has been run for the desired snapshot, restored to ${RESTORE_DIR}"
echo "Ensure the postgres, ldap containers (if used) ARE running"
echo "Ensure the alfresco container is NOT running"
read -p "Press enter to confirm"

if [ ${BACKUP_LDAP_ENABLED} == 'true' ]; then
	echo "Going to restore ldap backup from ${RESTORE_DIR} into ${LDAP_ADDRESS}"
	read -p "Press enter to confirm"

	set -x
	ldapadd -x -H $LDAP_ADDRESS -w $LDAP_ROOTPASSWORD -D $LDAP_ROOTUSER -f ${RESTORE_DIR}/ldap/ldap.ldif
	set +x
fi

if [ ${BACKUP_DB_ENABLED} == 'true' ]; then

	echo "Restoring db backup from ${RESTORE_DIR} into ${DATABASE_HOST}"
	echo "Going to drop and recreate 'alfresco' database. This may not exist."
	read -p "Press enter to confirm"

	export PGPASSWORD=${DBPASS}
	set -x
	/usr/bin/psql -h $DATABASE_HOST -U $DATABASE_USER -d postgres -c "DROP DATABASE alfresco"
	/usr/bin/psql -h $DATABASE_HOST -U $DATABASE_USER -d postgres -c "CREATE DATABASE alfresco WITH OWNER alfresco ENCODING 'utf8';"
	/usr/bin/psql -h $DATABASE_HOST -U $DATABASE_USER -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE alfresco TO alfresco;"
	set +x

	echo "Restoring database backup file"

	set -x
	/usr/bin/pg_restore -h $DATABASE_HOST -U $DATABASE_USER -d alfresco ${RESTORE_DIR}/db/alfresco.sql.Fc
	set +x
fi

if [ ${BACKUP_CONTENTSTORE_ENABLED} == 'true' ]; then
	echo "Restoring alfresco content"
	echo "Going to remove and replace contentstore"
	read -p "Press enter to confirm"

	set -x
	rm -rf $ALF_CONTENTSTORE || true
	rsync --info=progress2 -a ${RESTORE_DIR}/cs/contentstore/ ALF_CONTENTSTORE
	set +x
fi

echo "Complete. You should now start the rest of the containers via 'make up-d'."
echo "****************************************************************************"
echo "* NOTE. The share + nginx containers may need to be restarted              *"
echo "* after their initial creation.                                            *"
echo "****************************************************************************"

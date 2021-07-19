#! /usr/bin/env bash

# SPDX-FileCopyrightText: 2021 Belcan Advanced Solution
#
# SPDX-License-Identifier: MIT

set -e

if [ -f ${ALFBRT_PATH}/alfresco-bart.properties ]; then
	. ${ALFBRT_PATH}/alfresco-bart.properties 
else
	echo alfresco-bart.properties file not found, edit $0 and modify ALFBRT_PATH
fi

echo "Ensure a BART restore has been run for the desired snapshot, restored to ${RESTOREDIR}"
echo "Ensure the postgres, ldap containers (if used) ARE running"
echo "Ensure the alfresco container is NOT running"
read -p "Press enter to confirm"

if [ ${BACKUP_LDAP_ENABLED} == 'true' ]; then
	echo "Going to restore ldap backup from ${RESTOREDIR} into ${LDAP_ADDRESS}"
	read -p "Press enter to confirm"

	set -x
	ldapadd -x -H $LDAP_ADDRESS -w $LDAP_ROOTPASSWORD -D $LDAP_ROOTUSER -f ${RESTOREDIR}/ldap/ldap.ldif 
	set +x
fi

if [ ${BACKUP_DB_ENABLED} == 'true' ]; then

	echo "Restoring db backup from ${RESTOREDIR} into ${DBHOST}"
	echo "Going to drop and recreate 'alfresco' database. This may not exist."
	read -p "Press enter to confirm"

	export PGPASSWORD=${DBPASS}
	set -x
	/usr/bin/psql -h $DBHOST -U $DBUSER -d postgres -c "DROP DATABASE alfresco"
	/usr/bin/psql -h $DBHOST -U $DBUSER -d postgres -c "CREATE DATABASE alfresco WITH OWNER alfresco ENCODING 'utf8';"
	/usr/bin/psql -h $DBHOST -U $DBUSER -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE alfresco TO alfresco;"
	set +x 

	echo "Restoring database backup file"

	set -x
	/usr/bin/pg_restore -h $DBHOST -U $DBUSER -d alfresco ${RESTOREDIR}/db/alfresco.sql.Fc
	set +x
fi

if [ ${BACKUP_CONTENTSTORE_ENABLED} == 'true' ]; then
	echo "Restoring alfresco content"
	echo "Going to remove and replace contentstore"
	read -p "Press enter to confirm"

	set -x
	rm -rf ${ALF_DIRROOT}/contentstore || true
	rsync --info=progress2 -a ${RESTOREDIR}/cs/contentstore/ ${ALF_DIRROOT}/contentstore
	set +x

	echo "Removing and replacing contentstore.deleted. This may not exist"

	set -x
	rm -rf /usr/local/alfresco/alf_data/contentstore.deleted || true
	rsync --info=progress2 -a ${RESTOREDIR}/cs/contentstore.deleted/ ${ALF_DIRROOT}/contentstore.deleted || true
	set +x
fi

echo "Complete. You should now start the rest of the containers via 'make up-d'."
echo "****************************************************************************" 
echo "* NOTE. The share + nginx containers may need to be restarted              *"
echo "* after their initial creation.                                            *"
echo "****************************************************************************"
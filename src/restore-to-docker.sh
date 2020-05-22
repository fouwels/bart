#! /usr/bin/env bash
set -e

if [ -f ${ALFBRT_PATH}/alfresco-bart.properties ]; then
	. ${ALFBRT_PATH}/alfresco-bart.properties 
else
	echo alfresco-bart.properties file not found, edit $0 and modify ALFBRT_PATH
fi

echo "Ensure a BART restore has been run for the desired snapshot, restored from ${RESTOREDIR}"
echo "Ensure alfresco, share, and solr6 containers are NOT running"
echo "Ensure the postgres, ldap containers ARE running"
echo "The correct containers can be started by executing 'make down && make up-noalfresco-d' in the blueprint directory"
read -p "Press enter to confirm"

echo "Restoring ldap backup from ${RESTOREDIR} into ${LDAP_ADDRESS}"

#ldapsearch -LLL -s one -b $LDAP_ROOTDN "(cn=*)" dn | awk -F": " '$1~/^\s*dn/{print $2}' > listOfDNtoRemove.txt && ldapdelete -r -f listOfDNtoRemove.txt
set -x
ldapadd -x -H $LDAP_ADDRESS -w $LDAP_ROOTPASSWORD -D $LDAP_ROOTUSER -f ${RESTOREDIR}/ldap/ldap.ldif 
set +x

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

echo "Complete. You should now start the rest of the containers via 'make up-d'."
echo "****************************************************************************" 
echo "* NOTE. The share + nginx containers may need to be restarted              *"
echo "* after their initial creation.                                            *"
echo "****************************************************************************"
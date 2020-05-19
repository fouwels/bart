#! /usr/bin/env bash

read -p "Enter directory to restore FROM. This should containe the /ldap, /cs, /db directories " RESTORE_DIR
echo ""

echo "Restoring backup from ${RESTORE_DIR} into /opt/alfresco/alf_data, looking for postgres container named 'postgres'"
echo "Ensure a BART restore has been run for the desired snapshot, restored into ${RESTORE_DIR}"
echo "Ensure alfresco, share, and solr6 containers are NOT running"
echo "Ensure the postgres container IS running."
read -p "Press enter to confirm"

echo ""
echo "Going to drop and recreate 'alfresco' database. This may not exist."
read -p "Press enter to confirm"

export PGPASSWORD="alfresco"
/usr/bin/psql -h postgres -U alfresco -d postgres -c "DROP DATABASE alfresco"
/usr/bin/psql -h postgres -U alfresco -d postgres -c "CREATE DATABASE alfresco WITH OWNER alfresco ENCODING 'utf8';"
/usr/bin/psql -h postgres -U alfresco -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE alfresco TO alfresco;"

echo "Going to restore backup to 'alfresco' database."
read -p "Press enter to confirm"

/usr/bin/pg_restore -h postgres -U alfresco -d alfresco ${RESTORE_DIR}/db/alfresco.sql.Fc

echo ""
echo "Going to remove and replace contentstore"
read -p "Press enter to confirm"

rm -rf /usr/local/alfresco/alf_data/contentstore || true
rsync --info=progress2 -a ${RESTORE_DIR}/cs/contentstore/ /usr/local/alfresco/alf_data/contentstore

echo "Going to remove and replace contentstore.deleted. This may not exist"

rm -rf /usr/local/alfresco/alf_data/contentstore.deleted || true
rsync --info=progress2 -a ${RESTORE_DIR}/cs/contentstore.deleted/ /usr/local/alfresco/alf_data/contentstore.deleted || true

echo "Complete. You should now remove the old alfresco, share, and solr6 containers, and recreate them via make up."
echo "LDAP will need to be restored manually, from the ${RESTORE_DIR}/ldap directory"
echo "****************************************************************************" 
echo "* NOTE. The share container will need to be stopped, and then restarted,   *"
echo "* after it's initial creation. It does not appear to like being started    *"
echo "* while the alfresco container is rebuilding. Doing so causes it to        *"
echo "* accept log in, but render a blank page subsequently -kf                  *"
echo "****************************************************************************"
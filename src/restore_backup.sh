echo "Restoring backup from /tmp into /opt/alfresco/alf_data"
echo "Ensure a BART restore has been run for the desired snapshot, restored into /tmp"
echo "Ensure alfresco, share, solr6, and postgres containers have been created, but are not currently running"
read -p "Press enter to confirm"

echo ""
echo "Going to drop and restore 'alfresco' database. This may not exist."
read -p "Press enter to confirm"
export PGPASSWORD="alfresco"
/usr/bin/psql -h postgres -U alfresco -d postgres -c "drop database alfresco"
/usr/bin/psql -h postgres -U alfresco -d postgres -c "create database alfresco"
read -p "Press enter to continue"
/usr/bin/pg_restore -h postgres -U alfresco -d alfresco /tmp/db/alfresco.sql.Fc

echo ""
echo "Going to remove and replace contentstore"
read -p "Press enter to confirm"
rm -rf /opt/alfresco/alf_data/contentstore || true
cp -a /tmp/cs/contentstore /opt/alfresco/alf_data/contentstore

echo "Going to remove and replace contentstore.deleted. This may not exist"
read -p "Press enter to confirm"
rm -rf /opt/alfresco/alf_data/contentstore.deleted || true
cp -a /tmp/cs/contentstore.deleted /opt/alfresco/alf_data/contentstore.deleted || true

echo "Complete. You should now re-start the containers"
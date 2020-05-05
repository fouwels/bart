#! /usr/bin/env bash

echo "Restoring backup from /tmp into /opt/alfresco/alf_data, looking for postgres container named 'postgres'"
echo "Ensure a BART restore has been run for the desired snapshot, restored into /tmp"
echo "Ensure alfresco, share, and solr6 containers are NOT running"
echo "Ensure the postgres container IS running."
read -p "Press enter to confirm"

echo ""
echo "Going to drop and recreate 'alfresco' database. This may not exist."
echo '/usr/bin/psql -h postgres -U alfresco -d postgres -c "DROP DATABASE alfresco"'
echo '/usr/bin/psql -h postgres -U alfresco -d postgres -c "CREATE DATABASE alfresco WITH OWNER alfresco ENCODING "utf8";'
echo '/usr/bin/psql -h postgres -U alfresco -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE alfresco TO alfresco;"'
read -p "Press enter to confirm"

export PGPASSWORD="alfresco"
/usr/bin/psql -h postgres -U alfresco -d postgres -c "DROP DATABASE alfresco"
/usr/bin/psql -h postgres -U alfresco -d postgres -c "CREATE DATABASE alfresco WITH OWNER alfresco ENCODING 'utf8';"
/usr/bin/psql -h postgres -U alfresco -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE alfresco TO alfresco;"

echo "Going to restore backup to 'alfresco' database."
echo '/usr/bin/pg_restore -h postgres -U alfresco -d alfresco /tmp/db/alfresco.sql.Fc'
read -p "Press enter to confirm"

/usr/bin/pg_restore -h postgres -U alfresco -d alfresco /tmp/db/alfresco.sql.Fc

echo ""
echo "Going to remove and replace contentstore"
echo 'rm -rf /opt/alfresco/alf_data/contentstore || true'
echo 'cp -a /tmp/cs/contentstore /opt/alfresco/alf_data/contentstore'
read -p "Press enter to confirm"

rm -rf /opt/alfresco/alf_data/contentstore || true
rsync --info=progress2 -a /tmp/cs/contentstore /opt/alfresco/alf_data/contentstore

echo "Going to remove and replace contentstore.deleted. This may not exist"
echo 'rm -rf /opt/alfresco/alf_data/contentstore.deleted || true'
echo 'cp -a /tmp/cs/contentstore.deleted /opt/alfresco/alf_data/contentstore.deleted || true'

rm -rf /opt/alfresco/alf_data/contentstore.deleted || true
rsync --info=progress2 -a /tmp/cs/contentstore.deleted /opt/alfresco/alf_data/contentstore.deleted || true

echo "Complete. You should now remove the old alfresco, share, and solr6 containers, and recreate them via make up."
echo "****************************************************************************" 
echo "* NOTE. The share container will need to be stopped, and then restarted,   *"
echo "* after it's initial creation. It does not appear to like being started    *"
echo "* while the alfresco container is rebuilding. Doing so causes it to        *"
echo "* accept log in, but render a blank page subsequently -kf                  *"
echo "****************************************************************************"
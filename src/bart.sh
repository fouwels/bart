#!/bin/bash
set -e

# Copyright (c) 2013 Toni de la Fuente.
# SPDX-FileCopyrightText: Copyright (c) 2013 Toni de la Fuente.
# SPDX-FileCopyrightText: 2021 Belcan Advanced Solution
#
# SPDX-License-Identifier: Apache-2.0

. bart-functions.sh

ALFBRT_LOG_FILE=/dev/stdout

if [ -z "${PROPERTIES_FILE}" ]; then
	echo "PROPERTIES not set"
	exit 1
fi
. ${PROPERTIES_FILE}

if [ -z "${DUPLICITY_FLAGS}" ]; then
	echo "DUPLICITY_FLAGS not set"
	exit 1
fi

if [ -z "${TARGET_TYPE}" ]; then
	echo "TARGET_TYPE not set"
	exit 1
fi

if [ -z "${TARGET}" ]; then
	echo "TARGET not set"
	exit 1
fi

if [ -z "${RESTORE_DIR}" ]; then
	echo "RESTORE_DIR not set"
	exit 1
fi

# Checks backup type, target selected
case $TARGET_TYPE in
"azure")

	if [ -z "${AZURE_CONNECTION_STRING}" ]; then
		echo "AZURE_CONNECTION_STRING not set"
		exit 1
	fi

	export AZURE_CONNECTION_STRING
	;;
"s3")

	if [ -z "${AWS_ACCESS_KEY_ID}" ]; then
		echo "AWS_ACCESS_KEY_ID not set"
		exit 1
	fi
	if [ -z "${AWS_SECRET_ACCESS_KEY}" ]; then
		echo "AWS_SECRET_ACCESS_KEY not set"
		exit 1
	fi

	export AWS_ACCESS_KEY_ID
	export AWS_SECRET_ACCESS_KEY
	;;
"local")
	echo "Local backup selected"
	;;

*) echo "error: uknown TARGET type <$TARGET_TYPE>, review your alfresco-backup.properties" ;;
esac

case $1 in
"backup")

	if [ ${BACKUP_LDAP_ENABLED} == 'true' ]; then
		backup_ldap
	fi
	if [ ${BACKUP_DB_ENABLED} == 'true' ]; then
		backup_db
	fi
	if [ ${BACKUP_CONTENTSTORE_ENABLED} == 'true' ]; then
		backup_contentstore
	fi

	;;

"restore")

	echo 'Specify a backup DATE (YYYY-MM-DD) to restore at or a number of DAYS+D since your valid backup. For example, "2013-07-26" or "5D" without quotes.'
	echo -n "Please type a date or number of days (use 'now' for last backup): "
	builtin read RESTORE_TIME

	echo "Restoring from $RESTORE_TIME"
	echo -n "Enter to confirm and begin restore"

	if [ ${BACKUP_LDAP_ENABLED} == 'true' ]; then
		restore_ldap
	fi
	if [ ${BACKUP_DB_ENABLED} == 'true' ]; then
		restore_db
	fi
	if [ ${BACKUP_CONTENTSTORE_ENABLED} == 'true' ]; then
		restore_contentstore
	fi

	echo "Restore complete - Now you have to copy and replace your existing content with the content left in $RESTOREDIR, if you need a guideline about how to recovery your Alfresco installation from a backup please read the Alfresco Backup and Desaster Recovery White Paper file."
	exit 0
	;;

"collection")
	if [ ${BACKUP_LDAP_ENABLED} == 'true' ]; then
		collection_ldap
	fi
	if [ ${BACKUP_DB_ENABLED} == 'true' ]; then
		collection_db
	fi
	if [ ${BACKUP_CONTENTSTORE_ENABLED} == 'true' ]; then
		collection_contentstore
	fi
	exit 0
	;;

"maintenance")
	maintenance
	exit 0
	;;

"cleanup")
	cleanup
	exit 0
	;;

*) usage ;;
esac

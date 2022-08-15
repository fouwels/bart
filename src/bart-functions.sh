#!/bin/bash
set -e

# Copyright (c) 2013 Toni de la Fuente.
# SPDX-FileCopyrightText: Copyright (c) 2013 Toni de la Fuente.
# SPDX-FileCopyrightText: 2021 Belcan Advanced Solution
#
# SPDX-License-Identifier: Apache-2.0

function usage {
	echo "USAGE:

    Modes:
        backup [set]		runs an incremental backup or a full if first time
        restore [set] [date] [dest]	runs the restore, wizard if no arguments
        verify [set]		verifies the backup
        collection [set]	shows all the backup sets in the archive
        list [set]			lists the files currently backed up in the archive
        maintenance [set]	manually run maintenance commands on archive
        cleanup				manually run cleanup on all archives
        "
}
# LDAP_ADDRESS
# LDAP_ROOTDN
# LDAP_ROOTPASSWORD
# LDAP_ROOTUSER
function backup_ldap {

	echo "Starting backup to: $TARGET/ldap"

	F_DIR=/tmp/bart/ldap

	if [ ! -d $F_DIR ]; then
		mkdir -p $F_DIR
	fi

	set -v
	ldapsearch -x -H $LDAP_ADDRESS -b $LDAP_ROOTDN -w $LDAP_ROOTPASSWORD -D $LDAP_ROOTUSER -LLL >$F_DIR/ldap.ldif
	set +v
	set -x
	duplicity $DUPLICITY_FLAGS $DUPLICITY_UPLOAD_FLAGS $F_DIR $TARGET/ldap
	set +x

	echo "Starting backup to: $TARGET/ldap: complete"
}

# DATABASE_TYPE
# DATABASE_HOST
# DATABASE_USER
# DATABASE_NAME
# PGPASSFILE
# PGPASSWORD
function backup_db {

	echo "Starting backup to: $TARGET/database"

	F_DIR=/tmp/bart

	if [ ! -d $F_DIR ]; then
		mkdir -p $F_DIR
	fi

	case $DATABASE_TYPE in
	"postgresql")

		export PGPASSFILE
		export PGPASSWORD
		set -x
		pg_dump -Fc -w -h $DATABASE_HOST -U $DATABASE_USER $DATABASE_NAME > $F_DIR/$DATABASE_NAME.sql.Fc
		set +x

		echo "uploading"
		set -x
		duplicity $DUPLICITY_FLAGS $DUPLICITY_UPLOAD_FLAGS $F_DIR $TARGET/database
		set +x
		;;

	*)
		echo "error: unknown DB type \"$DATBASE_TYPE\", review your alfresco-bart.properties"
		exit 1
		;;
	esac

	echo "Starting backup to: $TARGET/database: complete"
}

# CONTENTSTORE_LOCATION
function backup_contentstore {

	echo "Starting backup to: $TARGET/contentstore"

	# Getting a variable to know all includes and excludes
	F_PARENT="$(dirname "$CONTENTSTORE_LOCATION")"
	F_CS="--include $CONTENTSTORE_LOCATION --exclude $F_PARENT"

	set -x
	duplicity $DUPLICITY_FLAGS $DUPLICITY_UPLOAD_FLAGS $F_CS $F_PARENT $TARGET/contentstore
	set +x

	echo "Starting backup to: $TARGET/contentstore: complete"
}

# RESTORE_TIME
# RESTORE_DIR
function restore_db() {

	echo "Starting restore from: $TARGET/database to $RESTOREDIR/db"
	set -x
	duplicity restore $DUPLICITY_FLAGS --restore-time $RESTORE_TIME $TARGET/database $RESTORE_DIR/db
	set +x
	echo "Starting restore from: $TARGET/database to $RESTOREDIR/db: complete"
}

# RESTORE_TIME
# RESTORE_DIR
# TARGET
function restore_contentstore() {

	echo "Starting restore from: $TARGET/contentstore to $RESTOREDIR/cs"
	set -x
	duplicity restore $DUPLICITY_FLAGS --restore-time $RESTORE_TIME $TARGET/contentstore $RESTORE_DIR/cs
	set +x
	echo "Starting restore from: $TARGET/contentstore to $RESTORE_DIR/cs: complete"
}

# RESTORE_TIME
# RESTORE_DIR
# TARGET
function restore_ldap() {

	echo "Starting restore from: $TARGET/ldap to $RESTOREDIR/ldap"
	set -x
	duplicity restore $DUPLICITY_FLAGS --restore-time $RESTORE_TIME $TARGET/ldap $RESTORE_DIR/ldap
	set +x
	echo "Starting restore from: $TARGET/ldap to $RESTORE_DIR/ldap: complete"
}

function collection_ldap() {
	echo "Backup collection: ldap"
	set -x
	duplicity collection-status $DUPLICITY_FLAGS $TARGET/ldap
	set +x

}
function collection_db() {
	echo "Backup collection: db"
	set -x
	duplicity collection-status $DUPLICITY_FLAGS $TARGET/database
	set +x

}
function collection_contentstore() {
	echo "Backup collection: cs"
	set -x
	duplicity collection-status $DUPLICITY_FLAGS $TARGET/contentstore
	set +x
}

# RETENTION_CLEAN_TIME
# RETENTION_MAX_FULL
function maintenance() {

	set -x

	if [ ${BACKUP_LDAP_ENABLED} == 'true' ]; then
		duplicity remove-older-than $DUPLICITY_FLAGS $RETENTION_CLEAN_TIME $TARGET/ldap 2>&1
		duplicity remove-all-inc-of-but-n-full $DUPLICITY_FLAGS $RETENTION_MAX_FULL $TARGET/ldap 2>&1
	fi

	if [ ${BACKUP_DB_ENABLED} == 'true' ]; then
		duplicity remove-older-than $DUPLICITY_FLAGS $RETENTION_CLEAN_TIME $TARGET/database
		duplicity remove-all-inc-of-but-n-full $DUPLICITY_FLAGS $RETENTION_MAX_FULL $TARGET/database
	fi

	if [ ${BACKUP_CONTENTSTORE_ENABLED} == 'true' ]; then
		duplicity remove-older-than $DUPLICITY_FLAGS $RETENTION_CLEAN_TIME $TARGET/contentstore 2>&1
		duplicity remove-all-inc-of-but-n-full $DUPLICITY_FLAGS $RETENTION_MAX_FULL $TARGET/contentstore 2>&1
	fi

	set +x
}

# TARGET
function cleanup() {
	if [ ${BACKUP_LDAP_ENABLED} == 'true' ]; then
		duplicity cleanup $DUPLICITY_FLAGS --force $TARGET/ldap 2>&1
	fi
	if [ ${BACKUP_DB_ENABLED} == 'true' ]; then
		duplicity cleanup $DUPLICITY_FLAGS --force $TARGET/database 2>&1
	fi
	if [ ${BACKUP_CONTENTSTORE_ENABLED} == 'true' ]; then
		duplicity cleanup $DUPLICITY_FLAGS --force $TARGET/contentstore 2>&1
	fi
	set +x
}

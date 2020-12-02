#! /usr/bin/env bash
set -e # Exit on fail
#
# Copyright (c) 2013 Toni de la Fuente.
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the Apache License as published by the Apache Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. 
#
# Most recent information about this tool is available in:
# http://blyx.com/alfresco-bart
#
# Latest code available at:
# http://blyx.com/alfresco-bart
#
#########################################################################################
# alfresco-bart: ALFRESCO BACKUP AND RECOVERY TOOL 
# Version 0.3     
#########################################################################################
# ACTION REQUIRED:
# CONFIGURE alfresco-bart in the alfresco-bart.properties file and ALFBRT_PATH
# in this file.
# Copy all files into your ALFRESCO_INSTALLATION_PATH/scripts.
# RUN ./alfresco-bart.sh [backup|recovery|verify|collection|list] 
#########################################################################################
#
# Run backup daily at 5AM
# 0 5 * * * root /path/to/alfresco-bart.sh backup 
#
#########################################################################################

ALFBRT_LOG_FILE=/dev/stdout

# Load properties
if [ -n "$ALFBRT_PATH" ]; then
  ALFBRT_PATH="$ALFBRT_PATH"
else
  ALFBRT_PATH="/opt/alfresco/scripts"
fi

if [ -f ${ALFBRT_PATH}/alfresco-bart.properties ]; then
	. ${ALFBRT_PATH}/alfresco-bart.properties 
else
	echo alfresco-bart.properties file not found, edit $0 and modify ALFBRT_PATH
fi

SSH_SETUP="false"
if [ $BACKUPTYPE == "sftp" ]; then
	SSH_SETUP="true"
fi
if [ $BACKUPTYPE == "scp" ]; then
	SSH_SETUP="true"
fi
if [ $SSH_SETUP == "true" ]; then
	echo "Writing SSH_KNOWN_HOST from bart config -> /root/.ssh/known_hosts"
	mkdir -p /root/.ssh
	echo ${SSH_KNOWN_HOST} > /root/.ssh/known_hosts

	if [ ! -f "/keys/ssh/initialized" ]; then
		echo "/keys/ssh/initialized does not exist, generating keys"
		mkdir "/keys/ssh" 
		ssh-keygen -f "/keys/ssh/id_ed25519" -N '' -t ed25519
		touch "/keys/ssh/initialized"
	fi

	echo "Restoring SSH keys from /keys/ssh -> /root/.ssh"
	cp -f /keys/ssh/id_ed25519 /root/.ssh/id_ed25519
	cp -f /keys/ssh/id_ed25519.pub /root/.ssh/id_ed25519.pub
	echo
	echo "Authenticating with keypair with public key:"
	cat /root/.ssh/id_ed25519.pub
	echo
fi

# # Do not let this script run more than once
# PROC=`ps axu | grep -v "grep" | grep --count "duplicity"`
# if [ $PROC -gt 0 ]; then 
# 	echo "alfresco-bart.sh or duplicity is already running."
# 	exit 1
# fi

# Command usage menu
usage(){
echo "USAGE:
    `basename $0` <mode> [set] [date <dest>]

Modes:
    backup [set]	runs an incremental backup or a full if first time
    restore [set] [date] [dest]	runs the restore, wizard if no arguments
    verify [set]	verifies the backup
    collection [set]	shows all the backup sets in the archive
    list [set]		lists the files currently backed up in the archive
	maintenance [set] manually run maintenance commands on archive

Sets:
    all		do all backup sets
    ldap	use ldap backup set for mode
    db		use data base backup set (group) for selected mode
    cs		use content store backup set (group) for selected mode"
}

# Checks if encryption is required if not it adds appropiate flag
if [ $ENCRYPTION_ENABLED = "true" ]; then
	export PASSPHRASE
else
	NOENCFLAG="--no-encryption"
fi

if [[ ! $GPG_OPTIONS = "" ]]; then
	echo "Setting GPG Options: ${GPG_OPTIONS}"
	GPGFLAGS="--gpg-options ${GPG_OPTIONS}"
fi

# Checks backup type, target selected
case $BACKUPTYPE in
	"s3" ) 
	    export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}"
        export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}"
		DEST=${S3FILESYSLOCATION}
		PARAMS="${GLOBAL_DUPLICITY_PARMS} ${GLOBAL_DUPLICITY_CACHE_PARMS} ${S3OPTIONS} ${NOENCFLAG} ${GPGFLAGS}"
		;;
	"ftp" ) 
		if [ ${FTPS_ENABLE} == 'false' ]; then
   			DEST=ftp://${FTP_USER}:${FTP_PASSWORD}@${FTP_SERVER}:${FTP_PORT}/${FTP_FOLDER}
   			PARAMS="${GLOBAL_DUPLICITY_PARMS} ${GLOBAL_DUPLICITY_CACHE_PARMS} ${NOENCFLAG} ${GPGFLAGS}"
		else
   			DEST=ftps://${FTP_USER}:${FTP_PASSWORD}@${FTP_SERVER}:${FTP_PORT}/${FTP_FOLDER}
   			PARAMS="${GLOBAL_DUPLICITY_PARMS} ${GLOBAL_DUPLICITY_CACHE_PARMS} ${NOENCFLAG} ${GPGFLAGS}"
		fi
		;;	
	"scp" )
		if [ "$SCP_PORT" != "" ]; then
			DEST=scp://${SCP_USER}@${SCP_SERVER}:${SCP_PORT}/${SCP_FOLDER}
		else
			DEST=scp://${SCP_USER}@${SCP_SERVER}/${SCP_FOLDER}
		fi
		PARAMS="${GLOBAL_DUPLICITY_PARMS} ${GLOBAL_DUPLICITY_CACHE_PARMS} ${NOENCFLAG} ${GPGFLAGS}"
		;;
	"sftp" )
		if [ "$SFTP_PORT" != "" ]; then
			DEST=sftp://${SFTP_USER}@${SFTP_SERVER}:${SFTP_PORT}/${SFTP_FOLDER}
		else
			DEST=sftp://${SFTP_USER}@${SFTP_SERVER}/${SFTP_FOLDER}
		fi
		PARAMS="${GLOBAL_DUPLICITY_PARMS} ${GLOBAL_DUPLICITY_CACHE_PARMS} ${NOENCFLAG} ${GPGFLAGS}"
		;;
	"local" )
		# command sintax is "file:///" but last / is coming from ${LOCAL_BACKUP_FOLDER} variable
		DEST=file://${LOCAL_BACKUP_FOLDER}
		PARAMS="${GLOBAL_DUPLICITY_PARMS} ${GLOBAL_DUPLICITY_CACHE_PARMS} ${NOENCFLAG} ${GPGFLAGS}"
		;;
	* ) echo "`date +%F-%X` - [ERROR] Unknown BACKUP type <$BACKUPTYPE>, review your alfresco-backup.properties" ;; 
esac

function ldapBackup {

	if [ ! -d $LOCAL_BACKUP_LDAP_DIR ]; then
		mkdir -p $LOCAL_BACKUP_LDAP_DIR
	fi
	echo 
	echo "`date +%F-%X` - $BART_LOG_TAG Backing up ldap to $BACKUPTYPE" 
	echo "`date +%F-%X` - $BART_LOG_TAG Starting backup - ldap " 

	set -v
	ldapsearch -x -H $LDAP_ADDRESS -b $LDAP_ROOTDN -w $LDAP_ROOTPASSWORD -D $LDAP_ROOTUSER -LLL > $LOCAL_BACKUP_LDAP_DIR/ldap.ldif 
	set +v
	set -x
  	$DUPLICITYBIN $PARAMS $LOCAL_BACKUP_LDAP_DIR $DEST/ldap
	set +x
}

function dbBackup {
	
	if [ ! -d $LOCAL_BACKUP_DB_DIR ]; then
		mkdir -p $LOCAL_BACKUP_DB_DIR
	fi
	
	case $DBTYPE in 
		"mysql" ) 
			echo "`date +%F-%X` - $BART_LOG_TAG Backing up the Alfresco DB to $BACKUPTYPE" 
  			echo "`date +%F-%X` - $BART_LOG_TAG Starting backup - Alfresco $DBTYPE DB" 
			# Mysql dump

			set -x
			$MYSQL_BINDIR/$MYSQLDUMP_BIN --single-transaction -u $DBUSER -h $DBHOST -p$DBPASS $DBNAME | $GZIP -9 > $LOCAL_BACKUP_DB_DIR/$DBNAME.dump
  			$DUPLICITYBIN $PARAMS $LOCAL_BACKUP_DB_DIR $DEST/db 
  			echo "`date +%F-%X` - $BART_LOG_TAG cleaning DB backup" 
  			rm -fr $LOCAL_BACKUP_DB_DIR/$DBNAME.dump
			set +x
			
		;; 
		"postgresql" ) 		
			echo "`date +%F-%X` - $BART_LOG_TAG Backing up the Alfresco DB to $BACKUPTYPE" 
  			echo "`date +%F-%X` - $BART_LOG_TAG Starting backup - Alfresco $DBTYPE DB" 
			# PG dump in plain text format and compressed 
			export PGPASSFILE=$PGPASSFILE
			export PGPASSWORD=$DBPASS

			set -x
			$PGSQL_BINDIR/$PGSQLDUMP_BIN -Fc -w -h $DBHOST -U $DBUSER $DBNAME > $LOCAL_BACKUP_DB_DIR/$DBNAME.sql.Fc
  			$DUPLICITYBIN $PARAMS $LOCAL_BACKUP_DB_DIR $DEST/db 
  			echo "`date +%F-%X` - $BART_LOG_TAG cleaning DB backup" 
  			rm -fr $LOCAL_BACKUP_DB_DIR/$DBNAME.sql.Fc
			set +x
		;; 
		
		* ) 
		echo "`date +%F-%X` - [ERROR] Unknown DB type \"$DBTYPE\", review your alfresco-bart.properties. Backup ABORTED!" 
		exit 1
		;; 
	esac 
}

function contentStoreBackup {
	echo 
	# Getting a variable to know all includes and excludes
	CONTENTSTORE_DIR_INCLUDES="--include $ALF_CONTENTSTORE"
	if [ "$ALF_CONTENSTORE_DELETED" != "" ]; then
		CS_DIR_INCLUDE_DELETED=" --include $ALF_CONTENSTORE_DELETED"
	fi
	if [ "$ALF_CACHED_CONTENTSTORE" != "" ]; then
		CS_DIR_INCLUDE_CACHED=" --include $ALF_CACHED_CONTENTSTORE"
	fi
	if [ "$ALF_CONTENTSTORE2" != "" ]; then
		CS_DIR_INCLUDE_CS2=" --include $ALF_CONTENTSTORE2"
	fi
	if [ "$ALF_CONTENTSTORE3" != "" ]; then
		CS_DIR_INCLUDE_CS3=" --include $ALF_CONTENTSTORE3"
	fi
	if [ "$ALF_CONTENTSTORE4" != "" ]; then
		CS_DIR_INCLUDE_CS4=" --include $ALF_CONTENTSTORE4"
	fi
	if [ "$ALF_CONTENTSTORE5" != "" ]; then
		CS_DIR_INCLUDE_CS5=" --include $ALF_CONTENTSTORE5"
	fi
	
	CONTENTSTORE_EXCLUDE_PARENT_DIR="$(dirname "$ALF_CONTENTSTORE")"
  	
  	echo "`date +%F-%X` - $BART_LOG_TAG Backing up the Alfresco ContentStore to $BACKUPTYPE" 
 	# Content Store backup itself 
	set -x
  	$DUPLICITYBIN $PARAMS $CONTENTSTORE_DIR_INCLUDES $CS_DIR_INCLUDE_DELETED $CS_DIR_INCLUDE_CACHED \
  	$CS_DIR_INCLUDE_CS2 $CS_DIR_INCLUDE_CS3 $CS_DIR_INCLUDE_CS4 $CS_DIR_INCLUDE_CS5 \
  	--exclude $CONTENTSTORE_EXCLUDE_PARENT_DIR $CONTENTSTORE_EXCLUDE_PARENT_DIR \
  	$DEST/cs 
	set +x
}

function restoreOptions (){
	if [ "$WIZARD" = "1" ]; then
		RESTORE_TIME=$RESTOREDATE
		RESTOREDIR=$RESTOREDIR
	else
		RESTORE_TIME=$3
			if [ -z $4 ]; then
				usage
				exit 0
			else
				RESTOREDIR=$4
			fi
	fi
}

function restoreDb (){
	restoreOptions $1 $2 $3 $4
	if [ ${BACKUP_DB_ENABLED} == 'true' ]; then
		echo " =========== Starting restore DB from $DEST/db to $RESTOREDIR/db==========="
		echo "`date +%F-%X` - $BART_LOG_TAG - Recovery $RESTORE_TIME_FLAG $DEST/db $RESTOREDIR/db" 
		set -x
		$DUPLICITYBIN restore --restore-time $RESTORE_TIME ${NOENCFLAG} ${GLOBAL_DUPLICITY_CACHE_PARMS} $DEST/db $RESTOREDIR/db
		set +x
		if [ ${DBTYPE} == 'mysql' ]; then
			mv $RESTOREDIR/db/$DBNAME.dump $RESTOREDIR/db/$DBNAME.dump.gz
			echo ""
			echo "DB from $DEST/db... DONE!"
			echo ""
		fi
		if [ ${DBTYPE} == 'postgresql' ]; then
			echo ""
			echo "DB from $DEST/db... DONE!"
			echo ""
		fi
	else
		echo "No backup DB configured to backup. Nothing to restore."
	fi
}
	
function restoreContentStore (){
	restoreOptions $1 $2 $3 $4
	if [ ${BACKUP_CONTENTSTORE_ENABLED} == 'true' ]; then
		echo " =========== Starting restore CONTENT STORE from $DEST/cs to $RESTOREDIR/cs ==========="
		echo "`date +%F-%X` - $BART_LOG_TAG - Recovery $RESTORE_TIME_FLAG $DEST/cs $RESTOREDIR/cs" 
		set -x
		$DUPLICITYBIN restore --restore-time $RESTORE_TIME ${NOENCFLAG} ${GLOBAL_DUPLICITY_CACHE_PARMS} $DEST/cs $RESTOREDIR/cs
		set +x
		echo ""
		echo "CONTENT STORE from $DEST/cs... DONE!"
		echo ""
	else
		echo "No backup CONTENTSTORE configured to backup. Nothing to restore."
	fi
}

function restoreLdap (){
	restoreOptions $1 $2 $3 $4
	if [ ${BACKUP_LDAP_ENABLED} == 'true' ]; then
		echo " =========== Starting restore LDAP from $DEST/ldap to $RESTOREDIR/ldap ==========="
		echo "`date +%F-%X` - $BART_LOG_TAG - Recovery $RESTORE_TIME_FLAG $DEST/ldap $RESTOREDIR/ldap" 
		set -x
		$DUPLICITYBIN restore --restore-time $RESTORE_TIME ${NOENCFLAG} ${GLOBAL_DUPLICITY_CACHE_PARMS} $DEST/ldap $RESTOREDIR/ldap
		set +x
		echo ""
		echo "FILES from $DEST/files... DONE!"
		echo ""
	else
		echo "No backup FILES configured to backup. Nothing to restore."
	fi
}
	
function restoreWizard(){
	WIZARD=1
    clear
    echo "################## Welcome to Alfresco BART Recovery wizard ###################"
    echo ""
    echo " This backup and recovery tool does not overrides nor modify your existing	"
    echo " data, then you must have a destination folder ready to do the entire 	"
    echo " or partial restore process.											        "
    echo ""
    echo "##############################################################################"
    echo ""
    echo " Choose a restore option:"
    echo "	1) Full restore"
    echo " 	2) Set restore"
    echo ""
    echo -n " Enter an option [1|2] or CTRL+c to exit: " 
    builtin read ASK1
    case $ASK1 in
    	1 ) 
    		RESTORECHOOSED=full
			while [ ! -w $RESTOREDIR ]; do
    			echo " Directory $RESTOREDIR does not exist, creating"
    			mkdir -p $RESTOREDIR
    		done
    		echo ""
    		echo " This wizard will help you to restore your Data Base, Content Store and rest of files to a given directory."
    		echo ""
    		echo -n " Do you want to see what backups collections are available to restore? [yes|no]: "
			read SHOWCOLANSWER
			shopt -s nocasematch
			case "$SHOWCOLANSWER" in
  				y|yes) 
  					collectionCommands collection all
					;;
  				n|no) 
    				;;
  				* ) echo "Incorrect value provided. Please enter yes or no." 
  				;; 
			esac
    		echo ""
    		echo " Specify a backup DATE (YYYY-MM-DD) to restore at or a number of DAYS+D since your valid backup. I.e.: if today is August 1st 2013 and want to restore a backup from July 26th 2013 then type \"2013-07-26\" or \"5D\" without quotes."
    		echo -n " Please type a date or number of days (use 'now' for last backup): " 
    		builtin read RESTOREDATE
    		echo ""
    		echo " You want to restore a $RESTORECHOOSED backup from $BACKUPTYPE with date $RESTOREDATE to $RESTOREDIR"
    		echo -n " Is that correct? [yes|no]: "
    		read CONFIRMRESTORE
    		#duplicity restore --restore-time 
			read -p " To start restoring your selected backup press ENTER or CTRL+C to exit"
			echo ""
			restoreLdap
			restoreDb
			restoreContentStore
			echo ""
			echo " Restore finished! Now you have to copy and replace your existing content with the content left in $RESTOREDIR, if you need a guideline about how to recovery your Alfresco installation from a backup please read the Alfresco Backup and Desaster Recovery White Paper file."
			echo ""
			exit 1
		;; 		
    	
  		2 ) 
  			RESTORECHOOSED=partial
			while [ ! -w $RESTOREDIR ]; do
    			echo " ERROR! Directory $RESTOREDIR does not exist or it does not have write permissions"
    			echo -n " please enter a valid path to restore to: "
    			builtin read RESTOREDIR
    		done
    		echo ""
    		echo " This wizard will help you to restore one of your backup components: Data Base, Content Store or rest of files to a given directory."
    		echo ""
    		echo -n " Type a component to restore [db|cs|files|ldap]: "
    		builtin read BACKUPGROUP
    		echo ""
    		echo -n " Do you want to see what backups collections are available for $BACKUPGROUP to restore? [yes|no]: "
			read SHOWCOLANSWER
			shopt -s nocasematch
			case "$SHOWCOLANSWER" in
  				y|yes) 
  					collectionCommands collection $BACKUPGROUP
					;;
  				n|no) 
    				;;
  				* ) echo "Incorrect value provided. Please enter yes or no." 
  				;; 
			esac
    		echo ""
    		echo " Specify a backup DATE (YYYY-MM-DD) to restore at or a number of DAYS+D since your valid backup. I.e.: if today is August 1st 2013 and want to restore a backup from July 26th 2013 then type \"2013-07-26\" or \"5D\" without quotes."
    		echo -n " Please type a date or number of days (use 'now' for last backup): " 
    		builtin read RESTOREDATE 
    		echo ""
    		echo " You want to restore a $RESTORECHOOSED backup of $BACKUPGROUP from $BACKUPTYPE with date $RESTOREDATE to $RESTOREDIR"
    		echo -n " Is that correct? [yes|no]: "
    		read CONFIRMRESTORE
    		#duplicity restore --restore-time 
			read -p " To start restoring your selected backup press ENTER or CTRL+C to exit"
			echo ""
			case $BACKUPGROUP in
			"db" )
				restoreDb
			;;
			"cs" )
				restoreContentStore
			;;
			"ldap" )
				restoreLdap
    		;;
			* )
				echo "ERROR: Invalid parameter, there is no backup group with this name!"
		
			esac
			echo ""
			echo " Restore finished! Now you have to copy and replace your existing content with the content left in $RESTOREDIR, if you need a guideline about how to recovery your Alfresco installation from a backup please read the Alfresco Backup and Desaster Recovery White Paper."
			echo ""
			exit 1
		;;
  		q ) 
  			exit 0
  		;;
  		* ) 
  			restoreWizard
  		;;
		esac
}			

function verifyCommands (){
#    	if [ -z $2 ]; then	
#			echo "Please specify a valid backup group name to verify [db|cs|files|all]" 
#		else
		case $2 in
			"ldap" )
				echo "=========================== BACKUP VERIFICATION FOR LDAP ==========================="    
				set -x
    			$DUPLICITYBIN verify -v${DUPLICITY_LOG_VERBOSITY} ${NOENCFLAG}  ${GLOBAL_DUPLICITY_CACHE_PARMS} $DEST/ldap $LOCAL_BACKUP_LDAP_DIR
				set +x
			;;
			"db" )
				echo "=========================== BACKUP VERIFICATION FOR DB $DBTYPE ==========================="    
				set -x
    			$DUPLICITYBIN verify -v${DUPLICITY_LOG_VERBOSITY} ${NOENCFLAG}  ${GLOBAL_DUPLICITY_CACHE_PARMS} $DEST/db $LOCAL_BACKUP_DB_DIR
				set +x
			;;
			"cs" )
				echo "=========================== BACKUP VERIFICATION FOR CONTENTSTORE ==========================="
				set -x
    			$DUPLICITYBIN verify -v${DUPLICITY_LOG_VERBOSITY} ${NOENCFLAG}  ${GLOBAL_DUPLICITY_CACHE_PARMS} $DEST/cs $ALF_DIRROOT |grep contentstore
				set +x
			;;
			* )
				echo "=========================== BACKUP VERIFICATION FOR LDAP ==========================="    
				set -x
    			$DUPLICITYBIN verify -v${DUPLICITY_LOG_VERBOSITY} ${NOENCFLAG}  ${GLOBAL_DUPLICITY_CACHE_PARMS} $DEST/ldap $LOCAL_BACKUP_LDAP_DIR
				set +x

				echo "=========================== BACKUP VERIFICATION FOR DB $DBTYPE ==========================="    
				set -x
    			$DUPLICITYBIN verify -v${DUPLICITY_LOG_VERBOSITY} ${NOENCFLAG}  ${GLOBAL_DUPLICITY_CACHE_PARMS} $DEST/db $LOCAL_BACKUP_DB_DIR
				set +x

				echo "=========================== BACKUP VERIFICATION FOR CONTENTSTORE ==========================="
				set -x
    			$DUPLICITYBIN verify -v${DUPLICITY_LOG_VERBOSITY} ${NOENCFLAG}  ${GLOBAL_DUPLICITY_CACHE_PARMS} $DEST/cs $ALF_DIRROOT |grep contentstore
				set +x
			;;
		esac 
#		fi
}

function listCommands(){
		case $2 in
			"ldap" )
				set -x
				$DUPLICITYBIN list-current-files -v${DUPLICITY_LOG_VERBOSITY} ${NOENCFLAG}  ${GLOBAL_DUPLICITY_CACHE_PARMS} $DEST/ldap
				set +x
			;;
			"db" )
				set -x
				$DUPLICITYBIN list-current-files -v${DUPLICITY_LOG_VERBOSITY} ${NOENCFLAG}  ${GLOBAL_DUPLICITY_CACHE_PARMS} $DEST/db
				set +x
			;;
			"cs" )
			set -x
				$DUPLICITYBIN list-current-files -v${DUPLICITY_LOG_VERBOSITY} ${NOENCFLAG}  ${GLOBAL_DUPLICITY_CACHE_PARMS} $DEST/cs
				set +x
			;;
			* )
			set -x
				$DUPLICITYBIN list-current-files -v${DUPLICITY_LOG_VERBOSITY} ${NOENCFLAG}  ${GLOBAL_DUPLICITY_CACHE_PARMS} $DEST/ldap; \
				$DUPLICITYBIN list-current-files -v${DUPLICITY_LOG_VERBOSITY} ${NOENCFLAG}  ${GLOBAL_DUPLICITY_CACHE_PARMS} $DEST/db; \
				$DUPLICITYBIN list-current-files -v${DUPLICITY_LOG_VERBOSITY} ${NOENCFLAG}  ${GLOBAL_DUPLICITY_CACHE_PARMS} $DEST/cs;
				set +x
			;;
		esac 
#		fi
}

function collectionCommands () {
		case $2 in
			"ldap" )
				echo "=========================== BACKUP COLLECTION FOR LDAP =========================="
				set -x
    			$DUPLICITYBIN collection-status -v0 ${NOENCFLAG}  ${GLOBAL_DUPLICITY_CACHE_PARMS} $DEST/ldap
				set +x
			;;
			"db" )
				echo "=========================== BACKUP COLLECTION FOR DB $DBTYPE =========================="
				set -x
    			$DUPLICITYBIN collection-status -v0 ${NOENCFLAG}  ${GLOBAL_DUPLICITY_CACHE_PARMS} $DEST/db
				set +x
			;;
			"cs" )
				echo "========================== BACKUP COLLECTION FOR CONTENTSTORE ========================="
				set -x
    			$DUPLICITYBIN collection-status -v0 ${NOENCFLAG}  ${GLOBAL_DUPLICITY_CACHE_PARMS} $DEST/cs
				set +x
			;;
			* )
				echo "=========================== BACKUP COLLECTION FOR LDAP =========================="
				set -x 
				$DUPLICITYBIN collection-status -v0 ${NOENCFLAG}  ${GLOBAL_DUPLICITY_CACHE_PARMS} $DEST/ldap
				set +x

				echo "=========================== BACKUP COLLECTION FOR DB $DBTYPE =========================="
				set -x
				$DUPLICITYBIN collection-status -v0 ${NOENCFLAG}  ${GLOBAL_DUPLICITY_CACHE_PARMS} $DEST/db
				set +x

				echo "========================== BACKUP COLLECTION FOR CONTENTSTORE ========================="
				set -x
				$DUPLICITYBIN collection-status -v0 ${NOENCFLAG}  ${GLOBAL_DUPLICITY_CACHE_PARMS} $DEST/cs
				set +x
			;;
		esac 
#		fi
}
    
function maintenanceCommands () {
	echo 	
	# Function to apply backup policies
	echo "`date +%F-%X` - $BART_LOG_TAG Running maintenance commands" 
	set -x
	
	if [ ${BACKUP_LDAP_ENABLED} == 'true' ]; then
		
  		$DUPLICITYBIN remove-older-than $CLEAN_TIME -v${DUPLICITY_LOG_VERBOSITY}  ${GLOBAL_DUPLICITY_CACHE_PARMS} --force $DEST/ldap  2>&1
  		
  		$DUPLICITYBIN remove-all-inc-of-but-n-full $MAXFULL -v${DUPLICITY_LOG_VERBOSITY}  ${GLOBAL_DUPLICITY_CACHE_PARMS} --force $DEST/ldap  2>&1
	fi 
	
	if [ ${BACKUP_DB_ENABLED} == 'true' ]; then
		
		$DUPLICITYBIN remove-older-than $CLEAN_TIME -v${DUPLICITY_LOG_VERBOSITY}  ${GLOBAL_DUPLICITY_CACHE_PARMS} --force $DEST/db 
		
		$DUPLICITYBIN remove-all-inc-of-but-n-full $MAXFULL -v${DUPLICITY_LOG_VERBOSITY}  ${GLOBAL_DUPLICITY_CACHE_PARMS} --force $DEST/db 
	fi

	if [ ${BACKUP_CONTENTSTORE_ENABLED} == 'true' ]; then
		
  		$DUPLICITYBIN remove-older-than $CLEAN_TIME -v${DUPLICITY_LOG_VERBOSITY}  ${GLOBAL_DUPLICITY_CACHE_PARMS} --force $DEST/cs  2>&1
  		
  		$DUPLICITYBIN remove-all-inc-of-but-n-full $MAXFULL -v${DUPLICITY_LOG_VERBOSITY}  ${GLOBAL_DUPLICITY_CACHE_PARMS} --force $DEST/cs  2>&1
	fi

	set +x
}

# Main options
PARAMS="$PARAMS --allow-source-mismatch" #KF override as docker changes hose ID
case $1 in
	"backup" ) 
		case $2 in
			"db" )
			# Run backup of db if enabled
			if [ ${BACKUP_DB_ENABLED} == 'true' ]; then
				dbBackup
			fi
			;;
			"ldap" )
			# Run backup of db if enabled
			if [ ${BACKUP_DB_ENABLED} == 'true' ]; then
				ldapBackup
			fi
			;;
			"cs" )
			# Run backup of contentStore if enabled
			if [ ${BACKUP_CONTENTSTORE_ENABLED} == 'true' ]; then
				contentStoreBackup
			fi
			;;
			* )
				case $3 in 
					"force" )
						PARAMS="$PARAMS --allow-source-mismatch"
					;;
				esac
			
			echo "`date +%F-%X` - $BART_LOG_TAG Starting backup" 
			echo "`date +%F-%X` - $BART_LOG_TAG Set script variables done" 
			# Run backup of ldap if enabled
			if [ ${BACKUP_LDAP_ENABLED} == 'true' ]; then
				ldapBackup
			fi
			# Run backup of db if enabled
			if [ ${BACKUP_DB_ENABLED} == 'true' ]; then
				dbBackup
			fi
			# Run backup of contentStore if enabled
			if [ ${BACKUP_CONTENTSTORE_ENABLED} == 'true' ]; then
				contentStoreBackup
			fi
			# Maintenance commands (cleanups and apply retention policies)
			if [ ${BACKUP_POLICIES_ENABLED} == 'true' ]; then
				maintenanceCommands
			fi
		esac

	;;
	
	"restore" )	
		case $2 in
			"ldap" )
				restoreLdap $1 $2 $3 $4
			;;
			"db" )
				restoreDb $1 $2 $3 $4
			;;
			"cs" )
				restoreContentStore $1 $2 $3 $4
			;;
			"all" )
				restoreDb $1 $2 $3 $4
				restoreContentStore $1 $2 $3 $4
				restoreLdap $1 $2 $3 $4
			;;
			* )
			restoreWizard
		esac
   	
    ;;
    
	"verify" ) 
		verifyCommands $1 $2
	;;
    
	"list" ) 
    	listCommands $1 $2
    ;;
    
	"collection" )
		collectionCommands $1 $2
    ;;

	"maintenance" )
		maintenanceCommands
	;;
    
	* ) 	
		usage
	;;
esac

echo "`date +%F-%X` - $BART_LOG_TAG Done" 

# Unload al security variables
unset PASSPHRASE
unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset DBPASS
unset FTP_PASSWORD
unset REC_MYPASS
unset REC_PGPASS
unset REC_ORAPASS
unset PGPASSWORD
Modified by KF

An additional script has been added, executable via `restore_container.sh`.

This will take files restored by BART into `/tmp`, and restore them to the alfresco and postgres database containers. This should be run after performing a BART restore

BART commands can be called once the container is running via `docker exec -it bart bart.sh <command>`. For example, `docker exec -it bart bart.sh backup`. 

Restore_container can be called as `docker exec -it bart restore_container.sh`.




Alfresco BART - Backup and Recovery Tool
========================================
Copyright (c) 2013 Toni de la Fuente blyx.com.

Please read LICENSE file for information about Apache 2.0.

For install instructions see INSTALL file.

## CHANGELOG

#### [Aug/6/13] v0.1 
	* first release

#### [Nov/5/13] v0.2 
	* fixed LOCAL_DB_DIR comment
	* added PGPASSWORD on dump command for Postgresql
	* added date and time to any DB dump
	* added logging to db dumps
	* added backup of full Solr directory except live indexes (like a default installation based on the installer)
	* added command line option to backup task, now you can invoke directly backup set (index, db, cs or files), if nothing is specified a backup will be done as in the configuration file.
	* improved command options for restoration
	* added "--single-transaction" to the mysqldump command
	* added single file recovery from the contentstore (only mysql installations supported)
	* added single file or directory recovery from the installation files.
	* added "--allow-source-mismatch" in a force option if source hostname changes

#### [Oct/22/18] v0.3 
	* fixed S3 authentication
    * fixed script fails when the "EXCLUDE" paths are not inside alf_dir
    * fix for the missed ${NOENCFLAG} during restore
    * PostgreSQL dump format changed
    * folder destination changed for index and database to be fixed instead of based on the db type or index type
    * fix for the "date" printed in the log that was not updated while the script was running
    * added GLOBAL_DUPLICITY_CACHE_PARMS param in order to let the user configure where to keep the cache files
    * added SCP_PORT param in order to let the user configure the SFTP/SCP port when it is not the default 22. Also included the new SFTP related parameters, with the backup type as sftp
    * removed the "--extra-clean" parameter, as this can led to problems when the user needs to restore a backup

## ISSUES
Please use Github issues for any comment, bug or new features
https://github.com/toniblyx/alfresco-backup-and-recovery-tool/issues

## DESCRIPTION
Alfresco BART is a backup and recovery tool for Alfresco ECM. Is a shell script tool based on Duplicity for Alfresco backups and restore from a local file system, FTP, SCP, SFTP or Amazon S3 of all its components: indexes, data base, content store and all deployment and configuration files. It should runs in most Linux distributions, for Windows you may use Cygwin (non tested yet).

Brief description of its features: full and incremental backups, backup policies, backup volume control, encryption with GPG, compression. Also it has a restore wizard with shortcuts for quick restore of some key components (alfresco-global.properties and more).

## FEATURES
Full list of the first version here http://blyx.com/2013/08/07/alfresco-backup-and-recovery-tool-release-v0-1/

## USAGE
See samples here: http://blyx.com/2013/12/11/essential-commands-for-alfresco-bart/

### Features in this version (v0.2):
see CHANGELOG

### Features in this version (v0.1):

#### 5 different modes of work: backup, restore, verify, collection and list
    * backup: runs an incremental backup or a full if first time or configured
    * restore: runs the restore wizard
    * verify: verifies the backup
    * collection: shows all the backup sets in the archive
    * list: lists the files currently backed up in the archive
      
#### Full and incremental backups.

#### Backup policies:
    * periodicity: number of days of every full backup, if not backup found it does a full
    * retention: keep full or incremental copies, clean old backups.
    * control of number of moths to remove all backups older than or backup retention period.
      
#### Separated components (backup sets or groups), ability to enable or disable any set (cluster and dedicated search server aware), all backup sets supported are:
    * Indexes (SOLR or Lucene)
    * Data base (MySQL, PostgreSQL and Oracle)
    * Content Store plus deleted, cached and content store selector (optional).
    * Files: all configuration files, deployments, installation files, etc.

#### Restore wizard with support to:
    * restore a full backup (all sets)
    * given backup set
    * restore from a given date or days, month, year ago
    * restore alfresco-global.properties from a point in time

#### Backup volume control:
    * All backups collections are split in a volume size 25MB by default, this can help to store your backup in tapes or in order to upload to a FTP, SCP, SFTP or S3 server.

#### Backup to different destinations:
    * Local filesystem 
    * Remote FTP or FTPS server
    * SCP or SFTP server (should have shared keys already configured, no authentication with user and password supported)
    * Amazon S3 

#### Encryption with GnuPG, all backup volumes are encrypted, this feature is configurable (enable or disable).

#### Compression, all backup volumes are compressed by default

#### Log reporting, Alfresco BART creates a log file each day of operation with in a report of any activity.

## DEPENDENCES 
    * Duplicity 0.6 (with boot and fabric)
    * Python 
    * GnuPG
    * NcFTP
    * librsync
    * mysqldump for MySQL backup
    * pg_dump for PostgreSQL backup
    * imp for Oracle backup

## TODO
   * Force Solr index backup
   * Add more input and task controllers (and configuration, first run).
   * Snapshots (LVM if exist, AWS if exist).
   * Support for MS SQL Server.
   * Configuration wizard (shell).
   * Share admin panel configuration page as main point to configure more options related to backup (eager, cleaner, index backup, trascan cleaner, etc.).
   * More tests with JBOSS, MySQL, Oracle, S3, FTPs, SCP, etc.
   * Custom logging control and reporting improvement.

## HOW TO RESTORE A MYSQL DATABASE:
To restore this MySQL database use next command (the existing db must be empty):
gunzip < $RESTOREDIR/$DBTYPE/$DBNAME.dump.gz | mysql -u $DBUSER -p$DBPASS $DBNAME

## HOW TO CREATE A RECOVERY DB (for single repository file recovery option)
MySQL:
mysql> create database alfresco_rec;
mysql> grant all privileges on alfresco_rec.* to 'alfresco'@'localhost' identified by 'alfresco';

## HOW TO RESTORE YOUR BACKUP IN A DIFFERENT SEVER

1- Install Alfresco BART as usual.
2- Copy the directory ~/.gnupg from de original server to the new one (if gpg encryption is used).
3- Run the recovery wizard as usual.
4- Enjoy restoring your disaster recovery environment.

## HOSTNAME CHANGES ERROR
Fatal Error: Backup source host has changed. (added --allow-source-mismatch)
Run once: ./alfresco-bart.sh backup all force

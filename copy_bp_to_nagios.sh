#!/bin/bash

#Variabeln
FILE=bp_generated.cfg
SOURCEPATH=/etc/shinken/services
TARGETPATH=/usr/local/nagios/etc/objects/bp
TARGETSYSTEM=systemname
USER=root
BACKUP=$(date +'%Y%m%d%k%M%S')_$FILE
BACKUPFOLDER=$TARGETPATH/backup
IDENTITY=/home/username/.ssh/id_dsa

#Backup & Konfigurieren
ssh -i $IDENTITY $USER@$TARGETSYSTEM 'cd '"$TARGETPATH"'; cp '"$FILE"' '"$BACKUPFOLDER/$BACKUP"';'
scp -i $IDENTITY $SOURCEPATH/$FILE $USER@$TARGETSYSTEM:$TARGETPATH/$FILE

#Alternative über RSYNC
#rsync -avzh $SOURCEPATH/$FILE $USER@TARGETSYSTEM:$TARGETPATH/$FILE

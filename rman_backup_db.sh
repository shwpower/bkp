#!/bin/ksh

#########################################################################
# Revision History
#########################################################################
# Wei           06-Dec-12 Creation
#               RMAN backup database base on instance name
#
#
########################################################################

function Usage
{
        print "ERROR! Usage: ${0##*/} -i [Oracle SID] "
}

######### Parameter define ################
while getopts i: next; do
        case $next in
                i)
                 SID=$OPTARG
                 ;;
                *)
                 Usage
                 ;;
        esac
done



######### Variable define ################

EXEDIR=/u01/usr/oracle/dba/rman_bkup
LOGDIR=/u01/usr/oracle/logs

export ORACLE_SID=${SID:?"ERROR! Usage: ${0##*/} -i [Oracle Sid] "}
USR=system
PASSWD=`/usr/local/bin/orapass ${USR}`
export ORACLE_HOME=`/usr/local/bin/dbhome ${ORACLE_SID}`

LOGFILE=${LOGDIR}/rman_backup_db.log
MAIL_RCV="shwpower@gmail.com"

if [ "`date +%a`" = "Sun" ]
then
        LEVEL=0;export LEVEL
else
        LEVEL=1;export LEVEL
fi

echo "Begin ${ORACLE_SID} RMAN Backup ... " `date`    > ${LOGFILE}

$ORACLE_HOME/bin/rman target $USR/$PASSWD nocatalog log $LOGFILE append << EOF
        sql 'alter system archive log current';
        allocate channel for maintenance type disk;
        crosscheck backup;
        crosscheck archivelog all completed before 'sysdate-1';
        delete noprompt archivelog all completed before 'sysdate-1';
        delete noprompt obsolete;
        backup incremental level $LEVEL database plus archivelog;
        delete noprompt obsolete;
EOF

echo "End ${ORACLE_SID} RMAN Backup ... " `date`    >> ${LOGFILE}

## Judge the backup status
ANY_ERROR=`egrep -i '(ORA-|ERROR|RMAN-)' ${LOGFILE} |wc -l`
if [[ $ANY_ERROR -ne 0 ]] ; then
        /usr/bin/mailx -s "Oracle RMAN $ORACLE_SID backup Error on `hostname`" ${MAIL_RCV} < ${LOGFILE}
else
        /usr/bin/mailx -s "Oracle RMAN $ORACLE_SID backup Completed successfully on `hostname`" ${MAIL_RCV} < ${LOGFILE}
fi

## Log history the expdp log file
cp ${LOGFILE} ${LOGFILE}.${ORACLE_SID}.`date +%Y-%b-%d-%H-%M-%S`

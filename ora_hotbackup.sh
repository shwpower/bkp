#!/bin/env ksh

# Author        : Shen Wei
# Modified By   : Shen Wei
# Revision      : Version 1.0
# Date Revised  : Nov 25, 2012
# Revision History :
#
#

# Variable define
alias dbhome=/usr/local/bin/dbhome
day=$(date +%Y_%m_%d)
MAIL_RCV="shwpower@gmail.com"

Usage () {
        print Without passing ORACLE_SID,script exit
        print Usage: $0 -i [ Oracle SID]
}

while getopts i: opt; do
        case $opt in
                i) SID=$OPTARG
                   ;;
                *) Usage
                   exit 0
                   ;;
        esac
done

# backup Archive log function
archbkup () {
        print "Removing Arrhive Log before copy $arch_retention days archivelog to $arch_back_dir"
        rm ${arch_back_dir}/*.arc
        print "Switch Latest Online Log File to be archived "
        sqlplus -s "/ as sysdba" << EOF
        alter system switch logfile;
        exit;
EOF

        ARCSEQ=`sqlplus -s "/ as sysdba" << EOF
        set heading off
        set feedback off
        select sequence# from v\\$loghist where first_time > sysdate-${arch_retention};
        exit;
EOF`
        for arcfile in `echo ${ARCSEQ}`
        do
                print "Backup ${arcfile} to ${arch_back_dir} at `date` "
                cp -p ${arch_dir}/*${arcfile}*.arc ${arch_back_dir}
                if [ $? = 0 ];then
                        print "Copy $arch_retention days of archivelog to ${arch_back_dir} Succeessful."
                else
                        print "Copy Archive Log Failed.Pls manually Housekeep Archivelog "|tee -a ${ERRORFILE}
                fi
        done
}

# Backup pfile, Password file & control file function
paramnctlbkup () {
        print Backup Control File
        if [ -f ${back_dir}/controlfile.bak ]; then
                rm -f ${back_dir}/controlfile.bak
        fi

        sqlplus -s "/ as sysdba" << EOF
        alter database backup controlfile to '${back_dir}/controlfile.bak';
        exit;
EOF
        print Backup Server Parameter File
        if [ -f ${back_dir}/spfile${SID}.ora ]; then
                rm -f ${back_dir}/spfile${SID}.ora
                print "cp -p ${ORACLE_HOME}/dbs/spfile${SID}.ora ${back_dir}/spfile${SID}.ora "
                cp -p ${ORACLE_HOME}/dbs/spfile${SID}.ora ${back_dir}/spfile${SID}.ora
        else
                print "cp -p ${ORACLE_HOME}/dbs/spfile${SID}.ora ${back_dir}/spfile${SID}.ora "
                cp -p ${ORACLE_HOME}/dbs/spfile${SID}.ora ${back_dir}/spfile${SID}.ora
        fi

        print Backup Passwd file
        if [ -f ${back_dir}/orapw${SID} ]; then
                rm -f ${b01}/orapw${SID}
                print "cp -p ${ORACLE_HOME}/dbs/orapw${SID} ${back_dir}/orapw${SID} "
                cp -p ${ORACLE_HOME}/dbs/orapw${SID} ${back_dir}/orapw${SID}
        else
                print "cp -p ${ORACLE_HOME}/dbs/orapw${SID} ${back_dir}/orapw${SID} "
                cp -p ${ORACLE_HOME}/dbs/orapw${SID} ${back_dir}/orapw${SID}
        fi
}

# Backup database file function
dbfbkup () {

        # Create current hotbackup SQL script
        $ORACLE_HOME/bin/sqlplus "/as sysdba" <<EOF
                set echo off
                set feedback off
                set heading off
                set verify off
                set linesize 120
                set long 2000
                set pages 0
                col ts_name noprint
                col order_by noprint
                spool temp_hotbackup.sql
                select 'spool $EXEDIR/copydf_${SID}.log' from dual;
                select name ts_name, 1 order_by, 'alter tablespace '||trim(name)||' begin backup;'
        from v\$tablespace where name<>'TEMP'
                union
                select t.name ts_name, 2 order_by, 'host cp '||trim(f.name)||' ${back_dir}'||substr(f.name,1,4)||'/oradata/${SID}'
        from v\$tablespace t, v\$datafile f where t.ts#=f.ts#
                union
                select name ts_name, 3 order_by, 'alter tablespace '||trim(name)||' end backup;'
        from v\$tablespace where name<>'TEMP'
                order by 1, 2;
                select 'spool off' from dual;
        spool off
        exit
EOF

        sed '/^SQL>/d' temp_hotbackup.sql|sed '/^ /d'>hotbackup_${SID}.sql
        rm temp_hotbackup.sql

        #Implement Datafile Hotbackup
        echo "$SID Copy Datafile Start at `date`"
        sqlplus "/as sysdba" <<EOF
        @hotbackup_${SID}.sql
        exit
EOF
        echo "${SID} Copy Datafile End at `date`"

}

# Main Program Start Here
HOME=/u01/usr/oracle; export HOME
EXEDIR=${HOME}/dba/hotbkup
LOGFILE=${EXEDIR}/ora_hotbackup_${SID}.log
ERRORLOG=${EXEDIR}/ora_hotbackup_${SID}.err

# To Check if the Correct SID Pass in
if [ "$SID" = "" ]; then
        print Invalid SID Pass In
        Usage
        exit 0
fi

# Variable Declaration Start Here
export ORACLE_SID=$SID
export ORACLE_HOME=$(dbhome $ORACLE_SID)
export PATH=$ORACLE_HOME/bin:$ORACLE_HOME/dbs:$PATH
export LD_LIBRARY_PATH=$ORACLE_HOME/lib

arch_dir=/u01/app/oracle/admin/${ORACLE_SID}/arch
back_dir=/backup/hotbackup/${ORACLE_SID}
arch_back_dir=/backup/hotbackup/arch_bak/${ORACLE_SID}
arch_retention=1

cd ${EXEDIR}

db_status=$(ps -aef|grep pmon_${ORACLE_SID}|grep -v grep)
if [ -z ${db_status} ]; then
        print DB for $ORACLE_SID is NOT Running!! >${ERRORLOG}
        print Cannot Performed Hot Backup Hotbackup Abort >> ${ERRORLOG}
        exit
fi

if [ -f ${LOGFILE} ]; then
        rm ${LOGFILE}
fi


print  Hotbackup Started at `date +%H:%M` >${LOGFILE}

# Hotbackup Starts Here
dbfbkup |tee -a ${LOGFILE}
paramnctlbkup|tee -a ${LOGFILE}
archbkup|tee -a ${LOGFILE}
#paramnctlbkup|tee -a ${LOGFILE}
print  Finished Backup DBF at `date +%H:%M` |tee -a ${LOGFILE}

/usr/bin/mailx -s "XXX DB($ORACLE_SID) Hot-Backup Status at `date` in `hostname` " $MAIL_RCV < ${LOGFILE}

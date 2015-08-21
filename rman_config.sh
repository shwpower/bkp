#!/bin/ksh

#########################################################################
# Revision History
#########################################################################
# Wei           18-Dec-12 Creation
#               Config RMAN backup base on instance name
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


export ORACLE_SID=${SID:?"ERROR! Usage: ${0##*/} -i [Oracle Sid] "}
USER=system
PASSWD=`/usr/local/bin/orapass ${USER}`
export ORACLE_HOME=`/usr/local/bin/dbhome ${ORACLE_SID}`

echo "RMAN Config for Instance - $ORACLE_SID"

rman target / nocatalog << EOF
        CONFIGURE CONTROLFILE AUTOBACKUP ON;
        CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '/backup/rman_bkp/$SID/cf_%F';
        CONFIGURE DEVICE TYPE DISK PARALLELISM 4;
        CONFIGURE CHANNEL DEVICE TYPE DISK FORMAT '/backup/rman_bkp/$SID/db_%d_S_%s_P_%p_T_%T' MAXPIECESIZE 16g;
EOF

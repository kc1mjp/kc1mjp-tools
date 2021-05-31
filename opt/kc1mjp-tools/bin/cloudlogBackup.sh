#!/bin/bash
#------------------------------------------------------------------------------
#
# Name:     cloudlogBackup.sh
# Author:   Michael J. Ford <michael@kc1mjp.us>
# Purpose:  Download cloudlog backup from server for backup and GridTracker
#
#------------------------------------------------------------------------------
#
# LastMod: 20210529 - Michael J. Ford <michael.ford@slashetc.us>
#     - created
#
# LastMod: 20210530 - Michael J. Ford <michael.ford@slashetc.us>
#     - added more reliable download check
#     - fixed case statement (still greasing the gears)
#     - added -C option for crontab use, updated crontab ask to use
#     - fixed case statement... again... still greasing....
#
#------------------------------------------------------------------------------
# --- Script Config
#------------------------------------------------------------------------------

   . /opt/kc1mjp-tools/functions/kc1mjp-common.fun
   configFile=cloudlogBackup.conf
   checkScriptConf ${configFile}
   . ${scriptConfDir}/${configFile}

   if [[ ${MYCALL} == 'MYCALL' ]]
   then
      echo "Please Configure ${scriptConfDir}/${configFile}"
      exit 1
   fi

   crontab=false
   while getopts :C
   do
      case ${opt} in
         C)    crontab=true
               ;;
         \?)   echo "Invalid option: -${OPTARG}"
               exit 88
               ;;
      esac
   done

#------------------------------------------------------------------------------
# --- Main Code
#------------------------------------------------------------------------------

   if ! checkInternet
   then
      ${useTls} && port=443 || port=80
      if ! nc -z -w2 ${cloudlogHost} ${port} &>/dev/null
      then
         echo "FATAL: No path to ${cloudlogHost}"
         exit 1
      fi
   fi

   if ${useTls}
   then
      cloudlogBackupUrl="https://${cloudlogHost}/${cloudlogBackupPath}"
   else
      cloudlogBackupUrl="http://${cloudlogHost}/${cloudlogBackupPath}"
   fi

   for backupFile in ${cloudlogFiles[*]}
   do
      wget --quiet ${cloudlogBackupUrl}/${backupFile} -o /tmp/cloudlog_${backupFile}
      if [[ ! -f /tmp/cloudlog_${backupFile} ]]
      then
         echo "ERROR: Failed to download ${backupFile}"
         exit 1
      fi

      md5New="$( md5sum /tmp/cloudlog_${backupFile} 2>/dev/null )"
      md5Old="$( md5sum ${destinationPath}/cloudlog_${backupFile} 2>/dev/null )"
      if [[ ${md5New} == "${md5Old}" ]]
      then
         echo "INFO: ${backupFile} exists"
      else
         cp /tmp/cloudlog_${backupFile} ${destinationPath}/cloudlog_${backupFile}
      fi
   done

   rm /tmp/cloudlog_${backupFile}

   if [[ ${crontab} != true ]]
   then
      echo -en "Enter hourly task into ${USER} crontab? y/N: "
      read answer junk
      case ${answer} in
         y|Y)  if ! crontab -l | grep -q cloudlogBackup.sh
               then
                  echo "0 * * * * /opt/kc1mjp-tools/bin/cloudlogBackup.sh -C &>/dev/null" | crontab -
               else
                  echo "INFO: Crontab Exists"
               fi ;;
         n|N)  echo "No Crontab Changed"  ;;
         *)    echo "ERR Invalid Input"   ;;
      esac
   fi

   echo "INFO: done"

   exit 0

#------------------------------------------------------------------------------
# --- End Script
#------------------------------------------------------------------------------

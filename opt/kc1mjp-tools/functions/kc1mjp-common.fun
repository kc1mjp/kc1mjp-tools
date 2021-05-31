#!/bin/bash
#------------------------------------------------------------------------------
#
# Name:     kc1mjp-common.fun
# Author:   Michael J. Ford <michael@kc1mjp.us>
# Purpose:  Collection of common functions used in the kc1mjp-tools package
#
#------------------------------------------------------------------------------
#
# LastMod: 20210529 - Michael J. Ford <michael.ford@slashetc.us>
#     - created
#
#------------------------------------------------------------------------------
# --- Functions
#------------------------------------------------------------------------------

checkScriptConf()
{
   scriptConfDir=${HOME}/.config/kc1mjp-tools
   scriptConfFile=${1}
   if [[ ! -d ${scriptConfDir} ]]
   then
      mkdir -p ${scriptConfDir}
      cp -p /opt/kc1mjp-tools/examples/${scriptConfFile} ${scriptConfDir}/
      echo "INFO: Please Configure: ${scriptConfDir}/${scriptConfFile}"
      exit 99
   else
      cp -p /opt/kc1mjp-tools/examples/${scriptConfFile} ${scriptConfDir}/
      if [[ $? != "0" ]]
      then
         echo "ERR: Missing/Invalid Configuration File [${scriptConfFile}]"
         exit 1
      else
         echo "INFO: Please Configure [${scriptConfDir}/${scriptConfFile}]"
         exit 1
      fi
   fi

   return 0
}

#--------------------------------------

checkInternet()
{
   checkHost="google.com"
   pubIp="$( getent ahosts "$checkHost" | awk '{print $1; exit}' )"
   activeInt="$( ip route get "${pubIp}" | grep -Po '(?<=(dev )).*(?= src| proto)' )"
   privIp="$( ip addr show ${activeInt} | awk '/inet /{ print $2 }' | cut -d'/' -f1 )"

   if echo "${activeInt}" | grep -q 'unreachable'
   then
      return 0
   else
      unset pubIp
      unset activeInt
      unset privIp
      return 1
   fi
}
#------------------------------------------------------------------------------
# --- End Functions
#------------------------------------------------------------------------------

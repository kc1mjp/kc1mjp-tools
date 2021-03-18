#!/bin/bash
#------------------------------------------------------------------------------
#
# Name   : createSerialNames.sh
# Author : Michael Ford <michael@kc1mjp.us>
# Purpose: Create UDEV rules for USB Serial devices to give persistant names
#
# Example Rule
# SUBSYSTEM=="tty", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", ATTRS{serial}=="A6008isP", SYMLINK+="arduino"
#
# Based on: http://hintshop.ludvig.co.nz/show/persistent-names-usb-serial-devices/
#
#------------------------------------------------------------------------------
#
# LastMod: 20210310 - Michael J. Ford <michael.ford@slashetc.us>
#     - created
#     - not fully functional yet, but works for adding devices
#
#------------------------------------------------------------------------------
# --- Script Config
#------------------------------------------------------------------------------

   scriptName="$( basename $0 )"

   udevRulesFile=/etc/udev/rules.d/73-serial-names.rules

   supportedDevices=(
      0403 # FTDI
      )

   [[ -f ~/.config/kc1mjp-tools/createSerialNames.conf ]] &&
      . ~/.config/kc1mjp-tools/createSerialNames.conf

#------------------------------------------------------------------------------
# --- Local Functions
#------------------------------------------------------------------------------

listDevices()
{
   deviceList="$(
      local cnt=1
      if [[ -f ${udevRulesFile} ]]
      then
         echo "Configured Devices in: ${udevRulesFile}"
         while IFS= read -r line
         do
            echo "${cnt}) ${line}"
            (( cnt ++ ))
         done < ${udevRulesFile}
      else
         echo " - No Configured Devices"
      fi

      echo -e "\nDetected USB Serial Devices"
      ttyUSBdevices="$( ls /dev/ttyUSB* )"
      if [[ -z ${ttyUSBdevices} ]]
      then
         echo " - No ttyUSBx devices found"
      else
         for ttyUSBdevice in ${ttyUSBdevices}
         do
            echo "${cnt}) ${ttyUSBdevice}$( deviceStatus ${ttyUSBdevice} )"
            (( cnt ++ ))
         done
      fi )"

   echo "${deviceList}"
}

#--------------------------------------

addDevice()
{
   if [[ -z ${device} ]]
   then
      listDevices

      echo -en "\nEnter Line Number Of Hardware Device to Add:" \
               "\n>> " ; read answer junk
      deviceToAdd=$( echo "${deviceList}" | grep "^${answer})" | awk '{ print $2 }' )

      if [[ -z ${deviceToAdd} ]]
      then
         echo "Missing/Invalid Device"
         exit 1
      else
         ttyUSBidVendor="$( udevadm info -a -n ${deviceToAdd}  | grep '{idVendor}' | head -n1 )"
         ttyUSBidProduct="$( udevadm info -a -n ${deviceToAdd}  | grep '{idProduct}' | head -n1 )"
         ttyUSBidSerial="$( udevadm info -a -n ${deviceToAdd}  | grep '{serial}' | head -n1 )"

         if [[ -f ${udevRulesFile} ]]
         then
            if grep -q "${ttyUSBidSerial}" ${udevRulesFile}
            then
               echo "FATAL: Serial [${ttyUSBidSerial}] Exists in Configuration [${udevRulesFile}]"
            fi
         fi

         echo -en "\nEnter Symlink Name: "
         read ttyUSBsymlink junk
         echo -en "\nAdding Device [${deviceToAdd}], With This Info:"  \
                  "\nidVendor:  ${ttyUSBidVendor}"       \
                  "\nidProduct: ${ttyUSBidProduct}"      \
                  "\nidSerial:  ${ttyUSBidSerial}"       \
                  "\n\nSymlink Name:  ${ttyUSBsymlink}"  \
                  "\n\nAccept and Write? (y/N) "
         read answer junk ; echo

         case ${answer} in
            y|Y)  echo "SUBSYSTEM==\"tty\", ${ttyUSBidVendor//[[:space:]]/}, "               \
                       "${ttyUSBidProduct//[[:space:]]/}, ${ttyUSBidSerial//[[:space:]]/}, " \
                       "SYMLINK+=\"${ttyUSBsymlink//[[:space:]]/}\"" | \
                       sudo tee -a ${udevRulesFile} > /dev/null ;;
            n|N)  echo "Lets BAIL!"    ;;
            *)    echo "Missing/Invalid Input"  ;;
         esac

         local tries=3
         until [[ ${tries} == 0 ]]
         do
            echo -en "\nWrote to [${udevRulesFile}], Please remove and reseat device to confirm." \
                     "Press <ENTER> when Complete..." ; read junk
            if [[ -f /dev/${ttyUSBsymlink} ]]
            then
               echo -e "\nDevice Configured! Now you may use [/dev/${ttyUSBsymlink}] to access this Device"
               exit 0
            else
               (( tries -- ))
            fi
         done

         echo -e "\nFailed to find [/dev/${ttyUSBsymlink}], something is broken..."
         exit 1
      fi

   else
      echo "Can't Add Device Directly Yet, sorry.... :("
      exit
   fi
}

#--------------------------------------

removeDevice()
{
   if [[ -z ${device} ]]
   then
      listDevices

      echo "Not Yet Implmented, Please remove by hand... sorry :("
   else
      echo "Can't Remove Device Directly Yet, sorry.... :("
   fi
}

#--------------------------------------

showHelp()
{
   echo "
${scriptName}                 User Commands

NAME
      ${scriptName} - create USB serial device links

SYNOPSIS
      ${scriptName} [OPTION]...

DESCRIPTION
      List or Create USB TTY Serial Device Symbolic Links

      Mandatory Option/Arguments, [*] denotes mutually exclusive
      -a    Add New Device to [${udevRulesFile}], *

      -d    [LINK|DEVICE]
            Specify Device or Link to add/remove

      -f    [FILE]
            Specify udev rules file

      -l    List Configured and Unconfigured ttyUSB devices *

      -r    Remove Configured ttyUSB device, *

NOTES
      ONLY FTDI chips are supported by this tool. If you would like to add
      your own list of supported devices, create the file:

         ~/.config/kc1mjp-tools/createSerialNames.conf

      with an array of 'user supported' USB Vendor ID's. This feature is
      used at your own risk. There is NO warranty or guarantee, expressed of
      implied. If it breaks, you get to keep both halfs.

AUTHOR
      Written by Michael J. Ford <KC1MJP>

REPORTING BUGS
      https://github.com/kc1mjp/kc1mjp-tools

COPYRIGHT
      Copyright (C) 2020 Free Software Foundation, Inc.  License GPLv3+: GNU
      GPL version 3 or later <https://gnu.org/licenses/gpl.html>.
      This is free software: you are free to change and redistribute it.  There
      is NO WARRANTY, to the extent permitted by law.
   " | less
}


#--------------------------------------

deviceStatus()
(
   local configuredLink="$( ls -l /dev/ | grep " -> $( basename ${1} )" | \
      awk '{ print $9 }' )"
   if [[ ! -z ${configuredLink} ]]
   then
      echo " | Configured Link: ${configuredLink}"
      return 0
   fi

   local ttyUSBidVendor="$( udevadm info -a -n ${1}  | grep '{idVendor}' | head -n1 )"
   local idVendor="$( echo ${ttyUSBidVendor} | awk -F'==' '{ print $2 }' )"
   for supportedId in ${supportedDevices[*]}
   do
      if [[ ${idVendor} == "${supportedId}" ]]
      then
         echo " | Supported Device"
         return 0
      fi
   done

   echo " | Unsupported Device for this Tool.."
   return 1
)

#------------------------------------------------------------------------------
# --- Main Code
#------------------------------------------------------------------------------

  if [[ -z ${1} ]]
   then
      showHelp
      exit 1
   fi

   # do not change/populate default variables
   device=
   listDevices=false
   addDevice=false
   removeDevice=false

   while getopts ":lard:f:" opt
   do
      case ${opt} in
         l) listDevices=true  ;;
         a) addDevice=true    ;;
         r) removeDevice=true ;;
         d) device=${OPTARG}  ;;
         f) echo "Not implemented yet"
            exit 1            ;;
        \?) echo "Invalid option: -${OPTARG}"
            exit 1            ;;
         :) echo "Option -${OPTARG} requires an argument"
            exit 1            ;;
      esac
   done

   if ${listDevices}
   then
      if [[ ${addDevice} ==  true ]] || [[ ${removeDevice} == true ]]
      then
         echo "Options -a and -r are incompatible with -l"
         exit 1
      else
         listDevices
      fi
   elif ${addDevice}
   then
      if [[ ${removeDevice} == true ]] || [[ ${listDevices} == true ]]
      then
         echo "Options -r and -l are incompatible with -a"
         exit 1
      else
         addDevice
      fi
   elif ${removeDevice}
   then
      if [[ ${addDevice} == true ]] ||  [[ ${listDevices} == true ]]
      then
         echo "Options -a and -l are incompatible with -r"
         exit 1
      else
         removeDevice
      fi
   fi

#------------------------------------------------------------------------------
# --- End Script
#------------------------------------------------------------------------------

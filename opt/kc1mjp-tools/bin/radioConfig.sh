#!/bin/bash
#------------------------------------------------------------------------------
#
# Name: radioConfig.sh
#
# Author: Michael J. Ford <michael@kc1mjp.us
#
# Purpose: Converts Master Radio Repeater/Frequency List to Radio Specific
#          CSV files for Chirp and Other Radio Programing Tools.
#
# -- Comma Seperations as follows in created CSV --
#        1. Location       10. DtcsPolarity
#        2. Name           11. Mode
#        3. Frequency      12. Tstep
#        4. Duplex         13. Skip
#        5. Offset         14. Comment
#        6. Tone           15. URCALL
#        7. rToneFreq      16. RPT1CALL
#        8. cToneFreq      17. RPT2CALL
#        9. DtcsCode       18. DVCODE
#
# -- Comma Seperations as follows from Source CSV or ODS --
#        1.  Call Sign     12. Scan
#        2.  Frequency     13. ST
#        3.  Duplex        14. Location
#        4.  Offset        15. Name
#        5.  Tone          16. Short Name
#        6.  rToneFreq     17. Status
#        7.  cToneFreq     18. Network/Comments
#        8.  TX CC         19. AllStarLink
#        9.  RX CC         20. EchoLink
#        10. Mode          21. NERD
#        11. Radio         22. Repeater Book
#
# Example .ods file: /opt/kc1mjp-tools/examples/radioConfig.example.ods
#
#------------------------------------------------------------------------------
#
# LastMod: 20210219 - Michael J. Ford <michael.ford@slashetc.us>
#     - created
#
# LastMod: 20210530 - Michael J. Ford <michael.ford@slashetc.us>
#     - fixed example config directory
#
#------------------------------------------------------------------------------
# --- Script Config
#------------------------------------------------------------------------------

   if [[ ! -d ${HOME}/.config/kc1mjp-tools ]]
   then
      mkdir -p ${HOME}/.config/kc1mjp-tools
      cp -p /opt/kc1mjp-tools/examples/radioConfig.conf ${HOME}/.config/kc1mjp-tools/
      echo "INFO: Please ${HOME}/.config/kc1mjp-tools/radioConfig.conf"
      exit 99
   elif [[ -f ${HOME}/.config/kc1mjp-tools/radioConfig.conf ]]
   then
      . ${HOME}/.config/kc1mjp-tools/radioConfig.conf
   else
      cp -p /opt/kc1mjp-tools/examples/radioConfig.conf ${HOME}/.config/kc1mjp-tools/
      if [[ $? != "0" ]]
      then
         echo "ERR: Missing/Invalid Configuration file [radioConfig.conf]"
         exit 1
      else
         echo "INFO: Please ${HOME}/.config/kc1mjp-tools/radioConfig.conf"
      fi
   fi

   . ${HOME}/.config/kc1mjp-tools/radioConfig.conf
   [[ ${myCall} == 'MYCALL' ]] && echo "WARN: Please Update Callsign"
   [[ ! -d ${outputFileDir} ]] && mkdir -p ${outputFileDir}

   echo ${*} | grep -q '\-\-debug' && set -x

#------------------------------------------------------------------------------
# --- Local Functions
#------------------------------------------------------------------------------

makeRadioConfig()
{
   setDefaultVars
   writeRadioConfig
   Location=${memoryStart}
   lineCount=1
   while read -r line
   do
      # Need to figure out section breaks here
      # Radio Vari in Source
      RadioProgram=$( echo ${line} | awk -F',' '{ print $11 }' )
      if [[ ${RadioProgram} == "X" ]]
      then
         callSign=$( echo ${line} | awk -F',' '{ print $1 }' )
         shortName=$( echo ${line} | awk -F',' '{ print $16 }' )
         if echo ${shortName} | egrep -iq 'FRS|GMRS|MURS|CB'
         then
            Name=${shortName}
         else
            case ${useName} in
               none)    Name=                   ;;
               short)   Name=${shortName:-${callSign}} ;;
               normal)  Name=$( echo ${line} | awk -F',' '{ print $15 }' )
                        Name=${Name:-${callSign}}  ;;
               *)       Name=                   ;;
            esac
         fi
         Frequency=$( echo ${line} | awk -F',' '{ print $2 }' )
         Duplex=$( echo ${line} | awk -F',' '{ print $3 }' )
         Offset=$( echo ${line} | awk -F',' '{ print $4 }' )
         Tone=$( echo ${line} | awk -F',' '{ print $5 }' )
         [[ ${Tone} =~ Cross ]] && Tone=Tone # overriding for now
         rToneFreq=$( echo ${line} | awk -F',' '{ print $6 }' )
         cToneFreq=
         DtcsCode=
         DtcsPolarity=
         Mode=$( echo ${line} | awk -F',' '{ print $10 }' )
         Tstep=
         Skip=$( echo ${line} | awk -F',' '{ print $12 }' )
         [[ -z ${Skip} ]] && Skip=S || Skip=
         network=$( echo ${line} | awk -F',' '{ print $18 }' )
         [[ ! -z ${network} ]] && network="${network} - "
         Comment="${network}$( echo ${line} | awk -F',' '{ print $14 }' ) $( echo ${line} | awk -F',' '{ print $13 }' )"
         URCALL=
         RPT1CALL=
         RPT2CALL=
         DVCODE=
         if [[ ${Location} -gt "${memoryMax}" ]]
         then
            echo "ERR: Memory FULL, last entry was Source Line [${lineCount}],"   \
                 " Frequency: [${Frequency}], CallSign: ${callSign}"
            return 99
            break
         fi
         if freqCompat && modeCompat
         then
            writeRadioConfig
            (( Location++ ))
         fi
      fi
      (( lineCount++ ))
   done < ${inputFile}
   echo "INFO: Created [${outputFileName}] Configuration File"
   return 0
}

#--------------------------------------

writeRadioConfig()
{
   [[ ! -f ${outputFileName} ]] && touch ${outputFileName}
   echo  "${Location},${Name},${Frequency},${Duplex},${Offset},${Tone},${rToneFreq:-88.5},${cToneFreq:-88.5},${DtcsCode:-023},${DtcsPolarity:-NN},${Mode},${Tstep:-5.00},${Skip},${Comment},${URCALL},${RPT1CALL},${RPT2CALL},${DVCODE}" | tee -a ${outputFileName}
}

#--------------------------------------

freqCompat()
{
   # Ensure Frequency Memory is Compatible with Radio,

   # Make sure frequency entered is an actual number
   re='^[+-]?[0-9]+([.][0-9]+)?$'
   if [[ ! -z ${Frequency} ]]
   then
      [[ ${Frequency} =~ ${re} ]] || return 1
   fi
   if [[ ! -z ${Offset} ]]
   then
      [[ ${Offset} =~ ${re} ]] || return 1
   fi
   if [[ ! -z ${rToneFreq} ]]
   then
      [[ ${rToneFreq} =~ ${re} ]] || return 1
   fi
   if [[ ! -z ${cToneFreq} ]]
   then
      [[ ${cToneFreq} =~ ${re} ]] || return 1
   fi

   # then pad with Zeros if needed
   testFreq=$( echo ${Frequency} | awk -F'.' '{ print $1 }' )
   if [[ ! -z ${vhfRange} ]]
   then
      if [[ ${testFreq} -gt ${vhfRange[0]} ]] && [[ ${testFreq} -lt ${vhfRange[1]} ]]
      then
         Frequency=$( convertFreq ${Frequency} 6 )
         Offset=$( convertFreq ${Offset} 6 )
         rToneFreq=$( convertFreq ${rToneFreq} 1 )
         cToneFreq=$( convertFreq ${cToneFreq} 1 )
         Tstep=$( convertFreq ${Tstep} 2 )
         return 0
      fi
      vhfSecondaryLo=${vhfRange[2]}
      vhfSecondaryHi=${vhfRange[3]}
      if [[ ! -z ${vhfSecondaryLo} ]] && [[ ! -z ${vhfSecondaryHi} ]]
      then
         if [[ ${testFreq} -gt ${vhfRange[2]} ]] && [[ ${testFreq} -lt ${vhfRange[3]} ]]
         then
            Frequency=$( convertFreq ${Frequency} 6 )
            Offset=$( convertFreq ${Offset} 6 )
            rToneFreq=$( convertFreq ${rToneFreq} 1 )
            cToneFreq=$( convertFreq ${cToneFreq} 1 )
            Tstep=$( convertFreq ${Tstep} 2 )
            return 0
         fi
      fi
   fi
   if [[ ! -z ${uhfRange} ]]
   then
      if [[ ${testFreq} -gt ${uhfRange[0]} ]] && [[ ${testFreq} -lt ${uhfRange[1]} ]]
      then
         Frequency=$( convertFreq ${Frequency} 6 )
         Offset=$( convertFreq ${Offset} 6 )
         rToneFreq=$( convertFreq ${rToneFreq} 1 )
         cToneFreq=$( convertFreq ${cToneFreq} 1 )
         Tstep=$( convertFreq ${Tstep} 2 )
         return 0
      fi
   fi
   return 1
}

#--------------------------------------

modeCompat()
{
   # Only allow compatible modes to be loaded into radios
   modeCompat=false
   for radioMode in ${radioModes[*]}
   do
      local compatModeCnt=$( echo ${radioModes[*]} | wc -w )
      until ${modeCompat}
      do
         [[ ${Mode} == ${radioMode} ]] && modeCompat=true || modeCompat=false
         (( compatModeCnt-- ))
         [[ ${compatModeCnt} == 0 ]] && break
      done
   done
   ${modeCompat} && return 0 || return 1
}

#--------------------------------------

convertFreq()
{
   # Pad Frequencies with trailing zeros
   [[ -z ${1} ]] && return
   [[ -z ${2} ]] && return

   local zeroPad=${2}
   local upper=$( echo ${1} | awk -F'.' '{ print $1 }' )
   local lower=$( echo ${1} | awk -F'.' '{ print $2 }' )
   local freqCount=$(( $( echo ${lower} | wc -m ) - 1 ))
   if [[ ${freqCount} -lt ${zeroPad} ]]
   then
      local fillMissing=$(( ${zeroPad} - ${freqCount} ))
      until [[ ${fillMissing} == "0" ]]
      do
         local lower=${lower}0
         (( fillMissing-- ))
      done
   fi
   echo "${upper}.${lower}"
}

#--------------------------------------

setDefaultVars()
{
   echo "INFO: Setting Default Variables"
   Location=Location
   Name=Name
   Frequency=Frequency
   Duplex=Duplex
   Offset=Offset
   Tone=Tone
   rToneFreq=rToneFreq
   cToneFreq=cToneFreq
   DtcsCode=DtcsCode
   DtcsPolarity=DtcsPolarity
   Mode=Mode
   Tstep=Tstep
   Skip=Skip
   Comment=Comment
   URCALL=URCALL
   RPT1CALL=RPT1CALL
   RPT2CALL=RPT2CALL
   DVCODE=DVCODE
}

#------------------------------------------------------------------------------
# --- Main Code
#------------------------------------------------------------------------------

   inputFile=${1}
   todaysDate=$( date "+%Y%m%d" )
   if [[ -z ${inputFile} ]]
   then
      echo "ERR: Missing File - ${inputFile}"
      exit 1
   fi

   fileExt=$( echo ${inputFile} | awk -F'.' '{ print $NF }' )
   case ${fileExt} in
      ods)  libreoffice --headless --convert-to csv ${inputFile} --outdir /tmp/
            inputFile=/tmp/$( basename ${inputFile} | sed 's/.ods/.csv/' )
            usingTmp=true  ;;
      csv)  usingTmp=false ;;
      *)    echo "ERR: Unsupported File Format [${fileExt}]"
            exit 1         ;;
   esac

   for radioName in ${radioList[*]}
   do
      echo
      echo "INFO: Creating Radio CSV Config for ${radioName}"
      outputFileName=${outputFileDir}/${myCall}_Radio-${radioName}_${todaysDate}.csv
      echo "INFO: Using File: ${outputFileName}"
      echo
      sleep 1
      [[ -f ${outputFileName} ]] && rm -f ${outputFileName}
      ${radioName}
      makeRadioConfig
      exitStat=$?
   done

   if ${usingTmp}
   then
      echo "INFO: Removing TMP file [${inputFile}]"
      rm ${inputFile}
   fi

   exit ${exitStat}

#------------------------------------------------------------------------------
# --- End Script
#------------------------------------------------------------------------------

#!/bin/sh 
TMP_IP_PREFIX='record_ip'
TMP_ANALYSE_PREFIX='analyse'
CRON="/etc/cron.d/ipcheck.cron"
BASEDIR=$(pwd)
IPT="/sbin/iptables"
record_ip()
{
   cd $BASEDIR
   echo "====== record_ip begin ========="
   TMP_IP_FILE="mktemp $BASEDIR/$TMP_IP_PREFIX.XXXXXXXX"
   IP_LIST=`$TMP_IP_FILE` 
   echo "CREATE IPCHEK TEMP IP FILE: $IP_LIST "

   #保留端口号
   netstat -ntu | awk '{print $5}' | egrep -o "[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}:[0-9]{0,9}" | sort | uniq | sort -nr >> $IP_LIST
} 
analyse_ip()
{
   cd $BASEDIR 
   echo "====== analyse_ip begin ========="
   TMP_ANALYSE_FILE="mktemp $BASEDIR/$TMP_ANALYSE_PREFIX.XXXXXXXX"
   ANALYSE_LIST=`$TMP_ANALYSE_FILE` 
   echo "CREATE IPCHEK TEMP ANALYSE_LIST FILE: $ANALYSE_LIST "

   #本地ip
   echo "====== local_ip ========="
   netstat -ntu | awk '{print $4}' | egrep -o "[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}" | sort | uniq | sort -nr > locat_ip.txt
   cat locat_ip.txt

   #合并所有ip信息
   for line in `ls | grep $TMP_IP_PREFIX` ;do
      cat  $line >> $ANALYSE_LIST  
   done
   echo "====== 1.ANALYSE_LIST ============" 
   cat $ANALYSE_LIST

   #去除相同端口号和IP都相同的数据
   echo "====== 2.analyseTemp.txt ============" 
   sort $ANALYSE_LIST | uniq > analyseTemp.txt
   cat analyseTemp.txt

   #解析ip 去掉端口号
   egrep -o "[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}" analyseTemp.txt  > $ANALYSE_LIST
   uniq -c $ANALYSE_LIST > analyseTemp.txt

   while read line ;do
     CURR_LINE_COUNT=$(echo $line | cut -d" " -f1)
     CURR_LINE_IP=$(echo $line | cut -d" " -f2)

     if grep -q "$CURR_LINE_IP" locat_ip.txt; then
         echo "!!!find local ip = $CURR_LINE_IP!!!"
         continue 
     fi

     if [ $CURR_LINE_COUNT -gt 1 ]; then
        echo "IP = $CURR_LINE_IP"
        #$IPT -I INPUT -s $CURR_LINE_IP -j DROP
     fi
   done < analyseTemp.txt

   rm -rf ${TMP_IP_PREFIX}*
   rm -rf ${ANALYSE_LIST}*
}

if [ $1 -eq 0 ]; then
   rm -f $CRON
   BASEDIR=$(pwd) 
   echo "CREATE IPCHEK TEMP BASEDIR FILE $BASEDIR"
   echo "SHELL=/bin/sh" > $CRON
   echo "* * * * * root $BASEDIR/ipcheck.sh 1 $BASEDIR > $BASEDIR/log.txt" >> $CRON
   service crond restart
elif [ $1 -eq 1 ]; then
   BASEDIR=$2
   echo "baseDir = $BASEDIR"
   for ((index=0 ; index<10 ; ++index))
   do
      sleep 5 
      record_ip
   done

   analyse_ip 
fi


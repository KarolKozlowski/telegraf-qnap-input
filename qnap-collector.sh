#!/bin/bash

# data field definition
#
# measurement,tag1=val1,tag2=val2 field1="v1",field2=1i 0000000000000000000
#
# Ref.: https://docs.influxdata.com/influxdb/v2/reference/syntax/line-protocol/

# telegraf config stanza:
#
# # Read data from QNAP system info
# [[inputs.exec]]
#   commands = ["/opt/telegraf-qnap-input/qnap-collector-prod.sh"]
#   timeout = "5s"
#   data_format = "influx"

timestamp=$(date +%s%N)

cputmp=$(getsysinfo cputmp | cut -d "/" -f1 | cut -d " " -f1) # get CPU temperature
cputmp_unit=$(getsysinfo cputmp | cut -d "/" -f1 | cut -d " " -f2) # get CPU temperature unit
echo "cpu tmp=${cputmp},tmp_unit=\"${cputmp_unit}\" ${timestamp}"

model=$(getsysinfo model) # get system model name
echo "model name=\"${model}\" ${timestamp}"

sysfields=""

systmp=$(getsysinfo systmp | cut -d "/" -f1 | cut -d " " -f1) # get system temperature
systmp_unit=$(getsysinfo systmp | cut -d "/" -f1 | cut -d " " -f2) # get system temperature

system_version=$(getcfg system version)

sysfannum=$(getsysinfo sysfannum) # get total system fan number
for fan_no in  $(seq 1 ${sysfannum}); do
  sysfan=$(getsysinfo sysfan ${fan_no} | cut -d " " -f1 ) # get system fan speed
  sysfields="${sysfields}fan_${fan_no}=${sysfan},"
done

echo "sys ${sysfields}tmp=${systmp},tmp_unit=\"${systmp_unit}\",version=\"${system_version}\" ${timestamp}"


hdnum=$(getsysinfo hdnum) # get total system SATA disk number
for disk_no in $(seq 1 ${hdnum}); do
  hdtmp=$(getsysinfo hdtmp ${disk_no}| cut -d "/" -f1 | cut -d " " -f1) # get SATA disk temperature
  hdtmp_unit=$(getsysinfo hdtmp ${disk_no}| cut -d "/" -f1 | cut -d " " -f2) # get SATA disk temperature
  hdstatus=$(getsysinfo hdstatus ${disk_no}) # get SATA disk status
  hdmodel=$(getsysinfo hdmodel ${disk_no}) # get SATA disk model
  hdcapacity=$(getsysinfo hdcapacity ${disk_no} | cut -d " " -f1) # get SATA disk capacity
  hdcapacity_unit=$(getsysinfo hdcapacity ${disk_no} | cut -d " " -f2) # get SATA disk capacity
  hdsmart=$(getsysinfo hdsmart ${disk_no}) # get SATA disk SMART summary

  if [ "${hdtmp}" == "--" ]; then
      # skip metrics if no disk
      continue
  fi

  echo "disk_${disk_no} tmp=${hdtmp},tmp_unit=\"${hdtmp_unit}\",status=${hdstatus},model=\"${hdmodel}\",capacity=${hdcapacity},capacity_unit=\"${hdcapacity_unit}\",smart=\"${hdsmart}\" ${timestamp}"
done


sysvolnum=$(getsysinfo sysvolnum) # get system volume number
for volume_no in $(seq 0 $((${sysvolnum}-1))); do
  vol_desc=$(getsysinfo vol_desc ${volume_no}) # get volume description
  vol_fs=$(getsysinfo vol_fs ${volume_no}) # get volume file system
  vol_totalsize=$(getsysinfo vol_totalsize ${volume_no} | cut -d " " -f1) # get volume total size
  vol_totalsize_unit=$(getsysinfo vol_totalsize ${volume_no} | cut -d " " -f2) # get volume total size
  vol_freesize=$(getsysinfo vol_freesize ${volume_no} | cut -d " " -f1) # get volume free size
  vol_freesize_unit=$(getsysinfo vol_freesize ${volume_no} | cut -d " " -f2) # get volume free size
  vol_status=$(getsysinfo vol_status ${volume_no}) # get volume status

  echo "volume_${volume_no} description=\"${vol_desc}\",fs=\"${vol_fs}\",total_size=${vol_totalsize},total_size_unit=\"${total_size_unit}\",free_size=${vol_freesize},free_size_unit=\"${vol_freesize_unit}\",status=\"${vol_status}\" ${timestamp}"
done

echo "${timestamp}" > /tmp/qnap-collector.timestamp

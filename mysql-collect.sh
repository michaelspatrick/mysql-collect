#!/bin/bash
#
# Script collects numerous metrics for MySQL and the Operating System.
# It then compresses all the data into a single archive file which can then
# be shared with Support.
#
# Written by Michael Patrick (michael.patrick@percona.com)
# Version 0.1 - June 6, 2023
#
# It is recommended to run the script as a privileged user (superuser,
# rds_superuser, etc), but it will run as any user.  You can safely ignore any
# warnings.
#
# Percona toolkit is highly encouraged to be installed and available.
# The script will attempt to download only the necessary tools from the Percona
# website.  If that too fails, it will continue gracefully, but some key metrics
# will be missing.  This can also be skipped by the --skip-downloads flag.
#
# This script also gathers either /var/log/syslog or /var/log/messages.
# It will collect the last 1,000 lines from the log by default.
#
# The pt-stalk, pt-summary, and pt-mysql-summary utilities will be run multi-threaded
# to collect the best metrics.
#
# Modify the MySQL connectivity section below and then you should be able
# to run the script.
#
# Use at your own risk!
#

VERSION=0.1

# ------------------------- Begin Configuation -------------------------

# Setup directory paths
TMPDIR=/tmp
BASEDIR=${TMPDIR}/metrics

# MySQL connectivity
MYSQL_USER="root"
MYSQL_PASSWORD="password"
MYSQL_PORT=3306

# Number of log entries to collect from messages or syslog
NUM_LOG_LINES=1000

# -------------------------- End Configuation --------------------------

# Trap ctrl-c
trap die SIGINT

# Declare some variables
DATETIME=`date +"%F_%H-%M-%S"`
HOSTNAME=`hostname`
DIRNAME="${HOSTNAME}_${DATETIME}"
CURRENTDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
PTDEST=${BASEDIR}/${DIRNAME}

# Setup colors
if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
  NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m'
else
  NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW=''
fi

# Display output messages with color
msg() {
  if [ "$COLOR" = true ]; then
    echo >&2 -e "${1-}"
  else
    echo >&2 "${1-}"
  fi
}

# Check that a command exists
exists() {
  command -v "$1" >/dev/null 2>&1 ;
}

# Get the script version number
version() {
  echo "Version ${VERSION}"
  exit
}

# Display a colored heading
heading() {
  msg "${PURPLE}${1}${NOFORMAT}"
}

# Cleanup temporary files and working directory
cleanup() {
  echo
  heading "Cleanup"
  echo -n "Deleting temporary files: "
  if [ -d "${PTDEST}" ]; then
    rm -rf ${PTDEST}
    msg "${GREEN}done${NOFORMAT}"
  else
    msg "${YELLOW}skipped${NOFORMAT}"
  fi
}

# Call this when script dies suddenly
die() {
  echo
  cleanup
  local msg=$1
  local code=${2-1} # default exit status 1
  msg "$msg"
  exit "$code"
}

declare -a pids
declare -a processes
waitPids() {
  while [ ${#pids[@]} -ne 0 ]; do
    local range=$(eval echo {0..$((${#pids[@]}-1))})
    local i
    for i in $range; do
      if ! kill -0 ${pids[$i]} 2> /dev/null; then
        TIMESTAMP=`date +"%Y_%m_%d_%H_%M_%S"`
        echo "${TIMESTAMP} Process, ${processes[$i]}, completed."
        unset processes[$i]
        unset pids[$i]
      fi
    done
    pids=("${pids[@]}") # Expunge nulls created by unset.
    processes=("${processes[@]}") # Expunge nulls created by unset.
    sleep 1
  done
  echo "Done!"
}

addPid() {
  local desc=$1
  local pid=$2
  echo "Starting ${desc} process with PID: ${pid}"
  pids=(${pids[@]} $pid)
  processes=(${processes[@]} $desc)
}

os_metrics() {
  # Collect OS information
  echo -n "Collecting uname: "
  uname -a > ${PTDEST}/uname_a.txt
  msg "${GREEN}done${NOFORMAT}"

  # Collect kernel information
  echo -n "Collecting dmesg: "
  if [ "$HAVE_SUDO" = true ] ; then
    sudo dmesg > ${PTDEST}/dmesg.txt
    sudo dmesg -T > ${PTDEST}/dmesg_t.txt
    msg "${GREEN}done${NOFORMAT}"
  else
    msg "${YELLOW}skipped (insufficient user privileges)${NOFORMAT}"
  fi

  # Copy messages (if exists)
  if [ -e /var/log/messages ]; then
    echo -n "Collecting /var/log/messages (up to ${NUM_LOG_LINES} lines): "
    tail -n ${NUM_LOG_LINES} /var/log/messages > ${PTDEST}/messages
    msg "${GREEN}done${NOFORMAT}"
  fi

  # Copy syslog (if exists)
  if [ -e /var/log/syslog ]; then
    echo -n "Collecting /var/log/syslog (up to ${NUM_LOG_LINES} lines): "
    tail -n ${NUM_LOG_LINES} /var/log/syslog > ${PTDEST}/syslog
    msg "${GREEN}done${NOFORMAT}"
  fi

  # Copy the journalctl output
  echo -n "Collecting journalctl: "
  journalctl -e > ${PTDEST}/journalctl.txt
  msg "${GREEN}done${NOFORMAT}"
}

legacy_os_metrics() {
  # Collect ps
  echo -n "Collecting ps: "
  ps auxf > ${PTDEST}/ps_auxf.txt
  msg "${GREEN}done${NOFORMAT}"

  # Collect top
  echo -n "Collecting top: "
  top -bn 1 > ${PTDEST}/top.txt
  msg "${GREEN}done${NOFORMAT}"

  # Ulimit
  echo -n "Collecting ulimit: "
  ulimit -a > ${PTDEST}/ulimit_a.txt
  msg "${GREEN}done${NOFORMAT}"

  # Swappiness
  echo -n "Collecting swappiness: "
  cat /proc/sys/vm/swappiness > ${PTDEST}/swappiness.txt
  msg "${GREEN}done${NOFORMAT}"

  # Numactl
  echo -n "Collecting numactl: "
  if exists numactl; then
    numactl --hardware > ${PTDEST}/numactl-hardware.txt
    msg "${GREEN}done${NOFORMAT}"
  else
    msg "${YELLOW}skipped${NOFORMAT}"
  fi

  # cpuinfo
  echo -n "Collecting cpuinfo: "
  cat /proc/cpuinfo > ${PTDEST}/cpuinfo.txt
  msg "${GREEN}done${NOFORMAT}"

  # mpstat
  echo -n "Collecting mpstat (60 sec): "
  if exists mpstat; then
    mpstat -A 1 60 > ${PTDEST}/mpstat.txt
    msg "${GREEN}done${NOFORMAT}"
  else
    msg "${YELLOW}skipped${NOFORMAT}"
  fi

  # meminfo
  echo -n "Collecting meminfo: "
  cat /proc/meminfo > ${PTDEST}/meminfo.txt
  msg "${GREEN}done${NOFORMAT}"

  # Memory
  echo -n "Collecting free/used memory: "
  free -m > ${PTDEST}/free_m.txt
  msg "${GREEN}done${NOFORMAT}"

  # vmstat
  echo -n "Collecting vmstat (60 sec): "
  if exists vmstat; then
    vmstat 1 60 > ${PTDEST}/vmstat.txt
    msg "${GREEN}done${NOFORMAT}"
  else
    msg "${YELLOW}skipped${NOFORMAT}"
  fi

  # Disk info
  echo -n "Collecting df: "
  if exists df; then
    df -k > ${PTDEST}/df_k.txt
    msg "${GREEN}done${NOFORMAT}"
  else
    msg "${YELLOW}skipped${NOFORMAT}"
  fi

  # Block devices
  echo -n "Collecting lsblk: "
  if exists lsblk; then
    lsblk -o KNAME,SCHED,SIZE,TYPE,ROTA > ${PTDEST}/lsblk.txt
    msg "${GREEN}done${NOFORMAT}"
  else
    msg "${YELLOW}skipped${NOFORMAT}"
  fi

  # lsblk
  echo -n "Collecting lsblk (all): "
  if exists lsblk; then
    lsblk --all > ${PTDEST}/lsblk-all.txt
    msg "${GREEN}done${NOFORMAT}"
  else
    msg "${YELLOW}skipped${NOFORMAT}"
  fi

  # smartctl
  echo -n "Collecting smartctl: "
  if exists smartctl; then
    if [ "$HAVE_SUDO" = true ] ; then
      smartctl --scan | awk '{print $1}' | while read device; do { smartctl --xall "${device}"; } done > "${PTDEST}/smartctl.txt"
      msg "${GREEN}done${NOFORMAT}"
    else
      msg "${YELLOW}skipped (insufficient user privileges)${NOFORMAT}"
    fi
  else
    msg "${YELLOW}skipped${NOFORMAT}"
  fi

  # multipath (if root)
  echo -n "Collecting multipath: "
  if exists multipath; then
    if [ "$HAVE_SUDO" = true ] ; then
      multipath -ll > "${PTDEST}/multipath_ll.txt"
      msg "${GREEN}done${NOFORMAT}"
    else
      msg "${YELLOW}skipped (insufficient user privileges)${NOFORMAT}"
    fi
  else
    msg "${YELLOW}skipped${NOFORMAT}"
  fi

  # lvdisplay (only for systems with LVM)
  echo -n "Collecting lvdisplay: "
  if exists lvdisplay; then
    if [ "$HAVE_SUDO" = true ] ; then
      sudo lvdisplay --all --maps > ${PTDEST}/lvdisplay-all-maps.txt
      msg "${GREEN}done${NOFORMAT}"
    else
      msg "${YELLOW}skipped (insufficient user privileges)${NOFORMAT}"
    fi
  else
    msg "${YELLOW}skipped${NOFORMAT}"
  fi

  # pvdisplay (only for systems with LVM)
  echo -n "Collecting pvdisplay: "
  if exists pvdisplay; then
    if [ "$HAVE_SUDO" = true ] ; then
      sudo pvdisplay --maps > ${PTDEST}/pvdisplay-maps.txt
      msg "${GREEN}done${NOFORMAT}"
    else
      msg "${YELLOW}skipped (insufficient user privileges)${NOFORMAT}"
    fi
  else
    msg "${YELLOW}skipped${NOFORMAT}"
  fi

  # pvs (only for systems with LVM)
  echo -n "Collecting pvs: "
  if exists pvs; then
    if [ "$HAVE_SUDO" = true ] ; then
      sudo pvs -v > ${PTDEST}/pvs_v.txt
      msg "${GREEN}done${NOFORMAT}"
    else
      msg "${YELLOW}skipped (insufficient user privileges)${NOFORMAT}"
    fi
  else
    msg "${YELLOW}skipped${NOFORMAT}"
  fi

  # vgdisplay (only for systems with LVM)
  echo -n "Collecting vgdisplay: "
  if exists vgdisplay; then
    if [ "$HAVE_SUDO" = true ] ; then
      sudo vgdisplay > ${PTDEST}/vgdisplay.txt
      msg "${GREEN}done${NOFORMAT}"
    else
      msg "${YELLOW}skipped (insufficient user privileges)${NOFORMAT}"
    fi
  else
    msg "${YELLOW}skipped${NOFORMAT}"
  fi

  # nfsstat for systems with NFS mounts
  echo -n "Collecting nfsstat: "
  if exists nfsstat; then
    nfsstat -m > ${PTDEST}/nfsstat_m.txt
    msg "${GREEN}done${NOFORMAT}"
  else
    msg "${YELLOW}skipped${NOFORMAT}"
  fi

  # iostat
  echo -n "Collecting iostat (60 sec): "
  if exists iostat; then
    iostat -dmx 1 60 > ${PTDEST}/iostat.txt
    msg "${GREEN}done${NOFORMAT}"
  else
    msg "${YELLOW}skipped${NOFORMAT}"
  fi

  # nfsiostat
  echo -n "Collecting nfsiostat (60 sec): "
  if exists nfsiostat; then
    nfsiostat 1 60 > ${PTDEST}/nfsiostat.txt
    msg "${GREEN}done${NOFORMAT}"
  else
    msg "${YELLOW}skipped${NOFORMAT}"
  fi

  # netstat
  echo -n "Collecting netstat: "
  if exists netstat; then
    netstat -s > ${PTDEST}/netstat_s.txt
    msg "${GREEN}done${NOFORMAT}"
  else
    msg "${YELLOW}skipped${NOFORMAT}"
  fi

  # sar
  echo -n "Collecting sar (60 sec): "
  if exists sar; then
    sar -n DEV 1 60 > ${PTDEST}/sar_dev.txt
    msg "${GREEN}done${NOFORMAT}"
  else
    msg "${YELLOW}skipped${NOFORMAT}"
  fi
}

legacy_mysql_metrics() {
  # Only used if Percona Toolkit is not installed
  echo -n "Collecting MySQL Processes (100 sec): "
  ${MYSQLADMIN_CONNECT_STR} -i10 -c10 proc > ${PTDEST}/mysql_procs.txt
  if [ $? -eq 0 ]; then
    msg "${GREEN}done${NOFORMAT}"
  else
    msg "${RED}failed${NOFORMAT}"
  fi

  echo -n "Collecting MySQL Extended Status (100 sec): "
  ${MYSQLADMIN_CONNECT_STR} -i10 -c10 ext > ${PTDEST}/mysql_ext.txt
  if [ $? -eq 0 ]; then
    msg "${GREEN}done${NOFORMAT}"
  else
    msg "${RED}failed${NOFORMAT}"
  fi

  echo -n "Collecting MySQL Variables: "
  ${MYSQL_CONNECT_STR} -e "SHOW GLOBAL VARIABLES" > ${PTDEST}/mysql_vars.txt
  if [ $? -eq 0 ]; then
    msg "${GREEN}done${NOFORMAT}"
  else
    msg "${RED}failed${NOFORMAT}"
  fi

  echo -n "Collecting MySQL InnoDB Status: "
  ${MYSQL_CONNECT_STR} -e "SHOW ENGINE INNODB STATUS\G" > ${PTDEST}/mysql_innodb_status.txt
  if [ $? -eq 0 ]; then
    msg "${GREEN}done${NOFORMAT}"
  else
    msg "${RED}failed${NOFORMAT}"
  fi
}

mysql_metrics() {
  # Check whether mysql client exists
  if exists mysql; then
    MYSQL_EXISTS=true

    if exists mysqladmin; then
      echo -n "MySQL is running: "
      #mysqladmin -u ${MYSQL_USER} -p${MYSQL_PASSWORD} -P ${MYSQL_PORT} ping >/dev/null 2>&1
      #${MYSQLADMIN_CONNECT_STR} ping >/dev/null 2>&1
      mysqladmin -h 127.0.0.1 -P ${MYSQL_PORT} ping >/dev/null 2>&1
      if [ $? -eq 0 ]; then
        msg "${GREEN}success${NOFORMAT}"
      else
        msg "${RED}Server not running!${NOFORMAT}"
        die
      fi
    fi

    echo -n "Connecting to MySQL: "
    ${MYSQL_CONNECT_STR} -e ";" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
      msg "${GREEN}success${NOFORMAT}"
    else
      msg "${RED}Cannot connect to database!${NOFORMAT}"
      die
    fi

    # Check for pt-mysql-summary and attempt download if not found
    if exists pt-mysql-summary; then
      PT_MYSQL_SUMMARY=`which pt-mysql-summary`
    else
      if [ -f "${TMPDIR}/pt-mysql-summary" ]; then
        PT_MYSQL_SUMMARY=${TMPDIR}/pt-mysql-summary
        chmod +x ${PT_MYSQL_SUMMARY}
      else
        if [ "${SKIP_DOWNLOADS}" = false ]; then
          curl -sL https://percona.com/get/pt-mysql-summary --output ${TMPDIR}/pt-mysql-summary
          if [ $? -eq 0 ]; then
            PT_MYSQL_SUMMARY="${TMPDIR}/pt-mysql-summary"
            chmod +x ${PT_MYSQL_SUMMARY}
          fi
        fi
      fi
    fi
  else
    MYSQL_EXISTS=false
    msg "${RED}Error: MySQL client not found!${NOFORMAT}"
  fi

  # Check for pt-stalk and attempt download if not found
  if exists pt-stalk; then
    PT_STALK=`which pt-stalk`
  else
    if [ -f "${TMPDIR}/pt-stalk" ]; then
      PT_STALK=${TMPDIR}/pt-stalk
      chmod +x ${PT_STALK}
    else
      if [ "${SKIP_DOWNLOADS}" = false ]; then
        curl -sL https://percona.com/get/pt-stalk --output ${TMPDIR}/pt-stalk
        if [ $? -eq 0 ]; then
          PT_STALK="${TMPDIR}/pt-stalk"
          chmod +x ${PT_STALK}
        fi
      fi
    fi
  fi

  # Get the Percona Toolkit version via pt-summary
  if exists pt-summary; then
    PT_EXISTS=true
    PT_SUMMARY=`which pt-summary`
    PT_VERSION_NUM=`${PT_SUMMARY} --version | egrep -o '[0-9]{1,}\.[0-9]{1,}'`
  else
    if [ -f "${TMPDIR}/pt-summary" ]; then
      PT_EXISTS=true
      PT_SUMMARY=${TMPDIR}/pt-summary
      chmod +x ${PT_SUMMARY}
      PT_VERSION_NUM=`${PT_SUMMARY} --version | egrep -o '[0-9]{1,}\.[0-9]{1,}'`
    else
      msg "${RED}Warning: Percona Toolkit not found.${NOFORMAT}"
      echo -n "Attempting to download the tools: "
      if [ "${SKIP_DOWNLOADS}" = false ]; then
        curl -sL https://percona.com/get/pt-summary --output ${TMPDIR}/pt-summary
        if [ $? -eq 0 ]; then
          PT_EXISTS=true
          PT_SUMMARY="${TMPDIR}/pt-summary"
          chmod +x ${PT_SUMMARY}
          PT_VERSION_NUM=`${PT_SUMMARY} --version | egrep -o '[0-9]{1,}\.[0-9]{1,}'`
          msg "${GREEN}done${NOFORMAT}"
        else
          PT_EXISTS=false
          PT_VERSION_NUM=""
          msg "${RED}failed${NOFORMAT}"
        fi
      else
        msg "${YELLOW}skipped (per user request)${NOFORMAT}"
      fi
    fi
  fi

  # Display the Percona Toolkit version number
  echo -n "Percona Toolkit Version: "
  if [ "$PT_EXISTS" = true ]; then
    msg "${GREEN}${PT_VERSION_NUM}${NOFORMAT}"
  else
    msg "${YELLOW}not found${NOFORMAT}"
  fi

  if [ "$PT_EXISTS" = true ]; then
    # Collect summary info using Percona Toolkit (if available)
    if ! exists $PT_SUMMARY; then
      msg "${ORANGE}warning - Percona Toolkit not found${NOFORMAT}"
    else
      ($PT_SUMMARY > ${PTDEST}/pt-summary.txt) &
      addPid "pt-summary" $!
    fi
  else
    msg "${RED}Warning: Please install the Percona Toolkit.${NOFORMAT}"
  fi

  if [ "$PT_EXISTS" = true ]; then
    # Collect MySQL summary info using Percona Toolkit (if available)
    if ! exists $PT_MYSQL_SUMMARY; then
      msg "${ORANGE}warning - Percona Toolkit not found${NOFORMAT}"
    else
      ($PT_MYSQL_SUMMARY > ${PTDEST}/pt-mysql-summary.txt) &
      addPid "pt-mysql-summary" $!
    fi
  else
    msg "${RED}Warning: Please install the Percona Toolkit.${NOFORMAT}"
  fi

  if [ "$PT_EXISTS" = true ]; then
    # Collect pt-stalk info using Percona Toolkit (if available)
    if ! exists $PT_STALK; then
      msg "${ORANGE}warning - Percona Toolkit not found${NOFORMAT}"
    else
      ($PT_STALK --no-stalk --iterations=2 --sleep=30 --log=${PTDEST}/pt-stalk.log --dest=${PTDEST} -- --user=${MYSQL_USER} --password=${MYSQL_PASSWORD}) &
      addPid "pt-stalk" $!
    fi
  else
    msg "${RED}Warning: Please install the Percona Toolkit.${NOFORMAT}"
  fi

  # Copy MySQL server configuration file
  if [ -r "/etc/my.cnf" ]; then
    echo -n "Copying server configuration file (/etc/my.cnf): "
    cp /etc/my.cnf ${PTDEST}/etc-my.cnf
    if [ $? -eq 0 ]; then
      msg "${GREEN}done${NOFORMAT}"
    else
      msg "${RED}failed${NOFORMAT}"
    fi
  fi

  if [ -r "/etc/mysql/my.cnf" ]; then
    echo -n "Copying server configuration file (/etc/mysql/my.cnf): "
    cp /etc/mysql/my.cnf ${PTDEST}/etc_mysql-my.cnf
    if [ $? -eq 0 ]; then
      msg "${GREEN}done${NOFORMAT}"
    else
      msg "${RED}failed${NOFORMAT}"
    fi
  fi

  if [ -r "/usr/local/etc/my.cnf" ]; then
    echo -n "Copying server configuration file (/usr/local/etc/my.cnf): "
    cp /usr/local/etc/my.cnf ${PTDEST}/usr_local_etc-my.cnf
    if [ $? -eq 0 ]; then
      msg "${GREEN}done${NOFORMAT}"
    else
      msg "${RED}failed${NOFORMAT}"
    fi
  fi

  if [ -r "/usr/local/mysql/etc/my.cnf" ]; then
    echo -n "Copying server configuration file (/usr/local/mysql/etc/my.cnf): "
    cp /usr/local/mysql/etc/my.cnf ${PTDEST}/usr_local_mysql_etc-my.cnf
    if [ $? -eq 0 ]; then
      msg "${GREEN}done${NOFORMAT}"
    else
      msg "${RED}failed${NOFORMAT}"
    fi
  fi

  # Get all MySQL PIDs
  echo -n "Collecting PIDs: "
  pgrep -x mysqld > "${PTDEST}/mysql_PIDs.txt"
  if [ $? -eq 0 ]; then
    msg "${GREEN}done${NOFORMAT}"
  else
    msg "${RED}failed${NOFORMAT}"
  fi
}

# Display script usage
usage() {
  cat << EOF # remove the space between << and EOF
Usage: $(basename "${BASH_SOURCE[0]}") [-u] [-p] [-P] [-v] [-V] [--help] [--no-color] [--skip-downloads]

Script collects various Operating System and MySQL diagnostic information and stores output in an archive file.

Available options:
--help            Print this help and exit
-p, --password    database password
-P, --port        database server port
-u, --user        database user name
-v, --verbose     Print script debug info
-V, --version     Print script version info
--no-color        Do not display colors
--skip-downloads  Do not attempt to download any Percona tools
EOF
  exit
}

# Parse command line options and parameters
parse_params() {
  # default values of variables set from params
  COLOR=true             # Whether or not to show colored output
  SKIP_DOWNLOADS=false   # Whether to skip attempts to download Percona toolkit and scripts

  while [[ $# -gt 0 ]]; do
    case $1 in
      --help)
        usage
        shift # past argument
        ;;
      -P|--port)
        MYSQL_PORT="$2"
        shift # past argument
        shift # past value
        ;;
      -u|--user)
        MYSQL_USER="$2"
        shift # past argument
        shift # past value
        ;;
      -p|--password)
        MYSQL_PASSWORD="$2"
        shift # past argument
        shift # past value
        ;;
      -v|--verbose)
        set -x
        shift # past argument
        ;;
      -V|--version)
        version
        shift # past argument
        ;;
      --no-color)
        COLOR=false
        shift # past argument
        ;;
      --skip-downloads)
        SKIP_DOWNLOADS=true
        shift # past argument
        ;;
      -*|--*)
        echo "Unknown option $1"
        exit 1
        ;;
      *)
        break
        die
        ;;
    esac
  done

  args=("$@")

  MYSQL_CONNECT_STR="mysql -h 127.0.0.1 -u${MYSQL_USER} -p${MYSQL_PASSWORD} -P${MYSQL_PORT}"
  MYSQLADMIN_CONNECT_STR="mysqladmin -h 127.0.0.1 -u${MYSQL_USER} -p${MYSQL_PASSWORD} -P${MYSQL_PORT}"

  return 0
}

parse_params "$@"

# If user doesn't want color displayed, reset the color values to empty strings
if [ "$COLOR" = false ]; then
  NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW=''
fi

# Check to ensure running as root
if [ "$EUID" -ne 0 ]; then
  HAVE_SUDO=false
else
  HAVE_SUDO=true
fi

heading "Collecting Metrics"

# Display script version
echo -n "MySQL Data Collection Version: "
msg "${GREEN}${VERSION}${NOFORMAT}"

# Display user permissions
echo -n "User permissions: "
if [ "$HAVE_SUDO" = true ] ; then
  msg "${GREEN}root${NOFORMAT}"
else
  msg "${YELLOW}unprivileged${NOFORMAT}"
fi

# Display temporary directory
echo -n "Creating temporary directory (${PTDEST}): "
mkdir -p ${PTDEST}
if [ $? -eq 0 ]; then
  msg "${GREEN}done${NOFORMAT}"
else
  msg "${RED}failed${NOFORMAT}"
  exit 1
fi

# Collect MySQL metrics
mysql_metrics

# Collect the OS metrics
os_metrics
if [ "$PT_EXISTS" = false ]; then
  legacy_mysql_metrics
  legacy_os_metrics
fi

# Wait for forked processes to complete
waitPids

echo
heading "Preparing Data Archive"

# Compress files for sending to Percona
cd ${BASEDIR}
chmod a+r ${DIRNAME} -R
echo "Compressing files:"
DEST_TGZ="$(dirname ${PTDEST})/${DIRNAME}.tar.gz"
tar czvf "${DEST_TGZ}" ${DIRNAME}

# Show compressed file location
echo -n "File saved to: "
msg "${CYAN}${DEST_TGZ}${NOFORMAT}"

# Do Cleanup
cleanup

# Exit clean
exit 0

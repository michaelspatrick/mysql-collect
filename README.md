# mysql-collect
Data gathering script for MySQL, written in Bash, which can be useful to diagnose issues.  The tool collects numerous Operating System metrics as well as MySQL metrics which can be analyzed.  These metrics are written to text files and then tar and gzipped into an archive file which is easy to send to an engineer or attach to a support ticket.  If using the Percona Toolkit, processes are multi-threaded so that OS metrics and database metrics are collected simultaneously.

It is best to run the script with elevated privileges in order to collect the most OS system metrics as some require root privileges.  If you cannot do this, the script will run just fine as an unprivileged user and will skip commands which require root.  

The output is colorized (unless you pass the "--no-color" option) for easy identification of successful commands versus warnings or errors.  If a command is skipped, it will be identified as such.  Executed commands are designated with either a "done" on success, or a warning message if it is unable to be successfully processed.  Time estimates for longer running commands are also shown.

This tool utilizes the [Percona Toolkit](https://www.percona.com/software/database-tools/percona-toolkit) for [pt-summary](https://docs.percona.com/percona-toolkit/pt-summary.html) and [pt-mysql-summary](https://docs.percona.com/percona-toolkit/pt-mysql-summary.html).  You can read more about other tools in the toolkit at [Percona Toolkit Documentation](https://docs.percona.com/percona-toolkit/index.html).  If you do not have these installed, the tool will attempt to download the required tools from the Percona Github and execute them unless you utilize the "--no-downloads" option.  These tools are read-only and make no changes to the server.  In the event you are not permitted to download tools and run them, you can always use the "--skip-downloads" option and nothing will be downloaded.

You can also save the Percona Toolkit scripts locally in the TMPDIR and the script will look for them there to execute.

## Help Output
```
mpatrick@localhost:~/mysql$ ./mysql-collect.sh --help
Usage: mysql-collect.sh [-u] [-p] [-P] [-v] [-V] [--help] [--no-color] [--skip-downloads]

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
```

## Use Cases
* Collecting metrics to send to a support team to help diagnose an issue.
* Collecting metrics to send to a DBA or engineer to review during an issue.
* Collecting metrics to store as a baseline of server performance.  If and when a problem arises, these metrics could be compared against the current state.

## Sample Output
```
mpatrick@localhost:~/mysql$ ./mysql-collect.sh
Collecting Metrics
MySQL Data Collection Version: 0.1
User permissions: unprivileged
Creating temporary directory (/tmp/metrics/localhost_2023-06-07_01-32-33): done
MySQL is running: success
Connecting to MySQL: success
Percona Toolkit Version: 3.5
Starting pt-summary process with PID: 350446
Starting pt-mysql-summary process with PID: 350447
Starting pt-stalk process with PID: 350448
Copying server configuration file (/etc/mysql/my.cnf): done
Collecting PIDs: done
Collecting uname: done
Collecting dmesg: skipped (insufficient user privileges)
Collecting /var/log/syslog (up to 1000 lines): done
Collecting journalctl: done
mysql: [Warning] Using a password on the command line interface can be insecure.
2023_06_07_01_32_36 Starting /usr/bin/pt-stalk --function=status --variable=Threads_running --threshold=25 --match= --cycles=0 --interval=1 --iterations=2 --run-time=30 --sleep=30 --dest=/tmp/metrics/localhost_2023-06-07_01-32-33 --prefix= --notify-by-email= --log=/tmp/metrics/localhost_2023-06-07_01-32-33/pt-stalk.log --pid=/var/run/pt-stalk.pid --plugin=
2023_06_07_01_32_36 Not running with root privileges!
2023_06_07_01_32_36 Not stalking; collect triggered immediately
2023_06_07_01_32_36 Collect 1 triggered
2023_06_07_01_32_36 Collect 1 PID 351267
2023_06_07_01_32_36 Collect 1 done
2023_06_07_01_32_36 Sleeping 30 seconds after collect
2023_06_07_01_32_41 Process, pt-summary, completed.
grep: /proc/887/environ: Permission denied
2023_06_07_01_32_48 Process, pt-mysql-summary, completed.
2023_06_07_01_33_06 Not stalking; collect triggered immediately
2023_06_07_01_33_06 Collect 2 triggered
2023_06_07_01_33_06 Collect 2 PID 353982
2023_06_07_01_33_06 Collect 2 done
2023_06_07_01_33_06 Waiting up to 90 seconds for subprocesses to finish...
2023_06_07_01_34_08 Exiting because no more iterations
2023_06_07_01_34_08 /usr/bin/pt-stalk exit status 0
2023_06_07_01_34_08 Process, pt-stalk, completed.
Done!

Preparing Data Archive
Compressing files:
localhost_2023-06-07_01-32-33/
localhost_2023-06-07_01-32-33/2023_06_07_01_32_36-top
localhost_2023-06-07_01-32-33/uname_a.txt
localhost_2023-06-07_01-32-33/2023_06_07_01_33_06-vmstat-overall
localhost_2023-06-07_01-32-33/2023_06_07_01_33_06-opentables2
localhost_2023-06-07_01-32-33/2023_06_07_01_32_36-innodbstatus2
localhost_2023-06-07_01-32-33/2023_06_07_01_33_06-mysqladmin
localhost_2023-06-07_01-32-33/2023_06_07_01_32_36-trigger
localhost_2023-06-07_01-32-33/etc_mysql-my.cnf
localhost_2023-06-07_01-32-33/2023_06_07_01_33_06-mpstat
localhost_2023-06-07_01-32-33/2023_06_07_01_33_06-netstat
localhost_2023-06-07_01-32-33/2023_06_07_01_32_36-ps-locks-transactions
localhost_2023-06-07_01-32-33/2023_06_07_01_32_36-iostat
localhost_2023-06-07_01-32-33/2023_06_07_01_33_06-iostat
localhost_2023-06-07_01-32-33/2023_06_07_01_33_06-innodbstatus1
localhost_2023-06-07_01-32-33/2023_06_07_01_32_36-output
localhost_2023-06-07_01-32-33/2023_06_07_01_32_36-opentables1
localhost_2023-06-07_01-32-33/2023_06_07_01_32_36-mysqladmin
localhost_2023-06-07_01-32-33/2023_06_07_01_33_06-vmstat
localhost_2023-06-07_01-32-33/2023_06_07_01_33_06-log_error
localhost_2023-06-07_01-32-33/2023_06_07_01_33_06-df
localhost_2023-06-07_01-32-33/syslog
localhost_2023-06-07_01-32-33/2023_06_07_01_32_36-df
localhost_2023-06-07_01-32-33/pt-summary.txt
localhost_2023-06-07_01-32-33/2023_06_07_01_32_36-hostname
localhost_2023-06-07_01-32-33/2023_06_07_01_33_06-iostat-overall
localhost_2023-06-07_01-32-33/2023_06_07_01_33_06-ps-locks-transactions
localhost_2023-06-07_01-32-33/2023_06_07_01_33_06-diskstats
localhost_2023-06-07_01-32-33/2023_06_07_01_33_06-top
localhost_2023-06-07_01-32-33/2023_06_07_01_32_36-iostat-overall
localhost_2023-06-07_01-32-33/2023_06_07_01_32_36-vmstat
localhost_2023-06-07_01-32-33/2023_06_07_01_33_06-procvmstat
localhost_2023-06-07_01-32-33/2023_06_07_01_32_36-slave-status
localhost_2023-06-07_01-32-33/2023_06_07_01_33_06-opentables1
localhost_2023-06-07_01-32-33/2023_06_07_01_33_06-output
localhost_2023-06-07_01-32-33/2023_06_07_01_33_06-mpstat-overall
localhost_2023-06-07_01-32-33/2023_06_07_01_32_36-innodbstatus1
localhost_2023-06-07_01-32-33/2023_06_07_01_32_36-netstat_s
localhost_2023-06-07_01-32-33/pt-mysql-summary.txt
localhost_2023-06-07_01-32-33/2023_06_07_01_32_36-variables
localhost_2023-06-07_01-32-33/2023_06_07_01_32_36-procvmstat
localhost_2023-06-07_01-32-33/2023_06_07_01_32_36-procstat
localhost_2023-06-07_01-32-33/2023_06_07_01_32_36-opentables2
localhost_2023-06-07_01-32-33/2023_06_07_01_32_36-log_error
localhost_2023-06-07_01-32-33/2023_06_07_01_33_06-meminfo
localhost_2023-06-07_01-32-33/2023_06_07_01_32_36-mpstat-overall
localhost_2023-06-07_01-32-33/2023_06_07_01_33_06-sysctl
localhost_2023-06-07_01-32-33/mysql_PIDs.txt
localhost_2023-06-07_01-32-33/2023_06_07_01_33_06-netstat_s
localhost_2023-06-07_01-32-33/2023_06_07_01_32_36-disk-space
localhost_2023-06-07_01-32-33/2023_06_07_01_32_36-sysctl
localhost_2023-06-07_01-32-33/2023_06_07_01_33_06-trigger
localhost_2023-06-07_01-32-33/2023_06_07_01_33_06-variables
localhost_2023-06-07_01-32-33/2023_06_07_01_33_06-ps
localhost_2023-06-07_01-32-33/2023_06_07_01_33_06-hostname
localhost_2023-06-07_01-32-33/2023_06_07_01_33_06-numastat
localhost_2023-06-07_01-32-33/2023_06_07_01_32_36-diskstats
localhost_2023-06-07_01-32-33/2023_06_07_01_32_36-meminfo
localhost_2023-06-07_01-32-33/2023_06_07_01_32_36-mpstat
localhost_2023-06-07_01-32-33/2023_06_07_01_32_36-vmstat-overall
localhost_2023-06-07_01-32-33/2023_06_07_01_32_36-interrupts
localhost_2023-06-07_01-32-33/2023_06_07_01_32_36-ps
localhost_2023-06-07_01-32-33/2023_06_07_01_32_36-numastat
localhost_2023-06-07_01-32-33/2023_06_07_01_32_36-processlist
localhost_2023-06-07_01-32-33/2023_06_07_01_33_06-processlist
localhost_2023-06-07_01-32-33/2023_06_07_01_33_06-slave-status
localhost_2023-06-07_01-32-33/journalctl.txt
localhost_2023-06-07_01-32-33/2023_06_07_01_33_06-innodbstatus2
localhost_2023-06-07_01-32-33/2023_06_07_01_33_06-interrupts
localhost_2023-06-07_01-32-33/2023_06_07_01_33_06-procstat
localhost_2023-06-07_01-32-33/2023_06_07_01_33_06-disk-space
localhost_2023-06-07_01-32-33/2023_06_07_01_32_36-netstat
File saved to: /tmp/metrics/localhost_2023-06-07_01-32-33.tar.gz

Cleanup
Deleting temporary files: done
```

## Getting Started
After downloading the script, you can edit the MySQL configuration variables at the top of the script.  If you want to change the location of the temporary directory or the number of lines of system logs collected, you can do so in the Configuration section as noted below:
```
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
```

## Licensing
The code is Open Source and can be used as you see fit.  There is no support given and you use the code at your own risk. 

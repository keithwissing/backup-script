#!/bin/bash

### Configuration ###

enable_growling=false

if [ $HOSTNAME == "MacBook.local" ]; then
	source=/Users/hitiek/
	dest_host=wendy
	dest_path=/media/fantom/macbook/
	exclude_file="${source}.rsync-exclude"
	keep_x_hourlys=24
elif [ $HOSTNAME == "wendy" ]; then
	source=/
	dest_host=wendy
	dest_path=/media/fantom/wendy/
	exclude_file=""
	keep_x_hourlys=8
elif [ $HOSTNAME == "lenovo" ]; then
	source=/
	dest_host=wendy
	dest_path=/media/fantom/lenovo/
	exclude_file="/root/rsync.exclude"
	keep_x_hourlys=8
else
	echo "ERROR: I don't have configuration for $HOSTNAME"
	exit
fi

### End Configuration ###

########################################################################

growl() {
	if [ "$enable_growling" == "true" ]; then
		gnexe=`which growlnotify`
		if [ -z "$gnexe" ]; then
			gnexe='/usr/local/bin/growlnotify'
		fi
		if [ -x "$gnexe" ]; then
			#echo which true
			$gnexe -n "backup.sh" -s -d $HOSTNAME -m "$*" -t macbook
		else
			#echo "No growlnotify found"
			ssh macbook /usr/local/bin/growlnotify -n "backup.sh" -s -d $HOSTNAME -m \"$*\" -t $HOSTNAME
		fi
	fi
}

########################################################################

echoAndRun () {
	echo --------------------
	echo $*
	if [ ${run} != 0 ] ; then	
		time $*
	else
		time sleep 1
	fi
	return $?
}

check_errs() {
	if [ $# -eq 2 ]; then
		# Function. Parameter 1 is the return code
		# Para. 2 is text to display on failure.
		if [ "${1}" -ne "0" ]; then
			echo "ERROR # ${1} : ${2}"
			# as a bonus, make our script exit with the right error code.
			exit ${1}
		fi
	elif [ $# -eq 3 ]; then
		if [ "${1}" -ne "0" -a "${1}" -ne "23" -a "${1}" -ne "24" ]; then
			echo "ERROR # ${1} : ${2}"
			exit ${1}
		fi
	else
		echo "ERROR: check_errs called with invalid parameters"
	fi
}

########################################################################
# http://www.franzone.com/2007/09/23/how-can-i-tell-if-my-bash-script-is-already-running/

scriptlock_aquire() {
	# Setup Environment
	PDIR=${0%`basename $0`}
	LCK_FILE=`basename $0`.lck
	#echo "Lock file is ${LCK_FILE}"

	# Am I Running
	if [ -f "${LCK_FILE}" ]; then
		# The file exists so read the PID to see if it is still running
		MYPID=`head -n 1 "${LCK_FILE}"`
		TEST_RUNNING=`ps -p ${MYPID} | grep ${MYPID}`

		if [ -z "${TEST_RUNNING}" ]; then
			# The process is not running, Echo current PID into lock file
			echo $$ > "${LCK_FILE}"
		else
			echo "`basename $0` is already running [${MYPID}]"
			exit 0
		fi
	else
		# echo "Not running"
		echo $$ > "${LCK_FILE}"
	fi
}

scriptlock_release() {
	rm -f "${LCK_FILE}"
}

########################################################################

remove_old_backups() {
# args: alphabetical(chronological) list of backup directories with dates.
	_RET=''

	local bl=($*)
	local last='x'
	#local today=`date "+%Y-%m-%d"`

	local tcount=${#bl[*]}

	local count=0
	for bi in ${bl[*]} ; do
		count=$(($count+1))
		if [[ $bi =~ $date_re ]]; then
			bd=${BASH_REMATCH[1]}
			local lim=$(($count+$keep_x_hourlys))
			local keep=0
			#if [ $bd == $last ]; keep=1
			#if [ $lim -le $tcount ]; keep=1
			#if [ $bd != $today ]; keep=1
			#if [[ ( $bd == $last ) -a ( $lim -le $tcount ) -a ( $bd != $today ) ]]; then
			if [ $bd == $last -a $lim -le $tcount ]; then
				#echo "$count) $bi - remove"
				_RET=("${_RET[*]}" $bi)
			else
				last=$bd
				#echo "$count) $bi - keep"
			fi
		else
			echo "ERROR: date not found in $bi"
		fi
	done
}

########################################################################

scriptlock_aquire

echo --------------------
now=`date "+%Y-%m-%d-%H%M%S"`
echo "Backup Starting at $now"
date
echo --------------------
growl "Backup Starting at $now"

run=1

TIMEFORMAT=$'\nreal\t%3lR'

date_re='([0-9]{4}-[0-9]{2}-[0-9]{2})-[0-9]{6}'
#date_hour_re='([0-9]{4}-[0-9]{2}-[0-9]{2})-([0-9]{2})[0-9]{4}'
#date_time_re='([0-9]{4}-[0-9]{2}-[0-9]{2})-([0-9]{6})'

blist=(`ssh $dest_host ls -d ${dest_path}backup.????-??-??-??????`)
if [ ${#blist[*]} -lt 1 ]; then
	echo "ERROR: could not get list of backups from destination host"
	exit
fi
last_in_list=${blist[${#blist[*]}-1]}
echo "Last backup:" $last_in_list

#last=`echo $last_in_list | grep -o [0-9]*-[0-9]*-[0-9]*-[0-9]*`
#echo "Date of last backup:" $last

if [[ $last_in_list =~ $date_re ]]; then
	last=${BASH_REMATCH[0]}
	link_dest_last="--link-dest=../backup.${last}"
	echo "Date of last backup:" $last
else
	link_dest_last=""
	echo "Date of last backup:" "None Found"
fi

remove_old_backups ${blist[*]}
removal_queue=(${_RET[*]})
#if [ ${#removal_queue[*]} -gt 0 ]; then echo "To be removed:" ${removal_queue[0]}; fi
[ ${#removal_queue[*]} -gt 0 ] && echo "To be removed:" ${removal_queue[0]}
#if [ ${#removal_queue[*]} -gt 1 ]; then echo "To be removed:" ${removal_queue[1]}; fi
test ${#removal_queue[*]} -gt 1 && echo "To be removed:" ${removal_queue[1]}

#run=0

if [ "${exclude_file}" != "" ]; then
	exclude_from="--exclude-from=${exclude_file}"
else
	exclude_from=""
fi

#echoAndRun ssh $dest_host cp -alf ${dest_path}backup.${last} ${dest_path}backup.${now}.inProgress
#check_errs $? "hard link copy failed"

# Sometimes files change or disappear during a sync. When this happens, rsync exits with a 24 instead of a 0.
echoAndRun rsync -aHhx --delete --delete-excluded --stats ${exclude_from} ${link_dest_last} ${source} ${dest_host}:${dest_path}backup.${now}.inProgress/
check_errs $? extra "rsync failed"
echoAndRun ssh $dest_host mv ${dest_path}backup.${now}.inProgress ${dest_path}backup.${now}
check_errs $? "final move failed"
echoAndRun ssh $dest_host "( cd ${dest_path} ; ln -sf backup.${now} Latest )"
check_errs $? "symlink to Latest failed"

if [ ${#removal_queue[*]} -gt 0 ]; then
	if [ ${#removal_queue[0]} -eq $((${#dest_path}+24)) ]; then
		growl "Removing expired backup ${removal_queue[0]}"
		echoAndRun ssh $dest_host rm -rf ${removal_queue[0]}
		check_errs $? "removing expired backup"
	else
		echo "Not removing ${removal_queue[0]} because of length"
	fi
fi

if [ ${#removal_queue[*]} -gt 1 ]; then
	if [ ${#removal_queue[1]} -eq $((${#dest_path}+24)) ]; then
		growl "Removing expired backup ${removal_queue[1]}"
		echoAndRun ssh $dest_host rm -rf ${removal_queue[1]}
		check_errs $? "removing expired backup"
	else
		echo "Not removing ${removal_queue[1]} because of length"
	fi
fi

echoAndRun ssh $dest_host "( cd ${dest_path} ; ls -ld backup.*.inProgress )"
echoAndRun ssh $dest_host "( cd ${dest_path} ; rm -rf backup.*.inProgress )"

echo --------------------
now=`date "+%Y-%m-%d-%H%M%S"`
echo "Backup Complete at $now"
date
echo --------------------
growl "Backup Complete at $now"

scriptlock_release

########################################################################


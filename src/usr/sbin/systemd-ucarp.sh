#!/bin/sh

usage () {

	debugmessage 3 "Entering function \"usage\"."  

	cat <<EOHELP

	usage: `basename $0` INTERFACE

Helper script to start the ucarp service for the given interface. Configuration can be 
defined globally and by interface under "$CONFDIR" and by interface under "$CONFDIR/if.d/INTERFACE".

When ucarp is started by this wrapper, you can keep the ucarp instance from being started across reboots by creating the file "$BLOCKFILE" in the config locations. But the prefered procedure is to use systemd and enable and disable the service unit, controlling this wrapper.

EOHELP

	debugmessage 3 "Leaving function \"usage\"."  
}



cleanup () {

	
	debugmessage 3 "Entering function \"cleanup\"."  
	debugmessage 3 "Leaving function \"cleanup\"."  


}


debugmessage () {

	# $1 = signed INT Debug level; negative values exit the script
	# $2 = Text of message

	# we need a minimum of 2 parameters
	if [ -z "$2" ] ;
	then
		echo "Error (func: debugmessage): No Message given, \$2 is empty."
		return 101
	fi

	# is firste parameter a signed integer?
	#expr "0" : '^[+-]\?[0-9]\+$'>/dev/null ; echo $?
	if ! expr "$1" : '^[+-]\?[0-9]\+$' >/dev/null
	then
		echo "Error: (funk: debugmessage): First parameter must be an signed integer!"
		return 102
	fi

	# send message
	if [ $1 -le $DEBUG ] ;
	then
		# send the message
		if [ $1 -ge 2  -o $1 -ge 0 ] ;
		then
			# message is considered error, send on stderr
			echo "$2" >&2
		else
			# informational messages are sent on stadout
			echo "$2"
		fi
	fi

	# if $1 negative then exit
	if [ $1 -lt 0 ] ;
	then
		# make sure no clutter is left
		cleanup

		# return value must be positive
		RETVAL=$(($1*-1))
		exit $RETVAL
	fi

}


setdefaults () {

	DEBUG=${DEBUG:-$DEBUGDEFAULT}
	debugmessage 3 "Entering function \"setdefaults\"."  

	CONFDIR=${CONFDIR:-"/etc/systemd-ucarp"}
	CONFNAME=${CONFNAME:-"ucarp.conf"}

	SCRIPTDIR="$CONFDIR/script.d"

	BLOCKFILE="noucarp"


	## ucarp parameters
	UCARP_INTERFACE=${UCARP_INTERFACE:-$IFNAME}
	UCARP_SRCIP=${UCARP_SRCIP:-""}
	UCARP_VHID=${UCARP_VHID:-???}
	UCARP_PASSWD=${UCARP_PASSWD:-""}
	UCARP_PASSFILE=${UCARP_PASSFILE:-""}
	UCARP_PREEMPT=${UCARP_PREEMPT:-0}
	UCARP_NEUTRAL=${UCARP_NEUTRAL:-0}
	UCARP_ADDR=${UCARP_ADDR:-""}
	UCARP_ADVBASE=${UCARP_ADVBASE:-1}
	UCARP_ADVSKEW=${UCARP_ADVSKEW:-0}
	UCARP_UPSCRIPT=${UCARP_UPSCRIPT:-"$SCRIPTDIR/vip-up"}
	UCARP_DOWNSCRIPT=${UCARP_DOWNSCRIPT:-"$SCRIPTDIR/vip-down"}
	UCARP_DEADRATIO=${UCARP_DEADRATIO:-3}
	UCARP_SHUTDOWN=${UCARP_SHUTDOWN:-0}
	UCARP_DAEMONIZE=${UCARP_DAEMONIZE:-0}
	UCARP_FACILITY=${UCARP_FACILITY:-""}
	UCARP_XPARAM=${UCARP_XPARAM:-""}
	UCARP_IGNOREIFSTATE=${UCARP_IGNOREIFSTATE:-0}
	UCARP_NOMCAST=${UCARP_X:-0}
	#$UCARP_X=${$UCARP_X:-???}
	#$UCARP_X=${$UCARP_X:-???}
	#$UCARP_X=${$UCARP_X:-???}
	#$UCARP_X=${$UCARP_X:-???}


	SECONDARY_IPS=${SECONDARY_IPS:-""}

	debugmessage 3 "Leaving function \"setdefaults\"."  
}



getconfig () {

	debugmessage 3 "Entering function \"getdefaults\"."  

	# read global config file
	CONFFILE_GLOB="$CONFDIR/$CONFNAME"
	if [ -r "$CONFFILE_GLOB" ] ;
	then
		. "$CONFFILE_GLOB"
	else
		[ ! -f "$CONFFILE_GLOB" ] && debugmessage 2 "Warning: no global config file \"$CONFFILE_GLOB\" found."
		[ -f "$CONFFILE_GLOB" -a ! -r "$CONFFILE_GLOB" ] && debugmessage -1 "Fatal: global config file \"$CONFFILE_GLOB\" not readable."
	
	fi


	# read interface config file
	CONFFILE_IF="$CONFDIR/if.d/$UCARP_INTERFACE/$CONFNAME"
	if [ -r "$CONFFILE_IF" ] ;
	then
		. "$CONFFILE_IF"
	else
		[ ! -f "$CONFFILE_IF" ] && debugmessage 2 "Warning: no interface specific config file \"$CONFFILE_IF\" found."
		[ -f "$CONFFILE_IF" -a ! -r "$CONFFILE_IF" ] && debugmessage -2 "Fatal: interface specific config file \"$CONFFILE_IF\" not readable."
	
	fi


	debugmessage 3 "Leaving function \"getdefaults\"."  
}



checkenvironment () {

	debugmessage 3 "Entering function \"checkenvironment\"."  

	# are we running with enough privileges?
	# do we have all required commands?
	# read configuration!
	# do we have an interface ready?
	if [ `ip address show "$UCARP_INTERFACE" >/dev/null 2>/dev/null ; echo $?` -ne 0 ] ;
	then
		# interface does not exist
		debugmessage -2 "Error: interface \"$UCARP_INTERFACE\" does not exist. Aborting"
	fi

	# is ucarp being blocked by block-file?

	# global block-file present?
	[ -x "$CONFFILE_GLOB/$BLOCKFILE" ] &&  debugmessage -99  "WARNING: Global Blockfile found. \"$CONFFILE_GLOB/$BLOCKFILE\" Not starting CARP." 
	[ -x "$CONFFILE_IF/$BLOCKFILE" ] &&  debugmessage -99  "WARNING: Interface Blockfile found. \"$CONFFILE_IF/$BLOCKFILE\" Not starting CARP." 

	debugmessage 3 "Leaving function \"checkenvironment\"."  
}



startucarp() {

	debugmessage 3 "Entering function \"startucarp\"."  


	# construct option line

	## Interface, BaseIP and VHID

	OPTLINE="--interface=$UCARP_INTERFACE --srcip=$UCARP_SRCIP --vhid=$UCARP_VHID" 

	## password
	if [ -n "$UCARP_PASSFILE" ] ;
	then
		# use passfile
		OPTLINE="$OPTLINE --passfile=$UCARP_PASSFILE"
	else
		# if set, use passsword from config
		[ -n "$UCARP_PASSWD" ] && OPTLINE="$OPTLINE --pass=$UCARP_PASSWD"
	fi

	## startup behaviour (preempt and neutral)

	[ -n "$UCARP_PREEMPT" -a ! "$UCARP_PREEMPT" = "0" ] && OPTLINE="$OPTLINE --preempt"
	[ -n "$UCARP_NEUTRAL" -a ! "$UCARP_NEUTRAL" = "0" ] && OPTLINE="$OPTLINE --neutral"


	## Virtual IP and Script setup

	OPTLINE="$OPTLINE --addr=$UCARP_ADDR --advbase=$UCARP_ADVBASE --advskew=$UCARP_ADVSKEW"
	OPTLINE="$OPTLINE --upscript=$UCARP_UPSCRIPT --downscript=$UCARP_DOWNSCRIPT"
	[ -n "$UCARP_XPARAM" ] && OPTLINE="$OPTLINE --xparam=\"$UCARP_XPARAM\""
	OPTLINE="$OPTLINE --deadratio=$UCARP_DEADRATIO"


	## 
	[ -n "$UCARP_SHUTDOWN" -a ! "$UCARP_SHUTDOWN" = "0" ] && OPTLINE="$OPTLINE --shutdown"
	[ -n "$UCARP_DAEMONIZE" -a ! "$UCARP_DAEMONIZE" = "0" ] && OPTLINE="$OPTLINE --daemonize"
	[ -n "$UCARP_FACILITY" ] && OPTLINE="$OPTLINE --facility=$UCARP_FACILITY"
	[ -n "$UCARP_IGNOREIFSTATE" -a ! "$UCARP_IGNOREIFSTATE" = "0" ] && OPTLINE="$OPTLINE --ignoreifstate"
	[ -n "$UCARP_NOMCAST" -a ! "$UCARP_NOMCAST" = "0" ] && OPTLINE="$OPTLINE --nomcast"

	debugmessage 5 "DEBUG: OPTLINE = \"$OPTLINE\""

	# run ucarp

	eval ucarp "$OPTLINE"
	RETVAL=$?
	[ $RETVAL -ne 0 ] && debugmessage $RETVAL "ucarp did exit with nonzero value $RETVAL."

	debugmessage 3 "Leaving function \"startucarp\"."  
}



skeleton () {

	debugmessage 3 "Entering function \"skeleton\"."  


	debugmessage 3 "Leaving function \"skeleton\"."  
}


# set Debug Variables as early as possible
DEBUGDEFAULT=2

# save positional parameters
IFNAME="$1"

setdefaults 

# show usage if requested
[ "$1" = "-h" ] && { usage; exit 0; }

# we only allow one parameter
[ -n "$2" ] && {  usage ; debugmessage -1 "ERROR: \"`basename $0`\" called with too many parameters. Aborting!"; }

# Development stuff
[ $DEBUG -gt 8 ] && set -xv

## here we go!


getconfig
checkenvironment
startucarp


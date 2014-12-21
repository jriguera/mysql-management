#!/usr/bin/env bash
#
# Create/Delete (a new empty DB following the name convention)
# (c) 2013 Jose Riguera <jose.riguera@springer.com>
# Licensed under GPLv3

# First we need to setup the Global variables, only if their default values
# are wrong for this script
DEBUG=0
EXEC_USER=root                 # normally must be 'itmaint' or $USER to avoid 
                               # changuing the user automaticaly with sudo.
# Other variables
PROGRAM=${PROGRAM:-$(basename $0)}
PROGRAM_DIR=$(cd $(dirname "$0"); pwd)
NAME=$PROGRAM
DESC="Create/Delete (a new empty DB following the name convention)"

# Program variables
ACTION='add'
FORCE=0

# Load the library and load the configuration file if it exists
REALPATH=$(readlink "$PROGRAM")
if [ ! -z "$REALPATH" ]; then
    REALPATH=$(dirname "$REALPATH")
    _COMMON="$REALPATH/_libs/_common.sh"
    _MYSQL_LIB="$REALPATH/_libs/_mysql.sh"
else
    _COMMON="$PROGRAM_DIR/_libs/_common.sh"
    _MYSQL_LIB="$PROGRAM_DIR/_libs/_mysql.sh"
fi
if ! [ -f "$_COMMON" ]; then
    msg="$(date "+%Y-%m-%d %T"): Error $_COMMON not found!"
    logger -s -p local0.err -t ${0} -- "$msg"
    exit 1
fi
. $_COMMON

# Load the mysql library
if ! [ -f "$_MYSQL_LIB" ]; then
    error_log "$_MYSQL_LIB not found!"
    exit 1
fi
. $_MYSQL_LIB


# Functions and procedures
# help
usage() {
    cat <<EOF
Usage:

    $PROGRAM  [-h | --help ] [-d | --debug] 
	      [-r | --remove] [-f | --force ] <gid> <platform> <dbname>

$DESC

Arguments:

   -h, --help         Show this message
   -d, --debug        Debug mode
   -r, --remove       Remove the DB
   -f, --force	      Force even with linked users

In order to be able to remove a DB, it must not have associated users.

EOF
}

# Add a DB
do_add() {
    local name="$1"
    local host=$2

    local rvalue

    echo_log "Creating new DB='$name' on $(hostname) ... "
    ${MYSQL} -h $host -e "CREATE DATABASE $name" | tee -a $PROGRAM_LOG
    rvalue=${PIPESTATUS[0]}
    if [ $rvalue -eq 0 ]; then
        echo_log "DB='$name' Created!"
    else
        error_log "DB='$name' ERROR, not created!"
    fi
    return $rvalue
}


# Add a DB
do_remove() {
    local name="$1"
    local host="$2"
    local force="$3"

    local rvalue
    local lines=0
    local tmpfile="/tmp/${PROGRAM}_$$_$(date '+%Y%m%d%H%M%S').out"

    echo_log "Removing DB='$name' on $(hostname) ... "
    if [ "$force" == "0" ]; then
	    debug_log "Getting all the users linked to DB=$name ..."
	    get_db_users $host "$name" > $tmpfile
	    rvalue=$?
	    if [ $rvalue != 0 ]; then
		error_log "getting list of DBs and users"
		return $rvalue
	    fi
	    lines=$(wc -l < $tmpfile)
    fi
    if [ "$lines" == 0 ]; then
        ${MYSQL} -h $host -e "DROP DATABASE $name" | tee -a $PROGRAM_LOG
        rvalue=${PIPESTATUS[0]}
    else
        error_log "Are you trying to remove a DB with associated users?"
        nl $tmpfile | tee -a $PROGRAM_LOG
        error_log "Sorry, you cannot do that from here. Please remove the users first"
        rvalue=$lines
    fi
    #rm -f $tmpfile
    if [ "$rvalue" == "0" ]; then
        echo_log "DB='$name' Removed!"
    else
        error_log "DB='$name' ERROR, not removed!"
    fi
    return $rvalue
}


do_action() {
    local action="$1"
    local force="$2"
    local gid="$3"
    local platform="$4"
    local dbname="$5"

    local rvalue
    local db_name="${gid}_${platform}_${dbname}"
    local host=$PROGRAM_HOST

    case "$action" in
        add)
            do_add "$db_name" "$host"
            rvalue=$?
        ;;
        del)
            do_remove "$db_name" "$host" "$force"
            rvalue=$?
        ;;
    esac
    return $rvalue
}


# Main Program
# Parse the input
OPTIND=1 # Reset is necessary if getopts was used previously in the script.
         # It is a good idea to make this local in a function.
while getopts "hdfr-:" optchar; do
    case "${optchar}" in
        -)
            # long options
            case "${OPTARG}" in
                help)
                    usage
                    exit 0
                ;;
                debug)
                    DEBUG=1
                ;;
                remove)
                    ACTION='del'
                ;;
                force)
                    FORCE=1
                ;;
                *)
                    die "Unknown arg: ${OPTARG}"
                ;;
            esac
        ;;
        h)
            usage
            exit 0
        ;;
        d)
            DEBUG=1
        ;;
        r)
            ACTION='del'
        ;;
        f)
            FORCE=1
        ;;
    esac
done
shift $((OPTIND-1)) # Shift off the options and optional --.
if [ $# -ne 3 ]; then
    usage
    exit 1
fi

GID=$1
PLATFORM=$2
DBNAME=$3

# Call the main function
do_action "$ACTION" "$FORCE" "$GID" "$PLATFORM" "$DBNAME"
exit $?

# EOF


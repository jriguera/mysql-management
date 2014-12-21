#!/usr/bin/env bash
#
# Create/Delete users and DBs linked together
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
DESC="Create/Delete users and DBs and manage grants of administrators"

# Program variables
MYSQL_DB_PROGRAM=''
MYSQL_USER_PROGRAM=''
MYSQL_GRANTS_PROGRAM=''
ACTION='add'
PASS=''
PRIVILEGES=''

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


# Program variables
# Functions and procedures
set +e

# help
usage() {
    cat <<EOF
Usage:

    $PROGRAM  [-h | --help ] [-d | --debug] [-r | --remove] [-p | --password "userpass"]
              <gid> <platform> <dbname> <user[@host]> ["PRIVILEGE1, PRIVILEGE2 ..."]

$DESC

Arguments:

   -h, --help         Show this message
   -d, --debug        Debug mode
   -r, --remove       Remove the user
   -p, --password     Password for the new user

If no privileges are passed to the program, it will create the user with <default>
privileges. If no host is especified in the user, all host will be allowed
to connet. If no password is specified, a new random pass will be created.

WARNING: This program DROP only app users, not revoke privileges of other users!

EOF
}

# Add 
do_add() {
    local gid="$1"
    local platform="$2"
    local dbname="$3"
    local dbuser="$4"    
    local userpass="$5"
    local privileges="$6"

    local rvalue
    local privs="$privileges"
    
    echo_log "Adding new DB objects:"
    [ -z "$privileges" ] && privs='<defaults>' 

    echo "* $MYSQL_DB_PROGRAM $gid $platform $dbname ..."
    $MYSQL_DB_PROGRAM "$gid" "$platform" "$dbname"
    rvalue=$?
    if [ $rvalue == 0 ]; then
	if [ -z "$userpass" ]; then
            echo "* $MYSQL_USER_PROGRAM $gid $platform $dbname $dbuser '$privs' ..."
            $MYSQL_USER_PROGRAM "$gid" "$platform" "$dbname" "$dbuser" "$privileges"
        else
	    echo "* $MYSQL_USER_PROGRAM -p **** $gid $platform $dbname $dbuser '$privs' ..."
            $MYSQL_USER_PROGRAM -p "$userpass" "$gid" "$platform" "$dbname" "$dbuser" "$privileges"
	fi
	rvalue=$?
    else
    	error_log "Something was wrong. To do Rollback: $MYSQL_DB_PROGRAM -r $gid $platform $dbname"
    fi
    if [ $rvalue == 0 ]; then
	echo "* $MYSQL_GRANTS_PROGRAM update ..."
	$MYSQL_GRANTS_PROGRAM update
	rvalue=$?
    fi
    return $rvalue
}


# Remove 
do_remove() {
    local gid="$1"
    local platform="$2"
    local dbname="$3"
    local dbuser="$4"    
    
    local rvalue
    local nextrvalue

    echo_log "Removing DB objects:"
    echo "* $MYSQL_USER_PROGRAM -r $gid $platform $dbname $dbuser ..."
    $MYSQL_USER_PROGRAM -r "$gid" "$platform" "$dbname" "$dbuser"
    rvalue=$?
    echo "* $MYSQL_DB_PROGRAM -r -f $gid $platform $dbname ..."
    $MYSQL_DB_PROGRAM -r -f "$gid" "$platform" "$dbname"
    nextrvalue=$?
    rvalue=$((rvalue + nextrvalue))
    echo "* $MYSQL_GRANTS_PROGRAM check ..."
    $MYSQL_GRANTS_PROGRAM check
    nextrvalue=$?
    rvalue=$((rvalue + nextrvalue))
    return $rvalue
}


do_action() {
    local action=$1
    local gid="$2"
    local platform="$3"
    local dbname="$4"
    local dbuser="$5"
    local userpass="$6"
    local privileges="$7"

    case "$action" in
        add)
            do_add "$gid" "$platform" "$dbname" "$dbuser" "$userpass" "$privileges"
            rvalue=$?
        ;;
        del)
            do_remove "$gid" "$platform" "$dbname" "$dbuser"
            rvalue=$?
        ;;
    esac
    return $rvalue
}


# Main Program
# Parse the input
OPTIND=1 # Reset is necessary if getopts was used previously in the script.  
         # It is a good idea to make this local in a function.
while getopts "hdrp:-:" optchar; do
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
                password)
                  eval PASS="\$${OPTIND}"
                  OPTIND=$(($OPTIND + 1))
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
        p)
            PASS=$OPTARG       
        ;;
    esac
done
shift $((OPTIND-1)) # Shift off the options and optional --.
if [ $# -lt 4 ] || [ $# -gt 5 ]; then
    usage
    exit 1
fi
GID=$1
PLATFORM=$2
DBNAME=$3
DBUSER=$4
[ $# -eq 5 ] && PRIVILEGES="$5"

# check the parameters
[ -x "$MYSQL_DB_PROGRAM" ] || die "Program variable MYSQL_DB_PROGRAM='$MYSQL_DB_PROGRAM' not correct!"
[ -x "$MYSQL_USER_PROGRAM" ] || die "Program variable MYSQL_USER_PROGRAM='$MYSQL_USER_PROGRAM' not correct!"
[ -x "$MYSQL_GRANTS_PROGRAM" ] || die "Program variable MYSQL_GRANTS_PROGRAM='$MYSQL_GRANTS_PROGRAM' not correct!"

# Call the main function
do_action "$ACTION" "$GID" "$PLATFORM" "$DBNAME" "$DBUSER" "$PASS" "$PRIVILEGES"
exit $?

# EOF


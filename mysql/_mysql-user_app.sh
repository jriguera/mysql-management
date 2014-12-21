#!/usr/bin/env bash
#
# Create/Delete an app user to access to a DB
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
DESC="Create/Delete an app user to access to a DB"

# Program variables
MYSQL_NEW_USER_DEFAULT_PRIVILEGES="ALL PRIVILEGES"
ACTION='add'

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
              [-r | --remove] [-p | --password "userpass"]
              <gid> <platform> <dbname[.table]> <user[@host]> ["PRIVILEGE1, PRIVILEGE2 ..."]

$DESC

Arguments:

   -h, --help         Show this message
   -d, --debug        Debug mode
   -r, --remove       Remove the user
   -p, --password     Password for the new user

If no privileges are passed to the program, it will create the user with grant
"ALL PRIVILEGES". If no host is especified in the user, all host will be allowed
to connet. If no password is specified, a new random pass will be created.

WARNING: This program DROP app users, not revoke privileges!

EOF
}

# Add user
do_add() {
    local dbname="$1"
    local dbtable="$2"
    local dbuser="$3"
    local dbhost="$4"    
    local userpass="$5"
    local privileges="$6"
    local host="$7"

    local rvalue

    echo_log "Creating '${dbuser}'@'${dbhost}' with $privileges over '${dbname}'.'${dbtable}' on $host ... "
    if ! exists_db $host "$dbname"; then
        error_log "DB '$dbname' does not exists! First you have to create it!"
        rvalue=1
        return $rvalue
    fi    
    if [ -z "$userpass" ]; then
        userpass=$(random_str 10)
        echo_log "The password is PASSWORD=$userpass"
    fi
    cat <<EOF | ${MYSQL} -h $host | tee -a $PROGRAM_LOG 
CREATE USER '${dbuser}'@'${dbhost}' IDENTIFIED BY '${userpass}';
GRANT ${privileges} ON ${dbname}.${dbtable} TO '${dbuser}'@'${dbhost}';
FLUSH PRIVILEGES;

EOF
    rvalue=${PIPESTATUS[1]}
    if [ $rvalue -eq 0 ]; then
        echo_log "User='${dbuser}'@'${dbhost}' Created!"
    else
        error_log "User='${dbuser}'@'${dbhost}' ERROR, not created!"
    fi
    return $rvalue
}


# Remove user
do_remove() {
    local dbname="$1"
    local dbtable="$2"
    local dbuser="$3"
    local dbhost="$4"
    local host="$5"
    
    local rvalue

    echo_log "Removing '${dbuser}'@'${dbhost}' ..."
    if ! exists_db $host "$dbname"; then
	echo_log "Warning: DB does not exist!"
    fi
    ${MYSQL} -h $host -e "DROP USER '${dbuser}'@'${dbhost}'; FLUSH PRIVILEGES;" | tee -a $PROGRAM_LOG
    rvalue=${PIPESTATUS[0]}
    if [ $rvalue -eq 0 ]; then
        echo_log "User='${dbuser}'@'${dbhost}' Deleted!"
    else
        error_log "User='${dbuser}'@'${dbhost}' ERROR! ... something was wrong ..."
    fi
    return $rvalue
}


do_action() {
    local action="$1"
    local gid="$2"
    local platform="$3"
    local dbname="$4"
    local dbuser="$5"
    local userpass="$6"
    local privileges="$7"

    local rvalue
    local db_name
    local db_user
    local db_host='%'
    local db_table='*'
    local host=$PROGRAM_HOST
    
    if [[ $dbuser =~ @ ]]; then
        db_host=$(echo $dbuser | cut -d'@' -f 2)
        dbuser=$(echo $dbuser | cut -d'@' -f 1)
    fi
    if [[ $dbname =~ \. ]]; then
        db_table=$(echo $dbname | cut -d'.' -f 2)
        dbname=$(echo $dbname | cut -d'.' -f 1)
    fi
    db_name="${gid}_${platform}_${dbname}"
    db_user="${gid}_${platform}_${dbuser}"

    if [ ${#db_user} -gt 16 ]; then
        error_log "length of user name '$db_user' is greather than 16 chars"
        rvalue=1
        return $rvalue
    fi
    case "$action" in
        add)
            do_add "$db_name" "$db_table" "$db_user" "$db_host" "$userpass" "$privileges" "$host"
            rvalue=$?
        ;;
        del)
            do_remove "$db_name" "$db_table" "$db_user" "$db_host" "$host"
            rvalue=$?
        ;;
    esac
    return $rvalue
}


# Main Program
PASS=''
PRIVILEGES=''
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
[ -z "$PRIVILEGES" ] && PRIVILEGES="$MYSQL_NEW_USER_DEFAULT_PRIVILEGES"

# Call the main function
do_action "$ACTION" "$GID" "$PLATFORM" "$DBNAME" "$DBUSER" "$PASS" "$PRIVILEGES"
exit $?

# EOF

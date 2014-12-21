#!/usr/bin/env bash
#
# Checks and updates the grants for especial users (no app users)
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
DESC="Checks and updates the grants for especial users (no app users) like administrators"

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
# MYSQL_GRANTS_CONF=""

# Functions and procedures
set +e

# help
usage() {
    cat <<EOF
Usage:

    $PROGRAM  [-h | --help ] [--debug] [-u | --user <user>] [-d | --db <db>] <check|update>

$DESC

Arguments:

   -h, --help         Show this message
   --debug            Debug mode

Actions for the service:

    check
    update

Default action is <check>

EOF
}


do_grant() {
    local host="$1"
    local dbname="$2"
    local dbtable="$3"
    local dbuser="$4"
    local dbhost="$5"
    local privileges="$6"
    local revoke="$7"
    
    local rvalue
    local tmpfile="/tmp/${PROGRAM}_$$_$(date '+%Y%m%d%H%M%S').newgrants"
    
    echo "Updating ... "
    echo "START TRANSACTION;" > $tmpfile
    if [ "$revoke" != "0" ]; then
        debug_log "REVOKE ALL PRIVILEGES ON ${dbname}.${dbtable} FROM '${dbuser}'@'${dbhost}';"    
	echo "REVOKE ALL PRIVILEGES ON ${dbname}.${dbtable} FROM '${dbuser}'@'${dbhost}';" >> $tmpfile
    fi
    debug_log "GRANT ${privileges} ON ${dbname}.${dbtable} TO '${dbuser}'@'${dbhost}';"
    echo "GRANT ${privileges} ON ${dbname}.${dbtable} TO '${dbuser}'@'${dbhost}';" >> $tmpfile
    echo "FLUSH PRIVILEGES;" >> $tmpfile
    echo "COMMIT;" >> $tmpfile
    cat $tmpfile >> $PROGRAM_LOG
    ${MYSQL} -h $host < $tmpfile | tee -a $PROGRAM_LOG 
    rvalue=${PIPESTATUS[0]}
    rm -f $tmpfile
    if [ $rvalue -eq 0 ]; then        
        echo_log "'${dbuser}@${dbhost}'='${privileges}'@'${dbname}.${dbtable}' -> Done!"
    else
        error_log "'${dbuser}@${dbhost}'='${privileges}'@'${dbname}.${dbtable}' -> Error, not updated!"
    fi
    return $rvalue
}


get_privs() {
    local host="$1"
    local dbuser="$2"
    local dbhost="$3"
    local db="$4"    
    local dbtables="\`${5}\`"  
      
    [ -z "$5" ] && dbtables='*'
    [ -z "$3" ] && dbhost='%'
    [ "$5" == "*" ] && dbtables='*'
    
    debug_log "SHOW GRANTS FOR '$dbuser'@'$dbhost';"
    ${MYSQL} -h $host --skip-column-names -B -e "SHOW GRANTS FOR '$dbuser'@'$dbhost';" | \
        sed -n -e "s/^GRANT \(.*\) ON \`\(${db}\)\`\.\(${dbtables}\) TO '\(.*\)'@'\([[:graph:]]*\)'$/\2:\3:\4@\5:\1/p" | \
        tr -d '`'
}


get_user() {
    local host="$1"
    local dbuser="$2"
    local dbhost="$3"
      
    [ -z "$3" ] && dbhost='%'
    
    debug_log "SELECT user,host FROM mysql.user where user='$dbuser' and host='$dbhost';"
    ${MYSQL} -h $host --skip-column-names -B -e "SELECT user,host FROM mysql.user where user='$dbuser' and host='$dbhost';"
}


diff_privs() {
    local fields="$1"
    local tmpfile="$2"

    local rvalue

    awk -vfields="$fields" '
    BEGIN {
        m=split(fields, inputfields, "[ \t]*:[ \t]*")
        if (m != 4) exit 1
        name=inputfields[1]
        table=inputfields[2]
        user=inputfields[3]
        m=split(inputfields[4], privs, "[ \t]*,[ \t]*")
        for (x in privs) {
            value=privs[x]
            sub(/[ \t\r\n]+$/, "", value)
            privs[x]=tolower(value)
        }
        FS="[ \t]*:[ \t]*"
        diffs=0
        k=1
        found=0
    }
    {
        if (name == $1 && table == $2 && user == $3) {
            n=split($4, dbprivs, "[ \t]*,[ \t]*");
            for (i=1; i<=n; i++) {
                dbprivs[i]=tolower(dbprivs[i])
                for (x in privs)
                    if (dbprivs[i] == privs[x]) {
                        delete dbprivs[i]
                        result[k++]=toupper(privs[x])
                        delete privs[x]
                        break
                    }
            }
            for (x in privs) {
                result[k++]=toupper(privs[x])
                diffs++
            }
            found=1
        }
    }
    END {
        if (found == 1) {
            printf("%d:", diffs)
            for (i=1; i<k; i++) {
                printf("%s", result[i])
                if (k-i == 1) printf("\n")
                else printf(", ")
            }
         } else {
            printf("-1:")
            for (i=1; i<=m; i++) {
                printf("%s", privs[i])
                if (i == m) printf("\n")
                else printf(", ")
            }            
         }
    }' "$tmpfile"
    rvalue=$?
    return $rvalue
}


do_task() {
    local action="$1"
    local dbname="$2"
    local dbuser="$3"
    local dbtable="$4"
    local privileges="$5"
    local host="$6"

    local dbhost
    local dbfields
    local db
    local grants
    local update
    local tmpfile="/tmp/${PROGRAM}_$$_$(date '+%Y%m%d%H%M%S').grants"
    local rvalue=0
    local userinfo
    local dbs
    local revoke
    local errors=0

    [ -z "$privileges" ] && privileges="$MYSQL_NEW_USER_DEFAULT_PRIVILEGES"
    [ -z "$dbtable" ] && dbtable="*"
    if [[ $dbuser =~ @ ]]; then
        dbhost=$(echo $dbuser | cut -d'@' -f 2)
        dbuser=$(echo $dbuser | cut -d'@' -f 1)
    else
        dbhost='%'
    fi

    dbs=$(get_expr_dbs "$host" "$dbname")
    if [ -z "$dbs" ]; then
        error_log "I have not found DBs by '$dbname'"
        return $rvalue
    fi    
    for db in $dbs ; do
        echon_log "Checking privileges of '$dbuser@$dbhost' on '${db}.${dbtable}' : "
        userinfo=$(get_user "$host" "$dbuser" "$dbhost")
        if [ -z "$userinfo" ]; then
            echo "Failed!"
            error_log "User '$dbuser@$dbhost' not exists on the DB server! You have to create it first."
            continue
        fi
        get_privs "$host" "$dbuser" "$dbhost" "$db" "$dbtable" > $tmpfile
        revoke=$(wc -l < $tmpfile)
        dbfields="$db:$dbtable:$dbuser@$dbhost:$privileges"
        grants=$(diff_privs "$dbfields" $tmpfile)
        rvalue=$?
        if [ $rvalue == 0 ]; then
            update=$(echo "$grants" | cut -d':' -f 1)            
            if [ "$action" == "update" ]; then
                grants=$(echo "$grants" | cut -d':' -f 2)
                if [ "$update" == "0" ]; then
                    echo "Ok!"
                    debug_log "Update not needed ($grants)"
                else                
                    do_grant "$host" "$db" "$dbtable" "$dbuser" "$dbhost" "$grants" $revoke
                    [ $?  == 0 ] && rvalue=$((rvalue + 1)) || errors=$((errors + 1))
                fi
            else
                if [ "$update" != "0" ]; then
                    echo "Failed!"
                    rvalue=$((rvalue + 1))
                else
                    echo "OK!"
                fi
            fi
        else
            error_log "Procesing entry!"
            errors=$((errors + 1))
        fi
    done
    rm -f $tmpfile
    return $rvalue
}


# process the file
do_action() {
    local action="$1"
    local database="$2"
    local user="$3"

    local rvalue=0
    local rc
    local line
    local saveifs=$IFS
    local fdb
    local fdbtable
    local fdbuser
    local fdbprivs
    local host=$PROGRAM_HOST

    [ -z "$database" ] && database=".*" || database="^$database\$"
    [ -z "$user" ] && user=".*" || user="^$user\$"

    echo_log "Procesing grants file '$MYSQL_GRANTS_CONF' ..."
    #IFS=$(echo -en "\n\b")
    while IFS= read line; do
        echo $line | grep -q -e "^\([^#]\)" || continue
    
        fdb=$(echo "$line" | cut -d':' -f 1 | tr -d ' ')
        fdbtable=$(echo "$line" | cut -d':' -f 2 | tr -d ' ')
        fdbuser=$(echo "$line" | cut -d':' -f 3 | tr -d ' ')
        fdbprivs=$(echo "$line" | cut -d':' -f 4)
        if [ $?  != 0 ]; then
            error_log "Error procesing entry! (Maybe '$tmpfile' is not well formed!)"
            continue
        fi
        echo $fdb | grep -q -e "$database" || continue
        echo $fdbuser | grep -q -e "$user" || continue

        do_task "$action" "$fdb" "$fdbuser" "$fdbtable" "$fdbprivs" "$host"
        rc=$?
        [ $rc  != 0 ] && rvalue=$((rvalue + rc))
    done < $MYSQL_GRANTS_CONF
    IFS=$saveifs
    echo_log "counter=$rvalue"
    return $rvalue
}


# Main Program
# Parse the input
DATABASE=''
USER=''
OPTIND=1 # Reset is necessary if getopts was used previously in the script.
         # It is a good idea to make this local in a function.
while getopts "hd:u:-:" optchar; do
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
                db)
                  eval DATABASE="\$${OPTIND}"
                  OPTIND=$(($OPTIND + 1))
                ;;
                user)
                  eval USER="\$${OPTIND}"
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
            DATABASE=$OPTARG
        ;;
        u)
            USER=$OPTARG
        ;;
    esac
done
shift $((OPTIND-1)) # Shift off the options and optional --.

# Parse the rest of the options
ACTION='check'
while [ $# -gt 0 ]; do
    case "$1" in
        check|CHECK)
            ACTION="check"
        ;;
        update|UPDATE)
            ACTION="update"
        ;;
        *) 
            die "Unknown arg: ${1}"
        ;;
    esac
    shift
done

[ -r "$MYSQL_GRANTS_CONF" ] || die "Configuration file for grants '$MYSQL_GRANTS_CONF' not found!"

# Call the main function
do_action "$ACTION" "$DATABASE" "$USER"
exit $?

# EOF

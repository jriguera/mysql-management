#!/usr/bin/env bash
#
# Script with common procedures and funtions for shell programming 
# (c) 2013 Jose Riguera <jose.riguera@springer.com>
# Licensed under GPLv3

# LOAD with:
# _MYSQL_LIB="$PROGRAM_DIR/_mysql.sh"
# if ! [ -f "$_MYSQL_LIB" ]; then
#     msg="$(date '+%Y-%m-%d %T'): Error $_MYSQL_LIB not found!"
#     logger -s -p local0.err -t ${PROGRAM} -- "$msg"
#     exit 1
# fi
# . $_MYSQL_LIB

# Global Variables
MYSQL="mysql"
PT_SHOW_GRANTS="pt-show-grants"


# Get all dbs
get_all_dbs() {
    local host="$1"
    
    local rvalue

    $MYSQL -h $host --skip-column-names -B -e 'SHOW DATABASES;' | grep -v -E '(mysql|information_schema|performance_schema|ps_helper)'
    rvalue=${PIPESTATUS[0]}
    return $rvalue
}


# get a list of users linked to a db
get_db_users() {
    local host="$1"
    local db="$2"
    local tables="\`${3}\`"  
      
    local rvalue
    [ -z "$3" ] && tables='*'
    
    $PT_SHOW_GRANTS -h $host | sed -n -e "s/^GRANT \(.*\) ON \`\(${db}\)\`\.\(${tables}\) TO '\(.*\)'@'\([[:graph:]]*\)';$/\2:\3:\4@\5:\1/p" | tr -d '`'
    rvalue=${PIPESTATUS[0]}
    return $rvalue
}


# get a dbs by regex on the name
get_expr_dbs() {
    local host="$1"
    local expr="$2"

    local rvalue
    
    get_all_dbs $host | grep -E "$expr"
    rvalue=${PIPESTATUS[0]}
    return $rvalue   
}


# get all tables from a DB
get_tables() {
    local host="$1"
    local database="$2"
    
    $MYSQL -h $host --skip-column-names -B -e "SHOW TABLES" $database
    return $?
}


# checks if a DB exists
exists_db() {
    local host="$1"
    local db="$2"

    local rvalue
    
    get_all_dbs $host | grep -q -e "^$db\$"
    rvalue=$?
    return $rvalue  
}

# END

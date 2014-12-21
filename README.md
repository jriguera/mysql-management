mysql-management
================

Scripts to manage DBs, users and grants on mysql databases

About these scripts
===================

The script works by reading a configuration file with some variables. You can pass
the configuration file as an argument (`-c`), but the script is able to read
it automatically if one exists with the same name as the program (except the suffix).

So, by creating a links to the script and multiple configuration files with
the same name (only changing the sufix `.sh` into `.conf`) and using different 
variables, is possible to backup different mysql instances.

The scripts log almost everything on _/var/log/scripts_ and also includes
a copy of this logfile within the output tar file.

All the scripts need to run with root privileges (because of the mysql client 
configuration).

Those scripts define a name convention for the users and DBs, by using three 
mandatory components, a grouping identifier, a group specific customizable 
format component:

```
<named object> = <gid>_<platform>_<name>
```

Managing all together (DBs and users): mysql-manage.sh
======================================================

```
# ./mysql-manage.sh
Usage:

    mysql-manage.sh  [-h | --help ] [-d | --debug] [-r | --remove] [-p | --password "userpass"]
              <gid> <platform> <dbname> <user[@host]> ["PRIVILEGE1, PRIVILEGE2 ..."]

Create/Delete users and DBs and manage grants of administrators

Arguments:

   -h, --help         Show this message
   -d, --debug        Debug mode
   -r, --remove       Remove the user
   -p, --password     Password for the new user

If no privileges are passed to the program, it will create the user with <default>
privileges. If no host is especified in the user, all host will be allowed
to connet. If no password is specified, a new random pass will be created.

WARNING: This program DROP only app users, not revoke privileges of other users!
```

For example, to create a new DB new database _hola_ with a user _user_, 
you have to pass the _gid_, and the project _plat_ :

```
# ./mysql-manage.sh test plat hola user
--mysql-manage.sh 2013-10-04 17:21:05: Adding new DB objects:
* mysql-db.sh test plat hola ...
--mysql-db.sh 2013-10-04 17:21:05: Creating new DB='test_plat_hola' on spr-dev-mysql-01 ... 
--mysql-db.sh 2013-10-04 17:21:06: DB='test_plat_hola' Created!
* mysql-user_app.sh test plat hola user '<defaults>' ...
--mysql-user_app.sh 2013-10-04 17:21:06: Creating 'test_plat_user'@'%' with ALL PRIVILEGES over 'test_plat_hola'.'*' on mysql-01 ... 
--mysql-user_app.sh 2013-10-04 17:21:14: The password is PASSWORD=9AYZXfWICO
--mysql-user_app.sh 2013-10-04 17:21:15: User='test_plat_user'@'%' Created!
* mysql-user_grants.sh update ...
--mysql-user_grants.sh 2013-10-04 17:21:15: Procesing grants file 'mysql-grants.conf' ...
--mysql-user_grants.sh 2013-10-04 17:21:16: Checking privileges of 'jriguera@%' on 'test_jose_hola.*' : Ok!
--mysql-user_grants.sh 2013-10-04 17:21:16: Checking privileges of 'jriguera@%' on 'test_plat_hola.*' : Updating ... 
--mysql-user_grants.sh 2013-10-04 17:21:16: 'jriguera@%'='all privileges'@'test_plat_hola.*' -> Done!
--mysql-user_grants.sh 2013-10-04 17:21:16: Checking privileges of 'jriguera@%' on 'test_prueba_hoy.*' : Ok!
--mysql-user_grants.sh 2013-10-04 17:21:16: Checking privileges of 'jriguera@%' on 'test_riguera_hola.*' : Ok!
--mysql-user_grants.sh 2013-10-04 17:21:16: Checking privileges of 'jriguera@%' on 'test_test_db.*' : Ok!
--mysql-user_grants.sh 2013-10-04 17:21:17: Checking privileges of 'jriguera@%' on 'test_ultimo1_hoy.*' : Ok!
--mysql-user_grants.sh 2013-10-04 17:21:17: Checking privileges of 'jriguera@%' on 'test_ultimo2_hoy.*' : Ok!
--mysql-user_grants.sh 2013-10-04 17:21:17: Checking privileges of 'jriguera@%' on 'test_ultimo3_hoy.*' : Ok!
--mysql-user_grants.sh 2013-10-04 17:21:17: Checking privileges of 'jriguera@%' on 'test_ultimo5_hoy.*' : Ok!
--mysql-user_grants.sh 2013-10-04 17:21:17: Checking privileges of 'jriguera@%' on 'test_ultimo9_hoy.*' : Ok!
--mysql-user_grants.sh 2013-10-04 17:21:17: Checking privileges of 'jriguera@%' on 'test_ultimo_hoy.*' : Ok!
--mysql-user_grants.sh 2013-10-04 17:21:18: Checking privileges of 'jriguera@localhost' on 'test_jose_hola.*' : Failed!
--mysql-user_grants.sh 2013-10-04 17:21:18 ERROR: User 'jriguera@localhost' not exists on the DB server! You have to create it first.
--mysql-user_grants.sh 2013-10-04 17:21:18: Checking privileges of 'jriguera@localhost' on 'test_plat_hola.*' : Failed!
--mysql-user_grants.sh 2013-10-04 17:21:18 ERROR: User 'jriguera@localhost' not exists on the DB server! You have to create it first.
...
--mysql-user_grants.sh 2013-10-04 17:21:21: counter=2
```

Managing DBs: mysql-db.sh
=========================

To create a DB (without creating users):

```
# ./mysql-db.sh
Usage:

    mysql-db.sh  [-h | --help ] [-d | --debug] 
	      [-r | --remove] [-f | --force ] <gid> <platform> <dbname>

Create/Delete (a new empty DB following the name convention)

Arguments:

   -h, --help         Show this message
   -d, --debug        Debug mode
   -r, --remove       Remove the DB
   -f, --force	      Force even with linked users

In order to be able to remove a DB, it must not have associated users.
```


Managing users: mysql-user_app.sh 
=================================

Just creates an user (and/or password) with the provided privileges:

```
# ./mysql-user_app.sh
Usage:

    mysql-user_app.sh  [-h | --help ] [-d | --debug] 
              [-r | --remove] [-p | --password "userpass"]
              <gid> <platform> <dbname[.table]> <user[@host]> ["PRIVILEGE1, PRIVILEGE2 ..."]

Create/Delete an user to access linked to a DB

Arguments:

   -h, --help         Show this message
   -d, --debug        Debug mode
   -r, --remove       Remove the user
   -p, --password     Password for the new user

If no privileges are passed to the program, it will create the user with grant
"ALL PRIVILEGES". If no host is especified in the user, all host will be allowed
to connet. If no password is specified, a new random pass will be created.

WARNING: This program DROP app users, not revoke privileges!
```


Managing (especial) grants: mysql-user_grants.sh
================================================

Let's imagine you want to provide grants to an admin user for all DBs starting 
with _test_, that is your script. You also can define special rules for users 
who only need to view a couple of tables, or other special permissions. 
Next time, when you use the script _mysql-manage.sh_ (see the first example), 
all the rules will be checked and if it is necessary, they will be applied 
to the new DB.

```
# ./mysql-user_grants.sh --help
Usage:

    mysql-user_grants.sh  [-h | --help ] [--debug] [-u | --user <user>] [-d | --db <db>] <check|update>

Checks and updates the grants for especial users (no app users) like administrators

Arguments:

   -h, --help         Show this message
   --debug            Debug mode

Actions for the service:

    check
    update

Default action is <check>
```

So when you run it without args, it checks if everything is ok:

```
# ./mysql-user_grants.sh
--mysql-user_grants.sh 2013-10-04 17:25:36: Procesing grants file 'mysql-grants.conf' ...
--mysql-user_grants.sh 2013-10-04 17:25:37: Checking privileges of 'jriguera@%' on 'test_jose_hola.*' : OK!
--mysql-user_grants.sh 2013-10-04 17:25:37: Checking privileges of 'jriguera@%' on 'test_plat_hola.*' : OK!
--mysql-user_grants.sh 2013-10-04 17:25:38: Checking privileges of 'jriguera@%' on 'test_prueba_hoy.*' : OK!
--mysql-user_grants.sh 2013-10-04 17:25:38: Checking privileges of 'jriguera@%' on 'test_riguera_hola.*' : OK!
--mysql-user_grants.sh 2013-10-04 17:25:38: Checking privileges of 'jriguera@%' on 'test_test_db.*' : OK!
--mysql-user_grants.sh 2013-10-04 17:25:38: Checking privileges of 'jriguera@%' on 'test_ultimo1_hoy.*' : OK!
--mysql-user_grants.sh 2013-10-04 17:25:38: Checking privileges of 'jriguera@%' on 'test_ultimo2_hoy.*' : OK!
--mysql-user_grants.sh 2013-10-04 17:25:38: Checking privileges of 'jriguera@%' on 'test_ultimo3_hoy.*' : OK!
--mysql-user_grants.sh 2013-10-04 17:25:38: Checking privileges of 'jriguera@%' on 'test_ultimo5_hoy.*' : OK!
--mysql-user_grants.sh 2013-10-04 17:25:38: Checking privileges of 'jriguera@%' on 'test_ultimo9_hoy.*' : OK!
--mysql-user_grants.sh 2013-10-04 17:25:38: Checking privileges of 'jriguera@%' on 'test_ultimo_hoy.*' : OK!
--mysql-user_grants.sh 2013-10-04 17:25:40: Checking privileges of 'jriguera@localhost' on 'test_jose_hola.*' : Failed!
--mysql-user_grants.sh 2013-10-04 17:25:40 ERROR: User 'jriguera@localhost' not exists on the DB server! You have to create it first.
--mysql-user_grants.sh 2013-10-04 17:25:40: Checking privileges of 'jriguera@localhost' on 'test_plat_hola.*' : Failed!
...
--spr-dev-mysql-user_grants.sh 2013-10-04 17:25:44: Checking privileges of 'jose@%' on 'test_jose_hola.*' : OK!
--spr-dev-mysql-user_grants.sh 2013-10-04 17:25:44: Checking privileges of 'jose@%' on 'test_plat_hola.*' : OK!
--spr-dev-mysql-user_grants.sh 2013-10-04 17:25:44: Checking privileges of 'jose@%' on 'test_prueba_hoy.*' : OK!
--spr-dev-mysql-user_grants.sh 2013-10-04 17:25:45: Checking privileges of 'jose@%' on 'test_riguera_hola.*' : OK!
--spr-dev-mysql-user_grants.sh 2013-10-04 17:25:45: Checking privileges of 'jose@%' on 'test_test_db.*' : OK!
--spr-dev-mysql-user_grants.sh 2013-10-04 17:25:45: Checking privileges of 'jose@%' on 'test_ultimo1_hoy.*' : OK!
--spr-dev-mysql-user_grants.sh 2013-10-04 17:25:45: Checking privileges of 'jose@%' on 'test_ultimo2_hoy.*' : OK!
--spr-dev-mysql-user_grants.sh 2013-10-04 17:25:45: Checking privileges of 'jose@%' on 'test_ultimo3_hoy.*' : OK!
--spr-dev-mysql-user_grants.sh 2013-10-04 17:25:45: Checking privileges of 'jose@%' on 'test_ultimo5_hoy.*' : OK!
--spr-dev-mysql-user_grants.sh 2013-10-04 17:25:45: Checking privileges of 'jose@%' on 'test_ultimo9_hoy.*' : OK!
--spr-dev-mysql-user_grants.sh 2013-10-04 17:25:45: Checking privileges of 'jose@%' on 'test_ultimo_hoy.*' : OK!
--spr-dev-mysql-user_grants.sh 2013-10-04 17:25:45: counter=0
```

You have to define the grants in the file _mysql-grants.conf_. For example:

```
# Grants file for MySQL test
#
# This file maintains the grants for special users
# like gid or platform administrators.
#
# Every time a DB is added, this file is checked by 
# the program "user_grants.sh"
#
# <DB | DB regex> : <table | *> : <user> : <MYSQL Privileges>
#
test_mob_p : EVP : test_mob_prouser : SELECT
aaa_.* : * : aaa_GLOBAL_ADM : ALL PRIVILEGES

```

In the first case, the user _test_mob_prouser_ (you have to create it) will 
only be able to perform selects over the table _EVP_ in the database 
_test_mob_p_. In the second case, there is a global user _aaa_GLOBAL_ADM_
for the project _aaa_, so for example, every time that a new DB is created, 
this user will become automatically an administrator.


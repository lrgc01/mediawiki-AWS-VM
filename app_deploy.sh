#!/bin/sh

PROGNAME=`basename $0 .sh`

# Check base packages to continue
which sudo > /dev/null 2>&1
[ "$?" != 0 ] && ( echo "You must install sudo to run this script"; exit 1 )

# Check release (get ID from here)
[ -f /etc/os-release ] && . /etc/os-release

which ansible > /dev/null 2>&1
if [ "$?" != 0 ]; then
  which pip > /dev/null 2>&1
  if [ "$?" != 0 ]; then
     case "$ID" in
       'debian'|'ubuntu')
          sudo apt-get install -y python-pip
       ;;
       *)
         echo "Sorry, only Debian or Ubuntu by now."
         exit 
       ;;
     esac
  fi

  case "$ID" in
    'debian'|'ubuntu'|'Centos')
       sudo pip install ansible
    ;;
    *)
      echo "Sorry, this script only installs the ansible package on Debian, Ubuntu or Centos with pip pre installed."
      exit 
    ;;
  esac
fi


PLAYDIR="`dirname $0`"

cd "$PLAYDIR"

BASEDIR="`pwd`"
CONFDIR="${BASEDIR}/conf.d"
SSHCONF=${SSHCONF:-"${CONFDIR}/ssh_config"}

if [ ! -z "$REMOTE_USER" ]; then
   REMOTE_USER="sudo_user=$REMOTE_USER"
fi

# Warning: There are particular/private local passwords or keys
# that should be copied (or linked) in $CONFDIR

# Ensure priv keys in conf.d dir are protected
if [ -d ${CONFDIR} ]; then
   chmod go-w,o-rwx ${CONFDIR}/*
fi

export BASEDIR CONFDIR SSHCONF

export ANSIBLE_DISPLAY_SKIPPED_HOSTS="false"

export ANSIBLE_SSH_ARGS="-C -o ControlMaster=auto -o ControlPersist=60s -F ${SSHCONF}"

#
# Build a simple inventory file
#
eval SERVER_LIST_${PROGNAME}="\${SERVER_LIST_${PROGNAME}:-\"localhost\"}"
eval SERVER_VARS_${PROGNAME}="\${SERVER_VARS_${PROGNAME}:-\"ansible_python_interpreter=/usr/bin/python3\"}"

# only create if non existing
if [ ! -f "${PROGNAME}.inv" ]; then 
   ERASE_INV='1'
   echo "[${PROGNAME}]" > ${PROGNAME}.inv 
   for srv in `eval echo \\$SERVER_LIST_${PROGNAME}`
   do
       echo $srv >> ${PROGNAME}.inv
   done
   echo "" >> ${PROGNAME}.inv
   echo "[${PROGNAME}:vars]" >> ${PROGNAME}.inv 
   for var in `eval echo \\$SERVER_VARS_${PROGNAME}`
   do
       echo $var >> ${PROGNAME}.inv
   done
   echo "" >> ${PROGNAME}.inv
fi
#
# End build inventory

# Specific for AWS RDS databases: get the endpoint
# Doesn't harm if looked for the instance name which is the same as this prog's name
RC_FILE="`find . -type f -name ${PROGNAME}.rc | head -1`" # limit to the first found
if [ -f "${RC_FILE}" ] ; then
   . "${RC_FILE}"
   DB_INSTANCE="db_instance_endpoint=${_INSTANCE_ENDPOINT}" # _INSTANCE_ENDPOINT is defined in roles/AWS/tasks/*yml
fi

# Use --tags "__TAG_NAME__" to restrict ansible-playbook in the following useful tags:
#  - base_users
#  - auth_keys
#  - deploy_templates
#  - cron_config
#  - config_files
#  - ssl_certificate
#  - databases
#  - php_config
#  - drupal_site
#  - final_config
# From common: (these first two must be called when python is missing)
#  - install_dep_pkg
#  - bootstrap_python
#  - update_repository
# To run or not apt update AND apt upgrade
# update_cache_y_n=yes or no

# First, run with full playbook running - no skip => SKIP_TAGS="" sh thisprogramname.sh
# After first install, the tag "bootstrap_python" can be safely skipped:
#[ -z "$SKIP_TAGS" ] && SKIP_TAGS="--skip-tags bootstrap_python"

[ -z "$GATHER_FACTS" ] && GATHER_FACTS="false"

# Order is important, since Docker will create de DBMS server
ansible-playbook -i ${PROGNAME}.inv --extra-vars "$REMOTE_USER gather_y_n=${GATHER_FACTS} update_cache_y_n=yes basedir=${BASEDIR} confdir=${CONFDIR} sshconf=${SSHCONF} $DB_INSTANCE" $SKIP_TAGS ${PROGNAME}.yml

# garbage
rm -f *.retry 
[ "$ERASE_INV" ] && rm -f ${PROGNAME}.inv

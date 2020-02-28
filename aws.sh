#!/bin/sh

PROGNAME=`basename $0 .sh`

# READ command line
while [ "$#" -gt 0 ]; do
   case "$1" in
      "--auth") ASK_AUTH="y"
      ;;
      "--noauth") ASK_AUTH="silent"
      ;;
   esac
   shift
done

# Check release
[ -f /etc/os-release ] && . /etc/os-release

which ansible > /dev/null 2>&1
if [ "$?" != 0 ]; then
  # Check if can install requisite packages
  which sudo > /dev/null 2>&1
  [ "$?" != 0 ] && ( echo "No ansible. You must install it or have sudo rights to let this script install it"; exit 1 )

  case "$ID" in
    'debian')
       grep "deb http://ppa.launchpad.net/ansible/ansible/ubuntu trusty main" /etc/apt/sources.list > /dev/null 2>&1 
       if [ "$?" != 0 ]; then
          sudo sh -c "echo 'deb http://ppa.launchpad.net/ansible/ansible/ubuntu trusty main' >> /etc/apt/sources.list"
       fi
       # Followed instructions in https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html#latest-releases-via-apt-debian
       sudo apt install dirmngr
       sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 93C4A3FD7BB9C367
       sudo apt-get update
       sudo apt-get -y install ansible
    ;;
    'ubuntu')
       sudo apt-get update
       sudo apt-get -y install software-properties-common
       sudo apt-add-repository ppa:ansible/ansible
       sudo apt-get update
       sudo apt-get -y install ansible
    ;;
    *)
      echo "Sorry, only Debian or Ubuntu by now."
      exit 
    ;;
  esac
 fi

PLAYDIR="`dirname $0`"

cd "$PLAYDIR"

BASEDIR="`pwd`"
CONFDIR="${BASEDIR}/conf.d"
SSHCONF="${CONFDIR}/ssh_config"
FACTSDIR="${BASEDIR}/facts.d"

export BASEDIR CONFDIR SSHCONF FACTSDIR

export ANSIBLE_DISPLAY_SKIPPED_HOSTS="false"

# First check base local pre-requisites, but becoming root with password:
##echo "Local sudo to install local base requirements (may comment line after first run)"
##ansible-playbook -i hosts --ask-become-pass base_AWS.yml
# can comment the line after first successfull run

# Read credentials from input line
if [ "$ASK_AUTH" = "y" ]; then
	echo "Echo mode off. Typing won't show up"
	echo -n "Enter AWS Access ID:"
	stty -echo
	read AWS_ACCESS_KEY_ID
	echo
	stty echo
	echo -n "Enter AWS Access key:"
	stty -echo
	read AWS_SECRET_ACCESS_KEY
	echo
	stty echo
	export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
	echo "Echo mode on."
else
   if [ "$AWS_ACCESS_KEY_ID" = "" -o "$AWS_SECRET_ACCESS_KEY" = "" ] ; then
     if [ "$ASK_AUTH" != "silent" ]; then
	echo "#########################################################"
	echo "  This script can ask for key id/pass pair from command line"
	echo "  in order to set the environment variables to "
	echo "  authenticate in AWS. Just call it with --auth."
	echo "  To dismiss this message call with --noauth."
	echo "#########################################################"
     fi
   fi
fi

# Some usefull tags to pass with --tags or skip with --skip-tags
#  - base_config
#  - gather_default_vpc
#  - create_key_pairs
#  - create_security_groups
#  - create_aws_instances
#  - create_ec2_instances
#  - create_rds_instances
#  - change_state_all_ec2_instances
#  - change_state_all_instances
#

# First, run with full playbook running - no skip => SKIP_TAGS="--tags bootstrap_python" sh aws.sh
# After first install, the tag "bootstrap_python" can be safely skipped:
[ -z "$SKIP_TAGS" ] && SKIP_TAGS="--skip-tags bootstrap_python"

[ -z "$GATHER_FACTS" ] && GATHER_FACTS="false"

# The rest of AWS stuff may work with a local non-root user
#ansible-playbook -i ${PROGNAME}.inv --extra-vars "gather_y_n=false basedir=${BASEDIR} confdir=${CONFDIR} sshconf=${SSHCONF} facts_out_dir=${FACTSDIR}" --tags "gather_cfn" ${PROGNAME}.yml
ansible-playbook -i ${PROGNAME}.inv --extra-vars "gather_y_n=${GATHER_FACTS}  basedir=${BASEDIR} confdir=${CONFDIR} sshconf=${SSHCONF} facts_out_dir=${FACTSDIR}" ${SKIP_TAGS} ${PROGNAME}.yml

rm -f *.retry

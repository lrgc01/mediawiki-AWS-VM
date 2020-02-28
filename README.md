# Deployment of a mediawiki server on a VM in a cloud provider

The goal of this exercise is to deploy a linux VM (ubuntu) in a cloud (here AWS) and then deploy the mediawiki server on it using a well known web server (nginx).

## The running system 

The systems was deployed in a AWS cloud with 1 EC2 instance, 1 RDS instance and 1 CFN distribution. All VPC and subnets are the default to an ordinary AWS account.

Mediawiki is running on the URL: [http://ec2-13-59-68-214.us-east-2.compute.amazonaws.com/](http://ec2-13-59-68-214.us-east-2.compute.amazonaws.com/). This AWS address is the same as the Linux VM which can be accessed using the proper key pair via SSH and user ubuntu.

The RDS instance is named mediawiki or mediawiki.ctxnidj2utoz.us-east-2.rds.amazonaws.com which is not accessible from the internet, but only in the private cloud.

The CFN distribution is using the CFN address [http://d3n7n18gbk9ktd.cloudfront.net](http://d3n7n18gbk9ktd.cloudfront.net) which is supposed to redirect the connection to the origin URL http://ec2-13-59-68-214.us-east-2.compute.amazonaws.com.

## Playbooks

There are two playbooks in the same directory hierarchy. They run by running one script for each that check some environment, change if necessary, and run the ansible-playbook.i

The next two sections show an overview of each playbook.

### The AWS cloud playbook

Main tasks:
  - Create (or modify or delete) EC2 instance: here = ubuntu 18.04
  - Create (or modify or delete) RDS instance: name = mediawiki
  - Create the Cloudfront distribution **after** the deploy of the EC2, since we are using the origin as the amazon computer hostname (ec2-...compute.amazonaws.com)
  - Save locally some facts to be used later by the deployment of the application on the linux VM, like the hostname/IP, the database endpoint, the ssh key pair, etc.
    - conf.d/ssh_config    (IdentityFile, StrictHostKeyChecking, etc)
    - facts.d/mediawiki.rc (database endpoint)

### The mediawiki playbook

It uses some data recorded by the previos playbook. Check in these directories/files:
  - conf.d/ssh_config
  - facts.d/mediawiki.rc (the database instance name)

Main tasks:
  - Install base software: 
and grant privilages on the database: here mediawiki instance name, user wikiuser

## Overview of ansible playbook directory organization

  - Directories:
    - . (the root): 
      - aws.sh: script to set some environment (ex. auth) and/or to install some pre requisites and then run the playbook
      - AWS-mediawiki.yml: playbook to deploy the VM
      - AWS-mediawiki.inv: inventory to the AWS-mediawiki playbook
      - AWS-mediawiki.sh : a link to the aws.sh script (which is a generic one)
      - app_deploy.sh: script to set some environment (ex. SSH stuff) based on previous output from the AWS VM playbook, to install some pre requisites and then run the playbook
      - mediawiki.yml: playbook to deploy the mediawiki on the previous linux VM build on AWS cloud
      - mediawiki.inv: inventory to the mediawiki playbook
      - mediawiki.sh : a link to the app_deploy.sh script (which is a generic one)
    - conf.d: transient configuration based on linux needs (ssh key pair, ssh conf, etc.) 
    - facts.d: the facts gathered from AWS cloud respectively to each VM (EC2), database (RDS), VPC, subnet, Cloudfront (CFN), etc.
    - roles: the roles directory according to Ansible best practices having the subdirectories default, tasks and templates (almost always)
      - common: very generic tasks like installing python it non existing
      - base: base tasks like package install and some file / template deployment to adjust to the whole config need
      - DB_adm: create, delete, change databases and grants
      - AWS: create, delete, change instances: EC2, RDS, CFN, as well as gather facts to later record locally
    - vars_files: the variables used in each playbook run
      - base_AWS.yml and AWS-mediawiki.yml: loaded in AWS-mediawiki.yml playbook
      - mediawiki.yml: loaded in mediawiki.yml playbook

  - Sensitive data:
    - All sensitive data is omitted in this repository
      - ../secret.yml is a file imported by AWS-mediawiki.yml and mediawiki.yml playbooks that should contain the database user, password and database name
      - conf.d/ECS-Test-key.pem should be used to grant access to the ubuntu user in the VM, but is a non existing file in this repository as is all conf.d directory
      - facts.d is a missing directory in this repo that record data from the running system for later use
      - conf.d and facts.d shall be created by the shell script when running the AWS playbook

## The playbook roles summary

First a summary of each role. Then their tasks listed with '--list-tasks'.

### Roles summary for AWS-mediawiki playbook

  - common
  - AWS

#### the common role

Responsible to adjust the environment, for example, by installing python or pip or python-openssl.

#### the AWS role

Main role. First create some local subdirectories to set aws auth configs and then other subdirs to save some transient configuration like SSH settings and database endpoint name.

The tasks of main interest are the EC2, RDS and CFN creation. CFN is done by a handler after EC2 creation. The last tasks collect many relevant data (facts) and save them under facts.d subdirectory.

### Roles summary for mediawiki playbook

  - common
  - base
  - DB\_adm

#### the common role

As in the former playbook. It is responsible to adjust the environment, for example, by installing python or pip or python-openssl.

#### the base role

Its tasks shall install all packages as requisite to deploy a simple linux server, like nginx web server, php and its extensions. 

Some of its tasks receive file, link, template definitions to deploy in proper place. 

As with php, some INI files are changed according to the need. 

The mediawiki source bundle is downloaded and unarchived (a tar ball) in the proper place (/var/www/html).

At its final duties this role check the previous defined packages, if having the 'srv' key in its dictionary, and make sure the corresponding service is started, like 'nginx' and 'php7.2-fpm'.

#### the DB\_adm role

Create databases and grant privileges in DBMS servers. Here a MySQL RDS instance. 

The endpoint was saved in facts.d/'instanceName'.rc by the former playbook: AWS-mediawiki after the RDS instance deployment. In this case: 'facts.d/mediawiki.rc', and it is 'sourced' by the shell script when invoked (mediawiki.sh).


### Tasks list

```
playbook: AWS-mediawiki.yml

  play #1 (local): local        TAGS: []
    tasks:
      common : Install remote python if not installed ------------      TAGS: [bootstrap_python]
      common : Update cache and upgrade (may take a time) --------      TAGS: [update_repository]
      common : Preliminary dependency install -- python-pip ------      TAGS: [bootstrap_python]
      common : Preliminary dependency install -- python3-pip -----      TAGS: [bootstrap_python]
      common : Install local python dependencies via pip ---------      TAGS: [bootstrap_python]
      common : Install very basic packages to run ansible --------      TAGS: [install_base_pkg]
      AWS : Ensure base output directories ---  TAGS: [base_config, create_aws_instances, create_ec2_instances, create_security_groups, gather_default_vpc, gather_elb]
      AWS : Set AWS config ini style file ----- TAGS: [base_config]
      AWS : Gather default VPC facts ---------- TAGS: [create_aws_instances, create_ec2_instances, create_security_groups, gather_default_vpc]
      AWS : Copy default VPC facts ------------ TAGS: [gather_default_vpc]
      AWS : Gather default subnets ------------ TAGS: [create_aws_instances, create_ec2_instances, create_security_groups, gather_default_vpc]
      AWS : Copy default subnets facts -------- TAGS: [gather_default_vpc]
      AWS : Create/Modify/Delete sec groups --- TAGS: [change_state_all_ec2_instances, change_state_all_instances, create_aws_instances, create_ec2_instances, create_rds_instances, create_security_groups]
      AWS : Create/Delete EC2 key pairs ------- TAGS: [create_aws_instances, create_ec2_instances, create_key_pairs, create_rds_instances]
      AWS : Copy EC2 Private Key -------------- TAGS: [create_ec2_instances, create_instance, create_key_pairs, create_rds_instance]
      AWS : Create/Modify/Delete EC2 instances  TAGS: [create_aws_instances, create_ec2_instances]
      AWS : Create/Modify/Delete RDS instances  TAGS: [create_aws_instances, create_rds_instances]
      AWS : Gather CFN instances facts -------- TAGS: [change_state_all_instances, create_aws_instances, create_cfn_instances, gather_cfn]
      AWS : Create CloudFront distribution ---- TAGS: [create_aws_instances, create_cfn_instances]
      AWS : Copy security groups facts -------- TAGS: [change_state_all_ec2_instances, change_state_all_instances, create_aws_instances, create_ec2_instances, create_rds_instances, create_security_groups]
      AWS : Gather EC2 instances facts -------- TAGS: [change_state_all_ec2_instances, change_state_all_instances, create_aws_instances, create_ec2_instances, gather_ec2]
      AWS : Gather RDS instances facts -------- TAGS: [change_state_all_instances, create_aws_instances, create_rds_instances, gather_rds]
      AWS : Gather CFN instances facts -------- TAGS: [change_state_all_instances, create_aws_instances, create_cfn_instances, gather_cfn]
      AWS : Copy EC2 instances facts ---------- TAGS: [change_state_all_ec2_instances, change_state_all_instances, create_aws_instances, create_ec2_instances, gather_ec2]
      AWS : Copy RDS instances facts ---------- TAGS: [change_state_all_instances, create_aws_instances, create_rds_instances, gather_rds]
      AWS : Copy CFN filesystems facts -------- TAGS: [change_state_all_instances, create_aws_instances, create_cfn_instances, gather_cfn]
      AWS : Copy EC2 instances IP/DNS --------- TAGS: [change_state_all_ec2_instances, change_state_all_instances, create_aws_instances, create_ec2_instances, gather_ec2]
      AWS : Copy RDS instances useful data ---- TAGS: [change_state_all_instances, create_aws_instances, create_rds_instances, gather_rds]
      AWS : Deploy templates for inventory ---- TAGS: [config_ansible_host_file, config_files]

playbook: mediawiki.yml

  play #1 (mediawiki): mediawiki        TAGS: []
    tasks:
      common : Install remote python if not installed ------------      TAGS: [bootstrap_python]
      common : Update cache and upgrade (may take a time) --------      TAGS: [update_repository]
      common : Preliminary dependency install -- python-pip ------      TAGS: [bootstrap_python]
      common : Preliminary dependency install -- python3-pip -----      TAGS: [bootstrap_python]
      common : Install local python dependencies via pip ---------      TAGS: [bootstrap_python]
      common : Install very basic packages to run ansible --------      TAGS: [install_base_pkg]
      base : Install dependency packages -----------------------        TAGS: [install_dep_pkg]
      base : Ensure directories (when dir_file_tmpl_list.dir) --        TAGS: [config_files, deploy_templates]
      base : Make proper links or remove (state link or absent) -       TAGS: [config_files, deploy_templates]
      base : Deploy templates dir_file_tmpl_list.types=tmpl ----        TAGS: [config_files, deploy_templates]
      base : Upload files as state=upload in dir_file_tmpl_list -       TAGS: [config_files, upload_files]
      base : Restart service after tmpl/file/link change -------        TAGS: [config_files, deploy_templates, upload_files]
      base : Run shell if pointed out by tmpl of file tasks ----        TAGS: [config_files, deploy_templates, upload_files]
      base : Set some ini type files ---------------------------        TAGS: [config_files]
      base : Download and unarchive a .tgz, .rpm, etc packet ---        TAGS: [config_files]
      base : Ensure services are started and enabled -----------        TAGS: [install_dep_pkg]
      DB_adm : Create MySql DBs on respective hosts --------------      TAGS: [create_databases, databases]
      DB_adm : Grant user privileges in MySql DBs ----------------      TAGS: [databases, grant_privileges]
```


Overview
========

This project contains ansible playbooks to deploy Openstack and MidoNet both
in All-in-one and in multi-node environments.

Requirements
------------

- Ansible 1.6+
- Nova, Keystone, and Neutron python clients

Installation
------------

Install [Ansible](http://www.ansible.com) in your machine. For Ubuntu:

```
sudo apt-get install software-properties-common
sudo apt-add-repository ppa:ansible/ansible
sudo apt-get update
sudo apt-get install ansible
```

Install openstack clients

```
sudo apt-get install python-pip
sudo pip install python-keystoneclient python-novaclient python-neutronclient python-glanceclient
```

Update ansible-openstack-modules:

```
git submodule update --init
```

Configure
---------

Edit files in vars to your needs. See the examples in the repository.
I suggest to make a copy of os\_settings.yml outside of the git project so you
can use your personal creds.

```
[example]
```

Optional
--------

Add localhost to the default ansible hosts file

```
sudo cat > /etc/ansible/hosts << EOF
[local]
localhost    ansible_connection=local
EOF
```

Re-use SSH connections. Edit your ```.ssh/config``` file.

```
Host *
    controlpath /tmp/m-%l-%r@%h:%p
    stricthostkeychecking no
    controlmaster auto
    forwardagent yes
    controlpersist yes
```

Deploy playbook
---------------

Example (At least, the deploy variable is needed)

```
ansible-playbook -i hosts -e deploy=ubuntu14 -e os_settings=~/os_settings.yml site.yml
```

Grab a coffee/beer and wait some minutes.

Log in to controller IP when finished.

Deploy local Allinone
---------------------

Example to deploy an allinone Openstack + Midonet in local

```
ansible-playbook -i hosts_localhost_allinone -e deploy=ubuntu14 local-allinone.yml
```
Variables
---------

You can specify the following variables when you run ansible-playbook with
command line arguments, e.g. `-e http_proxy=1.2.3.4:1080`


Variable        | Required                           |  Description
-------------   | --------                           | ------------
http_proxy      |  No                                | Hostname or IP address optionally followed by port# e.g.`1.2.3.4:1080` for apt/yum http proxy server
repo_url_base   | Yes                                | Base of the url for apt/yum repository server.
midonet_repo    | No when debian_pkg_path is defined | Repository for MidoNet Packages, e.g. "midonet-nightly", "midonet-5", "mem-1.9", etc.
midonet_dist    | ditto                              | Distribution("unstable", "testing", "rc", "stable") of the Packages. Note that there's no "rc" or "stable" in the nightly repo.
debian_pkg_path | No                                 | Path to the debian package files so apt-get can find find them.
midonet_os_repo | Yes                                | Repository for MidoNet OpenStack packages, e.g. "openstack-kilo", "openstack-juno".
midonet_os_dist | Yes                                | Distribution("unstable", "testing", "rc", "stable") of the packages.
pkg_pubkey_url  | Yes                                | URL for public key for packages.

Vagrant files for development
-----------------------------

There are two vagrant files under `vagrant` directory for centos7 and for ubuntu14.
These are useful for development and testing your changes by deploying local
allinone inside. Here are notable configurations in `Vagrantfile`s:

- Port forwarding

  - For horizon (guest:80)
      - host:9999 on ubuntu14
      - host:9998 on centos7

  - For noVNC(guest:6080)  (TODO: automatically configure nova.conf)
      - host:6080 on ubuntu14
      - host:6079 on centos7

- Synced folder
  -  the top directory of this repository gets mounted on `/ansible` in the guest

- Installing dev tools
  -  basic tools(e.g. ansible, git) get installed with the provisioning script

- SSH agent forwarding: for accesing github
- RAM: 4GB


##### Start a VM

Go to either `vagrant/ubuntu14` or `vagrant/centos7` and start a VM.
Running examples below assume `centos7`

On the host:
```
cd vagrant/centos7
vagrant up
```

##### Log in to the VM

On the host:
```
vagrant ssh
```

You will be logged inside the guest after this.


#### deploy allinone


Inside the guest:
```
cd /ansible
ansible-playbook -i hosts_localhost_allinone -e deploy=centos7 local-allinone.yml
```

NOTE that there are required variables that need to be specified in the command line.
TODO: we need to list up all those variables with proper explanations.

***

> \- What is an ansible, Shevek?
> \- An idea.
> He smiled without much humor.

*Ursula K. LeGuin - The Dispossesed*

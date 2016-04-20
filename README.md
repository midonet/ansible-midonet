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

***

> \- What is an ansible, Shevek?
> \- An idea.
> He smiled without much humor.

*Ursula K. LeGuin - The Dispossesed*

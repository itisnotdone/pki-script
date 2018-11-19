#!/bin/bash

#wget -qO - https://packages.chef.io/chef.asc | sudo apt-key add -
#echo "deb [arch=amd64] https://packages.chef.io/repos/apt/stable xenial main" | sudo tee /etc/apt/sources.list.d/chef-stable.list

# used apt-get with -qq option to minimize the output
# sudo apt-get -qq update
# sudo apt-get -qq install -y chef

#if [ ! -f /usr/bin/hostnamectl_bak ]; then
#sudo mv /usr/bin/hostnamectl /usr/bin/hostnamectl_bak
#else
#sudo rm -vf /usr/bin/hostnamectl
#fi

#sudo bash -c "cat << EOF1 > /usr/bin/hostnamectl
#cat << EOF2
#   Static hostname: $(hostname)
#         Icon name: computer-server
#           Chassis: server
#        Machine ID: IIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII
#           Boot ID: DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD
#  Operating System: $(echo `lsb_release --description | awk -F ':' '{print $2}'`)
#            Kernel: Linux $(uname -r)
#      Architecture: $(uname -i)
#EOF2
#EOF1"
#sudo chmod +x /usr/bin/hostnamectl

#sudo mkdir /opt/chef/embedded/etc
#sudo bash -c "cat << EOF > /opt/chef/embedded/etc/gemrc
#gem: --no-ri --no-rdoc
#benchmark: false
#verbose: true
#update_sources: true
#sources: 
#- http://rubygems.org/
#backtrace: true
#bulk_threshold: 1000
#EOF"

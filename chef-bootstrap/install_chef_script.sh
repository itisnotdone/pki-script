#!/bin/bash

wget -qO - https://packages.chef.io/chef.asc | sudo apt-key add -
#echo "deb [arch=amd64] http://repo/chef/repos/apt/stable xenial main" | sudo tee /etc/apt/sources.list.d/chef-stable.list
echo "deb [arch=amd64] https://packages.chef.io/repos/apt/stable xenial main" | sudo tee /etc/apt/sources.list.d/chef-stable.list

# To wait until /var/lib/apt/lists can be locked.
while ps aux | grep apt | egrep -v 'chef|grep'; do echo "Waiting until apt is available.."; sleep 1; done

# used apt-get with -qq option to minimize the output
sudo apt-get -qq update
sudo apt-get -qq install -y chef
# sudo apt update && sudo apt install -y chef


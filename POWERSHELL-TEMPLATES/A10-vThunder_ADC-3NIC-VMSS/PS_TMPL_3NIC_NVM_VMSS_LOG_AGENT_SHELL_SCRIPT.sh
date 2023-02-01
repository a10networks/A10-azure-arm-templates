#!/bin/bash
# port number
port=514
mode="udp"
# azure log workspace id
customer_id="d1c8985b-xxxx-xxxx-xxxx-12868ad9d740"
# azure log Primary Key
shared_key="tewPsyMYkdGOThRjEyl********************************************************F8CzJ49ZRgw=="
# telegrapf config
(cat /etc/environment; echo "AZURE_CLIENT_ID=10724xxx-xxxx-xxxx-xxxx-xxxxxc14726d"; echo "AZURE_TENANT_ID=91d27xxx-xxxx-xxxx-xxxx-xxxbf81fcb2f"; echo "AZURE_CLIENT_SECRET=9-xxx~jxxOREVyxxxxxHNxxxOwv_xxxxxZLIYxxx") | sudo tee /etc/environment
app_insights_Key="37b1aea5-xxxx-xxxx-xxxx-f2c012bccd93"

# update package
sudo apt-get update
# get fluent bit install file
sudo curl https://raw.githubusercontent.com/fluent/fluent-bit/master/install.sh | sh
sudo curl https://packages.fluentbit.io/fluentbit.key | gpg --dearmor > /usr/share/keyrings/fluentbit-keyring.gpg
# update package after fluent bit config
sudo apt-get update
# install fluent bit
sudo apt-get install fluent-bit 2.0.3 -y
# allow port 514 udp
sudo ufw allow 514/udp
# start and stop fluent bit service
sudo service fluent-bit start && sudo service fluent-bit stop
# run fluentbit command with syslog plugin
sudo /opt/fluent-bit/bin/fluent-bit -R /etc/fluent-bit/parsers.conf -i syslog -p Listen=0.0.0.0 -p Port=$port -p Mode=$mode -p Parser=syslog-rfc3164 -o azure -p customer_id=$customer_id -p shared_key=$shared_key -m '*' -f 1 &
# setup cron job for auto start
(sudo crontab -l 2>/dev/null; echo "@reboot sudo /opt/fluent-bit/bin/fluent-bit -R /etc/fluent-bit/parsers.conf -i syslog -p Listen=0.0.0.0 -p Port=$port -p Mode=$mode -p Parser=syslog-rfc3164 -o azure -p customer_id=$customer_id -p shared_key=$shared_key -m '*' -f 1 &") | sudo crontab -

#install telegraf and start telegraf
sudo curl -s https://repos.influxdata.com/influxdb.key | sudo apt-key add -
source /etc/lsb-release
echo "deb https://repos.influxdata.com/${DISTRIB_ID,,} ${DISTRIB_CODENAME} stable" | sudo tee /etc/apt/sources.list.d/influxdb.list
sudo wget https://repos.influxdata.com/debian/packages/telegraf_1.23.4-1_amd64.deb
sudo dpkg -i telegraf_1.23.4-1_amd64.deb
sudo systemctl start telegraf

#install go and it's dependencies
sudo wget https://golang.org/dl/go1.18.4.linux-amd64.tar.gz
sudo tar -xzf go1.18.4.linux-amd64.tar.gz -C /usr/local/
sudo sed -i -e '$aexport PATH=$PATH:/usr/local/go/bin' /etc/profile
source /etc/profile
sudo snap install go --channel=1.18/stable --classic

#run custom plugin and configure it's depencencies
sudo apt install unzip
sudo apt-get install python3-pip -y
sudo pip3 install make
cd $1/usr/local/go/src
sudo git clone https://github.com/influxdata/telegraf.git
cd $1/usr/local/go/src/telegraf
sudo make

cd $1/usr/local/go/src/telegraf/plugins/inputs

#clone customplugin folder from gitlab
sudo unzip /usr/local/plugins.zip -d /usr/local/
sudo cp -r /usr/local/plugins/telegraf/plugins/inputs/customplugin /usr/local/go/src/telegraf/plugins/inputs/
cd $1/usr/local/go/src/telegraf/plugins/inputs/customplugin
sudo mv all.go /usr/local/go/src/telegraf/plugins/inputs/all
sudo mv customplugin.conf /usr/local/go/src/telegraf
sudo sed -i "s/"InstrumentationKeyUniqueValue"/$app_insights_Key/g" /usr/local/go/src/telegraf/customplugin.conf

sudo pip3 install python-dotenv
sudo pip3 install azure-identity==1.2.0
sudo pip3 install azure-mgmt-network

cd $1/usr/local/go/src/telegraf
sudo make
cd $1/usr/local/go/src
cd $1/usr/local/go/src/telegraf
sudo ./telegraf --config customplugin.conf &

(sudo crontab -l 2>/dev/null; echo "@reboot cd $1/usr/local/go/src/telegraf/ && sudo ./telegraf --config customplugin.conf") | sudo crontab -
exec bash
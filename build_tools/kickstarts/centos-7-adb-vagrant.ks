#repo http://mirror.centos.org/centos/7/os/x86_64/
install
text
keyboard us
lang en_US.UTF-8
skipx
network --device eth0 --bootproto dhcp --hostname centos7-adb
rootpw vagrant
firewall --disabled
authconfig --enableshadow --enablemd5
selinux --enforcing
timezone --utc America/New_York
# The biosdevname and ifnames options ensure we get "eth0" as our interface
# even in environments like virtualbox that emulate a real NW card
bootloader --location=mbr --append="no_timer_check console=tty0 console=ttyS0,115200 net.ifnames=0 biosdevname=0"
zerombr
clearpart --all --drives=vda

user --name=vagrant --password=vagrant

part biosboot --fstype=biosboot --size=1
part /boot --size=300 --fstype="xfs"
part pv.01 --grow
volgroup vg001 pv.01
logvol / --size=8192 --fstype="xfs" --name=root --vgname=vg001

reboot

%packages
@core
docker
deltarpm
rsync
screen
git
kubernetes
etcd
flannel
bash-completion
man-pages
atomic
nfs-utils
PyYAML
libyaml-devel
tuned
httpd-tools
adb-utils
centos-release-adb
fuse-sshfs
openshift2nulecule
cockpit
%end

%post

# Workaround for BZ1336857
restorecon -v /usr/bin/docker*

# Add adb version info to consumed by vagrant-service-manager plugin
# https://github.com/projectatomic/adb-atomic-developer-bundle/issues/183
echo "VARIANT=\"Atomic Developer Bundle (ADB)\"" >> /etc/os-release
echo "VARIANT_ID=\"adb\"" >> /etc/os-release
echo "VARIANT_VERSION=\"2.2.0\"" >> /etc/os-release

#Fixing https://github.com/projectatomic/adb-atomic-developer-bundle/issues/155
echo "127.0.0.1     centos7-adb" >> /etc/hosts

# set tuned profile to force virtual-guest
tuned-adm profile virtual-guest

# sudo
echo "%vagrant ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/vagrant
sed -i "s/^.*requiretty/#Defaults requiretty/" /etc/sudoers

# Fix #103 (https://github.com/projectatomic/adb-atomic-developer-bundle/issues/103)
echo "LC_ALL=en_US.utf-8" >> /etc/locale.conf

# Fix for #128 (https://github.com/projectatomic/adb-atomic-developer-bundle/issues/128)
cat > /etc/sysconfig/network-scripts/ifcfg-eth0 << EOF
DEVICE="eth0"
BOOTPROTO="dhcp"
ONBOOT="yes"
TYPE="Ethernet"
PERSISTENT_DHCLIENT="yes"
EOF

systemctl enable docker

groupadd docker
usermod -a -G docker vagrant

# Default insecure vagrant key
mkdir -m 0700 -p /home/vagrant/.ssh
echo "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA6NF8iallvQVp22WDkTkyrtvp9eWW6A8YVr+kz4TjGYe7gHzIw+niNltGEFHzD8+v1I2YJ6oXevct1YeS0o9HZyN1Q9qgCgzUFtdOKLv6IedplqoPkcmF0aYet2PkEDo3MlTBckFXPITAMzF8dJSIFo9D8HfdOV0IAdx4O7PtixWKn5y2hMNG0zQPyUecp4pzC6kivAIhyfHilFR61RGL+GPXQ2MWZWFYbAGjyiYJnAmCP3NOTd0jMZEnDkbUvxhMmBYSdETk1rRgm+R4LOzFUGaHqHDLKLX+FIPKcF96hrucXzcWyLbIbEgE98OHlnVYCzRdK8jlqm8tehUc9c9WhQ== vagrant insecure public key" >> /home/vagrant/.ssh/authorized_keys
chmod 600 /home/vagrant/.ssh/authorized_keys
chown -R vagrant:vagrant /home/vagrant/.ssh

# update docker.service file to exec the certificate generation script
sed -i.back 's/ExecStart=/ExecStartPre=\/opt\/adb\/cert-gen.sh\n&/' /usr/lib/systemd/system/docker.service

# update the docker config to listen on TCP as well as unix socket
sed -i.back '/OPTIONS=*/c\OPTIONS="--selinux-enabled -H tcp://0.0.0.0:2376 -H unix:///var/run/docker.sock --tlscacert=/etc/docker/ca.pem --tlscert=/etc/docker/server-cert.pem --tlskey=/etc/docker/server-key.pem --tlsverify"' /etc/sysconfig/docker

# Clear yum package and metadata cache
yum clean all

%end

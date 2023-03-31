#!/usr/bin/env bash
set -xeuo pipefail ;
# ref
# https://github.com/pythops/workstation/blob/master/scripts/start-vm.sh
VM_NAME="k3s" ;
workdir="${HOME}/qemu" ;
dir="${workdir}" ;
qcow="${dir}/${VM_NAME}.qcow2" ;
iso="${dir}/cloud-init.iso"
# url for bootable Archlinux VM disk
url="https://geo.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-cloudimg.qcow2" ;
# installing deps on arch
if [ "$(command -v "pacman")" != "" ];then
	if [ "$(command -v "xorriso")" == "" ];then
		sudo pacman -Syy --needed --noconfirm "libisoburn" ;
	fi
	if [ "$(command -v "openssl")" == "" ];then
		sudo pacman --quiet -Syy --noconfirm "openssl" ;
	fi
	if [ "$(command -v "qemu-system-x86_64")" == "" ];then
		sudo pacman --quiet -Syy --noconfirm "qemu-base" "qemu-system-x86" ;
	fi
	if [ "$(command -v "aria2c")" == "" ];then
		sudo pacman --quiet -Syy --noconfirm "aria2" ;
	fi
	if [ "$(command -v "socat")" == "" ];then
		sudo pacman --quiet -Syy --noconfirm "socat" ;
	fi
	# TODO: remove this once ssh is fixed
	if [ "$(command -v "sshpass")" == "" ];then
		sudo pacman --quiet -Syy --noconfirm "sshpass" ;
	fi
fi
# Ensuring required binaries exist
if [ "$(command -v "xorriso")" == "" ];then
	echo "*** "xorriso" not found in PATH. please install it before running this script"
	exit 1
fi
if [ "$(command -v "openssl")" == "" ];then
	echo "*** "openssl" not found in PATH. please install it before running this script"
	exit 1
fi
if [ "$(command -v "qemu-system-x86_64")" == "" ];then
	echo "*** "qemu-system-x86_64" not found in PATH. please install it before running this script"
	exit 1
fi
if [ "$(command -v "socat")" == "" ] ;then
	echo "*** "socat" not found in PATH. please install it before running this script"
	exit 1
fi
if [ "$(command -v "aria2c")" == "" ];then
	echo "*** "aria2c" not found in PATH. it is recommended to install "aria2" before running this script"
fi
if [ "$(command -v "wget")" == "" ] && [ "$(command -v "aria2c")" == "" ];then
	echo "*** "wget" not found in PATH. please install it before running this script"
	exit 1
fi
# TODO: remove this once everythning is fixed
rm -rf "${dir}" ;
[ ! -p "${dir}" ] && mkdir -p "${dir}"

pushd "${dir}" > /dev/null 2>&1 ;

if [ ! -r "${qcow}" ]; then
	# if [ "$(command -v "aria2c")" != "" ];then
	# 	aria2c --optimize-concurrent-downloads --min-split-size=1M --max-connection-per-server=16 --continue=true --file-allocation=falloc --dir="${dir}" --out="$(basename ${qcow})" "${url}"
	# else
		# short form :
		# wget -nv -qO "${qcow}" "${url}"
		wget --quiet --no-verbose --show-progress --output-document "${qcow}" "${url}" ;
	# fi
fi
# generating ssh key to inject into the guest 
PRIVATE_KEY="${HOME}/.ssh/id_rsa_${VM_NAME}" ;
if [ ! -r "${PRIVATE_KEY}" ];then
	[ ! -d "$(dirname "${PRIVATE_KEY}")" ] && mkdir -p "$(dirname "${PRIVATE_KEY}")"]
	ssh-keygen -b "4096" -t "rsa" -f "${PRIVATE_KEY}" -N ""
	chmod 700 "$(dirname "${PRIVATE_KEY}")" ;
	find "$(dirname "${PRIVATE_KEY}")" -type f -name "id*" -exec chmod 600 {} \;
	find "$(dirname "${PRIVATE_KEY}")" -type f -name "id*.pub" -exec chmod 644 {} \;
	[ -r "$(dirname "${PRIVATE_KEY}")/authorized_keys" ] && chmod 644 "$(dirname "${PRIVATE_KEY}")/authorized_keys" ;
	[ -r "$(dirname "${PRIVATE_KEY}")/known_hosts" ] && chmod 644 "$(dirname "${PRIVATE_KEY}")/known_hosts" ;
	[ -r "$(dirname "${PRIVATE_KEY}")/config" ] && chmod 644 "$(dirname "${PRIVATE_KEY}")/config" ;
fi
if [ ! -r "${iso}" ]; then
	if [ "$(command -v "go")" != "" ];then
		if [ "$(command -v "yamlfmt")" == "" ];then
			go install github.com/google/yamlfmt/cmd/yamlfmt@latest
		fi
	fi
# ssh_pwauth: false
# NOTE: location in guest
# sudo cat /var/lib/cloud/instance/user-data.txt
# sudo cat /var/lib/cloud/instances/nocloud/cloud-config.txt
	cat << EOF | tr -dC '[:print:]\t\n' | tee "${dir}/user-data" > /dev/null
#cloud-config
output: {all: '| tee -a /var/log/cloud-init-output.log'}
disable_root: true
system_info:
  distro: arch
  ssh_svcname: sshd
  default_user:
    name: arch
    plain_text_passwd: arch
    lock_passwd: false
    gecos: Arch Cloud User
    groups: 
      - wheel
      - sudo
      - adm
    sudo: 
      - ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
users:
  - default
  - name: "$(whoami)"
    passwd: "$(openssl passwd -1 -salt SaltSalt '${USER}' 2>/dev/null)"
    lock_passwd: false
    groups: 
      - wheel
      - sudo
      - adm
    shell: /bin/bash
    ssh_authorized_keys:
      - $(cat "${PRIVATE_KEY}")
packages:
  - zsh
write_files:
  - path: /etc/sysctl.d/enabled_ipv4_forwarding.conf
    content: |
      net.ipv4.conf.all.forwarding=1
  - path: /etc/ssh/sshd_config
    content: |
      AcceptEnv                         LANG   LC_*
      Subsystem                         sftp   /usr/lib/openssh/sftp-server
      ChallengeResponseAuthentication   no
      UsePAM                            no
      X11Forwarding                     no
      PrintMotd                         no
      PubkeyAuthentication              yes
      PermitRootLogin                   yes
      PasswordAuthentication            yes
runcmd:
  - printenv > /tmp/env.txt
EOF
	if [ "$(command -v "yamlfmt")" != "" ];then
		yamlfmt "${dir}/user-data"
	fi
	touch "${dir}/meta-data" ;
	xorriso -as genisoimage \
			-joliet \
      -quiet \
			-volid "CIDATA" \
			-output "${iso}" \
			-rock "${dir}/user-data" "${dir}/meta-data" 
fi
# In case base archlinux image is less than 2 10 GB in size, increase it by 10 GBs
if [ "$(qemu-img info "${qcow}" | grep "virtual size" | awk "{print $3}")" -le 10 ]; then
	qemu-img resize "${qcow}" "+10G" ;
fi
# calculate VM Memory:
# alternative to:
# awk '/MemFree/ { printf "%.3f \n", $2/1024/1024 }' /proc/meminfo
# https://stackoverflow.com/questions/34937580/get-available-memory-in-gb-using-single-bash-shell-command
VM_MEM=$(($(getconf _AVPHYS_PAGES) * $(getconf PAGE_SIZE) / (1024 * 1024 * 1024)))
# If there is less than 2 GB of available memory, exit as we cannot launch the VM
if [ $VM_MEM -lt 2 ]; then
	echo "*** We need at least 2Gb of avaiable free memory to launch the VM"
	echo "Available free memory is "${VM_MEM}Gb""
	exit 1
fi
# If there is more than 2 GB of available memory, then set half of it for the VM
if [ $VM_MEM -gt 2 ]; then
	VM_MEM=$(( VM_MEM /2 ))
fi
# If half of available memory is less than 2 GB, then fall back to 2 GB default
if [ $VM_MEM -lt 2 ]; then
	VM_MEM=2
fi
VM_MEM=2;
# Allocate a quarter of available logical CPU cores for the VM
VM_CORES=$(("$(getconf _NPROCESSORS_ONLN)" / 4))
echo "*** starting "${VM_NAME}" archlinux based VM with "qemu". It can take up to ten minutes for "cloud-init" to finish configuration and installation of packages"
# ──────────────────────────────────────────────────────────────────────────────
# snippets
# List all starred vms with
# https://blog.stefan-koch.name/2020/05/24/managing-qemu-vms
# 
# ps -eo comm | grep ^qemu-vm-
# 
# ──────────────────────────────────────────────────────────────────────────────
# interact with qemu-monitor through UNIX socket
# https://unix.stackexchange.com/questions/426652/connect-to-running-qemu-instance-with-qemu-monitor
#
# socat -,echo=0,icanon=0 unix-connect:/tmp/qemu-monitor-socket
# ──────────────────────────────────────────────────────────────────────────────
# share host files into guest
# https://www.linux-kvm.org/page/9p_virtio
# https://wiki.qemu.org/Documentation/9psetup
# 
# sudo mount -t 9p -o trans=virtio,version=9p2000.L hostshare /mnt
# ──────────────────────────────────────────────────────────────────────────────
# ssh into guest
# 
# ssh -p 2222 -m "hmac-sha2-512" -o "StrictHostKeyChecking=no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null" 127.0.0.1
# ──────────────────────────────────────────────────────────────────────────────
	# -serial "mon:stdio" `# get ctrl-c to work` \
qemu-system-x86_64 \
	-daemonize \
	-nographic `# disable graphical output and redirect serial I/Os to console` \
	-display "none" \
	-chardev "stdio,mux=on,id=char0,logfile=/tmp/${VM_NAME}.log,signal=off" `# help writing output to file` \
	-mon chardev=char0 `# help writing output to file` \
	-serial chardev:char0 `# help writing output to file` \
	-monitor "unix:/tmp/qemu-monitor-socket-${VM_NAME},server,nowait" `# allow one to interact with qemu-monitor through UNIX socket` \
	-boot "order=d"  `# boot from cdrom` \
	-cdrom "${iso}" `# boot from cdrom` \
	-net "user" `# configure netwrok interface` \
	-nic "user,hostfwd=tcp::2222-:22,hostfwd=tcp::6443-:6443" `# map ssh and kubernetes ports from host to guest` \
  -smp "cpus=${VM_CORES}" `# set number of cores` \
	-m "${VM_MEM}G" `# allocate memory` \
	-virtfs "local,path="${workdir}",mount_tag=hostshare,security_model=none" `# allow for mounting a directory from host into guest, using "hostshare" tag` \
	-name "${VM_NAME},process=qemu-vm-${VM_NAME}"  `# set VM name and process name` \
	"${qcow}" ;

printf "Waiting for SSH to become available ..."
until sshpass -p 'arch' ssh \
		-p 2222 \
		-o "ConnectTimeout=10" \
		-m "hmac-sha2-512" \
		-o "StrictHostKeyChecking=no" \
		-o "CheckHostIP=no" \
		-o "UserKnownHostsFile=/dev/null" \
		"arch@127.0.0.1" -t "whoami && exit"  &>/dev/null; do
	printf "." ;
done
printf "Waiting unitl cloud-init is done configuring "${VM_NAME}" Guest ..."
sshpass -p 'arch' ssh \
		-p 2222 \
		-m "hmac-sha2-512" \
		-o "StrictHostKeyChecking=no" \
		-o "CheckHostIP=no" \
		-o "UserKnownHostsFile=/dev/null" \
		"arch@127.0.0.1" -t "cloud-init status --wait";
printf ""${VM_NAME}" Guest is ready ..."
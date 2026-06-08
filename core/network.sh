# PMStack Network — network configuration helpers
# Source: https://raw.githubusercontent.com/rsdenck/pmstore/main/core/network.sh

build_net_args() {
  local ip="$1" gw="$2"
  if [ "$ip" = "dhcp" ]; then
    echo "name=eth0,bridge=vmbr0,type=veth"
  else
    echo "name=eth0,bridge=vmbr0,gw=${gw},ip=${ip},type=veth"
  fi
}

config_ssh() {
  local ctid="$1" ssh_enabled="$2" ssh_port="${3:-22}"
  exec_lxc "$ctid" dnf install -y openssh-server
  exec_lxc "$ctid" sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
  exec_lxc "$ctid" sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
  if [ "$ssh_port" != "22" ]; then
    exec_lxc "$ctid" sed -i "s/^#*\\s*Port\\s\\+[0-9]\\+/Port ${ssh_port}/" /etc/ssh/sshd_config
  fi
  if [ "$ssh_enabled" = "false" ]; then
    exec_lxc "$ctid" systemctl disable sshd --now || true
  else
    exec_lxc "$ctid" systemctl enable sshd --now
  fi
}

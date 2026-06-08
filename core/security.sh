# PMStack Security — SOC hardening, sysctl, umask
# Source: https://raw.githubusercontent.com/rsdenck/pmstore/main/core/security.sh

apply_soc_hardening() {
  local ctid="$1"
  exec_lxc "$ctid" bash -c "cat > /etc/sysctl.d/99-soc-hardening.conf << 'SYSCTL'
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_syn_retries = 2
net.ipv4.conf.all.log_martians = 1
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 300
SYSCTL"
  exec_lxc "$ctid" sysctl -p /etc/sysctl.d/99-soc-hardening.conf
  exec_lxc "$ctid" bash -c 'echo "umask 027" >> /etc/profile.d/umask.sh'
  exec_lxc "$ctid" chmod 644 /etc/profile.d/umask.sh
}

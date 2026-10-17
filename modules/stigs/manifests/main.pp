# DISA STIG vulnerability IDs: none directly; this class aggregates the
# functional STIG classes listed below.
class stigs::main {
  if $facts['os']['family'] != 'RedHat' or $facts['os']['release']['major'] !~ /^(8|9|10)$/ {
    fail('stigs supports only RHEL 8, RHEL 9, and RHEL 10')
  }

  include stigs::audit
  include stigs::dconf
  include stigs::dnf
  include stigs::etc
  include stigs::firewalld
  include stigs::gdm
  include stigs::modprobe_d
  include stigs::networkmanager
  include stigs::pam
  include stigs::permissions
  include stigs::profile_d
  include stigs::security
  include stigs::selinux
  include stigs::ssh
  include stigs::sssd
  include stigs::sysctl_d
  include stigs::systemd
  include stigs::systemd_units
  include stigs::usbguard
  include stigs::packages
  include stigs::services

  Class['stigs::security'] -> Class['stigs::pam']
  Class['stigs::packages'] -> Class['stigs::services']
}

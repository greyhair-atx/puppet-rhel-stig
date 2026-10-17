# DISA STIG vulnerability IDs implemented by this class:
# RHEL 8: none directly
# RHEL 9:
#   V
# RHEL 10:
#   V-280965
class stigs::usbguard {
  file { 'stig directory /etc/usbguard':
    ensure => directory,
    path   => '/etc/usbguard',
  }
  if $facts['os']['release']['major'] =~ /^(9|10)$/ {
      file { 'stig /etc/usbguard/usbguard-daemon.conf':
        ensure       => file,
        path         => '/etc/usbguard/usbguard-daemon.conf',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/usbguard/usbguard-daemon.conf'),
        sourceselect => 'first',
      }
  }
}

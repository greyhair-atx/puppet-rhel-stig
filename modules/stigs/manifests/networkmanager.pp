# DISA STIG vulnerability IDs implemented by this class:
# RHEL 8: none directly
# RHEL 9:
#   V
# RHEL 10:
#   V-281362
class stigs::networkmanager {
  file { 'stig directory /etc/NetworkManager':
    ensure => directory,
    path   => '/etc/NetworkManager',
  }
  if $facts['os']['release']['major'] =~ /^(9|10)$/ {
      file { 'stig /etc/NetworkManager/NetworkManager.conf':
        ensure       => file,
        path         => '/etc/NetworkManager/NetworkManager.conf',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/NetworkManager/NetworkManager.conf'),
        sourceselect => 'first',
      }
  }
}

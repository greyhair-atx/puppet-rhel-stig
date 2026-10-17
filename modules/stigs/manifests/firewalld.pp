# DISA STIG vulnerability IDs implemented by this class:
# RHEL 8: none directly
# RHEL 9:
#   V
# RHEL 10:
#   V-281361
class stigs::firewalld {
  file { 'stig directory /etc/firewalld':
    ensure => directory,
    path   => '/etc/firewalld',
  }
  if $facts['os']['release']['major'] =~ /^(9|10)$/ {
      file { 'stig /etc/firewalld/firewalld.conf':
        ensure       => file,
        path         => '/etc/firewalld/firewalld.conf',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/firewalld/firewalld.conf'),
        sourceselect => 'first',
      }
  }
}

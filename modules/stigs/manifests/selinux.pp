# DISA STIG vulnerability IDs implemented by this class:
# RHEL 8:
#   V-230240, V-230282
# RHEL 9:
#   V-258078, V-258079
# RHEL 10:
#   V-281249, V-281251
class stigs::selinux {
  file { 'stig directory /etc/selinux':
    ensure => directory,
    path   => '/etc/selinux',
  }
  file { 'stig /etc/selinux/config':
    ensure       => file,
    path         => '/etc/selinux/config',
    owner        => 'root',
    group        => 'root',
    mode         => '0644',
    source       => stigs::source_candidates('puppet:///modules/stigs/selinux/config'),
    sourceselect => 'first',
  }
}

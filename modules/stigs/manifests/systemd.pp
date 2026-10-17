# DISA STIG vulnerability IDs implemented by this class:
# RHEL 8:
#   V-230314, V-230315, V-230531
# RHEL 9:
#   V-257784, V-257812, V-257813
# RHEL 10:
#   V-281298, V-281317, V-281318
class stigs::systemd {
  file { 'stig directory /etc/systemd':
    ensure => directory,
    path   => '/etc/systemd',
  }
  file { 'stig directory /etc/systemd/system.conf.d':
    ensure => directory,
    path   => '/etc/systemd/system.conf.d',
  }
  if $facts['os']['release']['major'] =~ /^(8|9|10)$/ {
    file { 'stig /etc/systemd/coredump.conf':
      ensure       => file,
      path         => '/etc/systemd/coredump.conf',
      owner        => 'root',
      group        => 'root',
      mode         => '0644',
      source       => stigs::source_candidates('puppet:///modules/stigs/systemd/coredump.conf'),
      sourceselect => 'first',
      notify       => Exec['systemd daemon reload'],
    }
  }
  file { 'stig /etc/systemd/system.conf.d/55-CtrlAltDel-BurstAction.conf':
    ensure       => file,
    path         => '/etc/systemd/system.conf.d/55-CtrlAltDel-BurstAction.conf',
    owner        => 'root',
    group        => 'root',
    mode         => '0644',
    source       => stigs::source_candidates('puppet:///modules/stigs/systemd/system.conf.d/55-CtrlAltDel-BurstAction.conf'),
    sourceselect => 'first',
    notify       => Exec['systemd daemon reload'],
  }
}

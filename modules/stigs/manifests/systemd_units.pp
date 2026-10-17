# DISA STIG vulnerability IDs implemented by this class:
# RHEL 8:
#   V-230236, V-244523
# RHEL 9:
#   V
# RHEL 10:
#   V-281327, V-281328
class stigs::systemd_units {
  file { 'stig directory /usr/lib/systemd/system':
    ensure => directory,
    path   => '/usr/lib/systemd/system',
  }
  if $facts['os']['release']['major'] =~ /^(8|9|10)$/ {
    file { 'stig /usr/lib/systemd/system/emergency.service':
      ensure       => file,
      path         => '/usr/lib/systemd/system/emergency.service',
      owner        => 'root',
      group        => 'root',
      mode         => '0644',
      source       => stigs::source_candidates('puppet:///modules/stigs/usr/lib/systemd/system/emergency.service'),
      sourceselect => 'first',
      notify       => Exec['systemd daemon reload'],
    }
    file { 'stig /usr/lib/systemd/system/rescue.service':
      ensure       => file,
      path         => '/usr/lib/systemd/system/rescue.service',
      owner        => 'root',
      group        => 'root',
      mode         => '0644',
      source       => stigs::source_candidates('puppet:///modules/stigs/usr/lib/systemd/system/rescue.service'),
      sourceselect => 'first',
      notify       => Exec['systemd daemon reload'],
    }
  }
}

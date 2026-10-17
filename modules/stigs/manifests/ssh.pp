# DISA STIG vulnerability IDs implemented by this class:
# RHEL 8:
#   V-230225, V-230244, V-230288, V-230290, V-230291, V-230296, V-230330, V-230382
#   V-230527, V-230555, V-230556, V-244525, V-244528
# RHEL 9:
#   V-257981, V-257982, V-257983, V-257984, V-257985, V-257986, V-257992, V-257993
#   V-257994, V-257995, V-257996, V-257997, V-257998, V-258003, V-258004, V-258005
#   V-258006, V-258007, V-258008, V-258009, V-258011
# RHEL 10:
#   V-281115, V-281216, V-281224, V-281254, V-281255, V-281256, V-281257, V-281258
#   V-281259, V-281260, V-281261, V-281263, V-281264, V-281265, V-281266, V-281267
#   V-281268, V-281269, V-281296
class stigs::ssh {
  file { 'stig directory /etc/ssh':
    ensure => directory,
    path   => '/etc/ssh',
  }
  case $facts['os']['release']['major'] {
    '8': {
      file { 'stig /etc/ssh/sshd_config':
        ensure       => file,
        path         => '/etc/ssh/sshd_config',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/ssh/sshd_config'),
        sourceselect => 'first',
        notify       => Service['sshd.service'],
      }
    }
    '9': {
      file { 'stig /etc/ssh/sshd_config':
        ensure       => file,
        path         => '/etc/ssh/sshd_config',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/ssh/sshd_config'),
        sourceselect => 'first',
        notify       => Service['sshd.service'],
      }
    }
    '10': {
      file { 'stig /etc/ssh/sshd_config':
        ensure       => file,
        path         => '/etc/ssh/sshd_config',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/ssh/sshd_config'),
        sourceselect => 'first',
        validate_cmd => '/usr/sbin/sshd -t -f %',
        notify       => Exec['reload sshd configuration'],
      }
    }
    default: {
      fail('stigs::ssh supports RHEL major versions 8, 9, and 10 only')
    }
  }
}

# DISA STIG vulnerability IDs implemented by this class:
# RHEL 8:
#   V-230227, V-230228, V-230231, V-230233, V-230324, V-230365, V-230366, V-230370
#   V-230378, V-230383, V-230387, V-230389, V-230481, V-230482
# RHEL 9:
#   V-257779, V-257946, V-257947, V-258041, V-258043, V-258071, V-258072, V-258073
#   V-258074, V-258075, V-258084, V-258104, V-258116, V-258117, V-258121, V-258144
#   V-258146, V-258147, V-258148, V-258150
# RHEL 10:
#   V-280960, V-280961, V-280985, V-280986, V-280990, V-280991, V-281080, V-281081
#   V-281082, V-281083, V-281169, V-281171, V-281179, V-281180, V-281208, V-281209
#   V-281210, V-281211, V-281222, V-281223, V-281224, V-281227, V-281270, V-281336
class stigs::etc {
  file { 'stig directory /etc':
    ensure => directory,
    path   => '/etc',
  }
  if $facts['os']['release']['major'] == '8' {
      file { 'stig /etc/aliases':
        ensure       => file,
        path         => '/etc/aliases',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/etc/aliases'),
        sourceselect => 'first',
      }
  }
  if $facts['os']['release']['major'] == '10' {
    file { 'stig /etc/aliases':
      ensure       => file,
      path         => '/etc/aliases',
      owner        => 'root',
      group        => 'root',
      mode         => '0644',
      source       => stigs::source_candidates('puppet:///modules/stigs/etc/aliases'),
      sourceselect => 'first',
    }
  }
  if $facts['os']['release']['major'] == '9' {
      file { 'stig /etc/bashrc':
        ensure       => file,
        path         => '/etc/bashrc',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/etc/bashrc'),
        sourceselect => 'first',
      }
  }
  if $facts['os']['release']['major'] == '10' {
    file { 'stig /etc/bashrc':
      ensure       => file,
      path         => '/etc/bashrc',
      owner        => 'root',
      group        => 'root',
      mode         => '0644',
      source       => stigs::source_candidates('puppet:///modules/stigs/etc/bashrc'),
      sourceselect => 'first',
    }
  }
  if $facts['os']['release']['major'] == '9' {
      file { 'stig /etc/chrony.conf':
        ensure       => file,
        path         => '/etc/chrony.conf',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/etc/chrony.conf'),
        sourceselect => 'first',
      }
  }
  if $facts['os']['release']['major'] == '10' {
    file { 'stig /etc/chrony.conf':
      ensure       => file,
      path         => '/etc/chrony.conf',
      owner        => 'root',
      group        => 'root',
      mode         => '0644',
      source       => stigs::source_candidates('puppet:///modules/stigs/etc/chrony.conf'),
      sourceselect => 'first',
    }
  }
  if $facts['os']['release']['major'] =~ /^(9|10)$/ {
      file { 'stig /etc/csh.cshrc':
        ensure       => file,
        path         => '/etc/csh.cshrc',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/etc/csh.cshrc'),
        sourceselect => 'first',
      }
  }
  file { 'stig /etc/issue':
    ensure       => file,
    path         => '/etc/issue',
    owner        => 'root',
    group        => 'root',
    mode         => '0644',
    source       => stigs::source_candidates('puppet:///modules/stigs/etc/issue'),
    sourceselect => 'first',
  }
  if $facts['os']['release']['major'] == '9' {
      file { 'stig /etc/libuser.conf':
        ensure       => file,
        path         => '/etc/libuser.conf',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/etc/libuser.conf'),
        sourceselect => 'first',
      }
  }
  if $facts['os']['release']['major'] == '10' {
    file { 'stig /etc/libuser.conf':
      ensure       => file,
      path         => '/etc/libuser.conf',
      owner        => 'root',
      group        => 'root',
      mode         => '0644',
      source       => stigs::source_candidates('puppet:///modules/stigs/etc/libuser.conf'),
      sourceselect => 'first',
    }
  }
  case $facts['os']['release']['major'] {
    '8': {
      file { 'stig /etc/login.defs':
        ensure       => file,
        path         => '/etc/login.defs',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/etc/login.defs'),
        sourceselect => 'first',
      }
    }
    '9': {
      file { 'stig /etc/login.defs':
        ensure       => file,
        path         => '/etc/login.defs',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/etc/login.defs'),
        sourceselect => 'first',
      }
    }
    '10': {
      file { 'stig /etc/login.defs':
        ensure       => file,
        path         => '/etc/login.defs',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/etc/login.defs'),
        sourceselect => 'first',
      }
    }
    default: {
      fail('stigs::etc supports RHEL major versions 8, 9, and 10 only')
    }
  }
  if $facts['os']['release']['major'] == '9' {
      file { 'stig /etc/opensc.conf':
        ensure       => file,
        path         => '/etc/opensc.conf',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/etc/opensc.conf'),
        sourceselect => 'first',
      }
  }
  if $facts['os']['release']['major'] == '10' {
    file { 'stig /etc/profile':
      ensure       => file,
      path         => '/etc/profile',
      owner        => 'root',
      group        => 'root',
      mode         => '0644',
      source       => stigs::source_candidates('puppet:///modules/stigs/etc/profile'),
      sourceselect => 'first',
    }
  }
  if $facts['os']['release']['major'] == '9' {
      file { 'stig /etc/profile':
        ensure       => file,
        path         => '/etc/profile',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/etc/profile'),
        sourceselect => 'first',
      }
  }
  case $facts['os']['release']['major'] {
    '8': {
      file { 'stig /etc/rsyslog.conf':
        ensure       => file,
        path         => '/etc/rsyslog.conf',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/etc/rsyslog.conf'),
        sourceselect => 'first',
        notify       => Service['rsyslog.service'],
      }
    }
    '9': {
      file { 'stig /etc/rsyslog.conf':
        ensure       => file,
        path         => '/etc/rsyslog.conf',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/etc/rsyslog.conf'),
        sourceselect => 'first',
        notify       => Service['rsyslog.service'],
      }
    }
    '10': {
      file { 'stig /etc/rsyslog.conf':
        ensure       => file,
        path         => '/etc/rsyslog.conf',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/etc/rsyslog.conf'),
        sourceselect => 'first',
        validate_cmd => '/usr/sbin/rsyslogd -N1 -f %',
        notify       => Exec['reload rsyslog configuration'],
      }
    }
    default: {
      fail('stigs::etc supports RHEL major versions 8, 9, and 10 only')
    }
  }
  if $facts['os']['release']['major'] =~ /^(9|10)$/ {
      file { 'stig /etc/sudoers':
        ensure       => file,
        path         => '/etc/sudoers',
        owner        => 'root',
        group        => 'root',
        mode         => '0440',
        source       => stigs::source_candidates('puppet:///modules/stigs/etc/sudoers'),
        sourceselect => 'first',
        validate_cmd => '/usr/sbin/visudo -cf %',
      }
  }
}

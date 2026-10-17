# @summary
#   Manages the main logrotate configuration and the rsyslog rotation policy.
class custom::logrotate {
  if $facts['os']['family'] != 'RedHat' {
    fail('custom::logrotate supports only Red Hat family operating systems')
  }

  case $facts['os']['release']['major'] {
    '8', '9', '10': { }
    default: {
      fail('custom::logrotate supports RHEL major versions 8, 9, and 10 only')
    }
  }

  file { 'custom logrotate configuration directory':
    ensure => directory,
    path   => '/etc/logrotate.d',
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  file { 'custom /etc/logrotate.conf':
    ensure       => file,
    path         => '/etc/logrotate.conf',
    owner        => 'root',
    group        => 'root',
    mode         => '0644',
    source       => custom::source_candidates('puppet:///modules/custom/etc/logrotate.conf'),
    sourceselect => 'first',
  }

  file { 'custom /etc/logrotate.d/rsyslog':
    ensure       => file,
    path         => '/etc/logrotate.d/rsyslog',
    owner        => 'root',
    group        => 'root',
    mode         => '0644',
    source       => custom::source_candidates('puppet:///modules/custom/etc/logrotate.d/rsyslog'),
    sourceselect => 'first',
    require      => File['custom logrotate configuration directory'],
  }
}

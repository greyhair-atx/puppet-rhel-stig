# @summary
#   Runs Puppet on a business-hours-aware systemd timer.
class custom::puppet_timer {
  if $facts['os']['family'] != 'RedHat' {
    fail('custom::puppet_timer supports only Red Hat family operating systems')
  }

  case $facts['os']['release']['major'] {
    '8', '9', '10': { }
    default: {
      fail('custom::puppet_timer supports RHEL major versions 8, 9, and 10 only')
    }
  }

  file { 'custom systemd unit directory':
    ensure => directory,
    path   => '/etc/systemd/system',
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  file { 'custom Puppet agent service unit':
    ensure       => file,
    path         => '/etc/systemd/system/ces-puppet-agent-run.service',
    owner        => 'root',
    group        => 'root',
    mode         => '0644',
    source       => custom::source_candidates('puppet:///modules/custom/puppet_timer/ces-puppet-agent-run.service'),
    sourceselect => 'first',
    require      => File['custom systemd unit directory'],
    notify       => Exec['reload custom systemd units'],
  }

  file { 'custom Puppet agent timer unit':
    ensure       => file,
    path         => '/etc/systemd/system/ces-puppet-agent-run.timer',
    owner        => 'root',
    group        => 'root',
    mode         => '0644',
    source       => custom::source_candidates('puppet:///modules/custom/puppet_timer/ces-puppet-agent-run.timer'),
    sourceselect => 'first',
    require      => File['custom systemd unit directory'],
    notify       => Exec['reload custom systemd units'],
  }

  exec { 'reload custom systemd units':
    command     => '/usr/bin/systemctl daemon-reload',
    refreshonly => true,
    notify      => Service['ces-puppet-agent-run.timer'],
  }

  service { 'ces-puppet-agent-run.timer':
    ensure  => running,
    enable  => true,
    require => Exec['reload custom systemd units'],
  }
}

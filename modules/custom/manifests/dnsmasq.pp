# @summary
#   Installs dnsmasq and selects configuration by trusted network, project, role, and certname.
class custom::dnsmasq {
  if $facts['os']['family'] != 'RedHat' or $facts['os']['release']['major'] !~ /^(8|9|10)$/ {
    fail('custom::dnsmasq supports only RHEL 8, RHEL 9, and RHEL 10')
  }

  include custom::rpm_install

  if 'dnsmasq' in $custom::rpm_install::xrpms {
    fail('custom::dnsmasq cannot be used when dnsmasq is in custom::rpm_install::xrpms')
  }

  # Including rpm_install first makes package ownership independent of class order.
  if !('dnsmasq' in $custom::rpm_install::rpms) {
    package { 'dnsmasq':
      ensure => installed,
    }
  }

  file { 'custom dnsmasq configuration directory':
    ensure  => directory,
    path    => '/etc/dnsmasq.d',
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    require => Package['dnsmasq'],
  }

  file { 'custom /etc/dnsmasq.conf':
    ensure       => file,
    path         => '/etc/dnsmasq.conf',
    owner        => 'root',
    group        => 'root',
    mode         => '0644',
    source       => custom::source_candidates('puppet:///modules/custom/dnsmasq/dnsmasq.conf'),
    sourceselect => 'first',
    require      => Package['dnsmasq'],
    notify       => Service['dnsmasq'],
  }

  file { 'custom /etc/dnsmasq.d/custom.conf':
    ensure       => file,
    path         => '/etc/dnsmasq.d/custom.conf',
    owner        => 'root',
    group        => 'root',
    mode         => '0644',
    source       => custom::source_candidates('puppet:///modules/custom/dnsmasq/dnsmasq.d/custom.conf'),
    sourceselect => 'first',
    require      => File['custom dnsmasq configuration directory'],
    notify       => Service['dnsmasq'],
  }

  service { 'dnsmasq':
    ensure  => running,
    enable  => true,
    require => [
      Package['dnsmasq'],
      File['custom /etc/dnsmasq.conf'],
      File['custom /etc/dnsmasq.d/custom.conf'],
    ],
  }
}

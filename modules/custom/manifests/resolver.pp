# @summary
#   Manages static resolver configuration supplied through Hiera.
#
# @param site_defaults
#   Default nameservers and optional search domains from the site/network Hiera
#   file.
# @param project_overrides
#   Explicit project overrides. Omitted keys retain their site default. An
#   empty custom_search array disables the search line.
class custom::resolver (
  Optional[Struct[{
    'custom_ns'               => Array[String[1], 1],
    Optional['custom_search'] => Array[String[1]],
  }]] $site_defaults = undef,
  Struct[{
    Optional['custom_ns']     => Array[String[1], 1],
    Optional['custom_search'] => Array[String[1]],
  }] $project_overrides = {},
) {
  if $facts['os']['family'] != 'RedHat' {
    fail('custom::resolver supports only Red Hat family operating systems')
  }

  case $facts['os']['release']['major'] {
    '8', '9', '10': { }
    default: {
      fail('custom::resolver supports RHEL major versions 8, 9, and 10 only')
    }
  }

  if $site_defaults == undef {
    fail('custom::resolver::site_defaults must be set in environment Hiera data')
  }

  $effective_settings = $site_defaults + $project_overrides
  $effective_search = $effective_settings['custom_search'] ? {
    undef   => [],
    default => $effective_settings['custom_search'],
  }

  file { 'custom NetworkManager configuration directory':
    ensure => directory,
    path   => '/etc/NetworkManager/conf.d',
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  file { 'custom NetworkManager static DNS configuration':
    ensure  => file,
    path    => '/etc/NetworkManager/conf.d/90-dns-none.conf',
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => "# Managed by Puppet.\n[main]\ndns=none\nrc-manager=unmanaged\n",
    require => File['custom NetworkManager configuration directory'],
  }

  file { 'custom /etc/resolv.conf':
    ensure  => file,
    path    => '/etc/resolv.conf',
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('custom/resolv.conf.epp', {
      'nameservers'    => $effective_settings['custom_ns'],
      'search_domains' => $effective_search,
    }),
    require => File['custom NetworkManager static DNS configuration'],
  }
}

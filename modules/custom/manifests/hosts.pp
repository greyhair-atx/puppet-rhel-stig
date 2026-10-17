# @summary
#   Maintains the workstation and controlled host records in /etc/hosts.
#
# @param site_defaults
#   The OpenVox server and optional additional host records for this site and
#   network.
# @param project_overrides
#   Explicit project overrides. Omitted keys retain their site/network default.
#   An empty additional_entries array removes the site/network additional list.
# @param workstation_entry
#   The workstation entry. Its IP address, FQDN, and hostname default to facts.
class custom::hosts (
  Optional[Struct[{
    'openvox_entry'                => Custom::HostEntry,
    Optional['additional_entries'] => Array[Custom::HostEntry],
  }]] $site_defaults = undef,
  Struct[{
    Optional['openvox_entry']      => Custom::HostEntry,
    Optional['additional_entries'] => Array[Custom::HostEntry],
  }] $project_overrides = {},
  Custom::HostEntry $workstation_entry = {
    'ip'       => $facts['networking']['ip'],
    'fqdn'     => $facts['networking']['fqdn'],
    'hostname' => $facts['networking']['hostname'],
  },
) {
  if $site_defaults == undef {
    fail('custom::hosts::site_defaults must be set in environment Hiera data')
  }

  $effective_settings = $site_defaults + $project_overrides
  $additional_entries = $effective_settings['additional_entries'] ? {
    undef   => [],
    default => $effective_settings['additional_entries'],
  }
  $host_entries = [
    $workstation_entry,
    $effective_settings['openvox_entry'],
  ] + $additional_entries
  $records = $host_entries.map |Custom::HostEntry $entry| {
    $host_alias = $entry['alias'] ? {
      undef   => '',
      default => $entry['alias'],
    }
    [$entry['ip'], $entry['fqdn'], $entry['hostname'], $host_alias].join("\t")
  }
  $records_text = $records.join("\n")
  $records_content = "${records_text}\n"

  file { 'CES Puppet hosts configuration directory':
    ensure => directory,
    path   => '/etc/ces-puppet',
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  file { 'CES Puppet hosts records':
    ensure  => file,
    path    => '/etc/ces-puppet/hosts.records',
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    content => $records_content,
    require => File['CES Puppet hosts configuration directory'],
  }

  file { 'CES Puppet hosts helper':
    ensure       => file,
    path         => '/usr/local/sbin/ces-puppet-hosts',
    owner        => 'root',
    group        => 'root',
    mode         => '0755',
    source       => custom::source_candidates('puppet:///modules/custom/ces-puppet-hosts.rb'),
    sourceselect => 'first',
  }

  exec { 'apply CES Puppet hosts records':
    command   => '/usr/local/sbin/ces-puppet-hosts --apply /etc/hosts /etc/ces-puppet/hosts.records',
    unless    => '/usr/local/sbin/ces-puppet-hosts --check /etc/hosts /etc/ces-puppet/hosts.records',
    path      => ['/usr/bin', '/bin'],
    logoutput => 'on_failure',
    require   => [
      File['CES Puppet hosts records'],
      File['CES Puppet hosts helper'],
    ],
  }
}

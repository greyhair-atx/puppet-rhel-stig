# DISA STIG vulnerability IDs implemented by this class:
# RHEL 8:
#   V
# RHEL 9: none directly
# RHEL 10:
#   V-281275
class stigs::gdm {
  file { 'stig directory /etc/gdm':
    ensure => directory,
    path   => '/etc/gdm',
  }
  if $facts['os']['release']['major'] =~ /^(8|10)$/ {
      file { 'stig /etc/gdm/custom.conf':
        ensure       => file,
        path         => '/etc/gdm/custom.conf',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/gdm/custom.conf'),
        sourceselect => 'first',
      }
  }
}

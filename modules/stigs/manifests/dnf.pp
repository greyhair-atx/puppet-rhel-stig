# DISA STIG vulnerability IDs implemented by this class:
# RHEL 8:
#   V-230265, V-230281
# RHEL 9:
#   V-257820, V-257821, V-257824
# RHEL 10:
#   V-280932, V-280933, V-280942
class stigs::dnf {
  file { 'stig directory /etc/dnf':
    ensure => directory,
    path   => '/etc/dnf',
  }
  case $facts['os']['release']['major'] {
    '8': {
      file { 'stig /etc/dnf/dnf.conf':
        ensure       => file,
        path         => '/etc/dnf/dnf.conf',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/dnf/dnf.conf'),
        sourceselect => 'first',
      }
    }
    '9': {
      file { 'stig /etc/dnf/dnf.conf':
        ensure       => file,
        path         => '/etc/dnf/dnf.conf',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/dnf/dnf.conf'),
        sourceselect => 'first',
      }
    }
    '10': {
      file { 'stig /etc/dnf/dnf.conf':
        ensure       => file,
        path         => '/etc/dnf/dnf.conf',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/dnf/dnf.conf'),
        sourceselect => 'first',
      }
    }
    default: {
      fail('stigs::dnf supports RHEL major versions 8, 9, and 10 only')
    }
  }
}

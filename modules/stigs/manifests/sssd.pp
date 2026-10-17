# DISA STIG vulnerability IDs implemented by this class:
# RHEL 8:
#   V-230274, V-230369
# RHEL 9:
#   V-258122, V-258123, V-258133
# RHEL 10:
#   V-281324, V-281325, V-281331
class stigs::sssd {
  file { 'stig directory /etc/sssd':
    ensure => directory,
    path   => '/etc/sssd',
  }
  file { 'stig directory /etc/sssd/conf.d':
    ensure => directory,
    path   => '/etc/sssd/conf.d',
  }
  case $facts['os']['release']['major'] {
    '8': {
      file { 'stig /etc/sssd/conf.d/certificate_verification.conf':
        ensure       => file,
        path         => '/etc/sssd/conf.d/certificate_verification.conf',
        owner        => 'root',
        group        => 'root',
        mode         => '0600',
        source       => stigs::source_candidates('puppet:///modules/stigs/sssd/conf.d/certificate_verification.conf'),
        sourceselect => 'first',
      }
    }
    '9': {
      file { 'stig /etc/sssd/conf.d/certificate_verification.conf':
        ensure       => file,
        path         => '/etc/sssd/conf.d/certificate_verification.conf',
        owner        => 'root',
        group        => 'root',
        mode         => '0600',
        source       => stigs::source_candidates('puppet:///modules/stigs/sssd/conf.d/certificate_verification.conf'),
        sourceselect => 'first',
      }
    }
    '10': {
      file { 'stig /etc/sssd/conf.d/certificate_verification.conf':
        ensure       => file,
        path         => '/etc/sssd/conf.d/certificate_verification.conf',
        owner        => 'root',
        group        => 'root',
        mode         => '0600',
        source       => stigs::source_candidates('puppet:///modules/stigs/sssd/conf.d/certificate_verification.conf'),
        sourceselect => 'first',
        notify       => Exec['validate and restart sssd'],
      }
    }
    default: {
      fail('stigs::sssd supports RHEL major versions 8, 9, and 10 only')
    }
  }
  file { 'stig /etc/sssd/sssd.conf':
    ensure       => file,
    path         => '/etc/sssd/sssd.conf',
    owner        => 'root',
    group        => 'root',
    mode         => '0600',
    source       => stigs::source_candidates('puppet:///modules/stigs/sssd/sssd.conf'),
    sourceselect => 'first',
    notify       => $facts['os']['release']['major'] ? {
      '10'    => Exec['validate and restart sssd'],
      default => undef,
    },
  }
}

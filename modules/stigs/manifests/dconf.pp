# DISA STIG vulnerability IDs implemented by this class:
# RHEL 8:
#   V-230226, V-230347, V-230352, V-230354, V-244519, V-244535, V-244536, V-244538
#   V-244539
# RHEL 9:
#   V-258012, V-258013, V-258014, V-258015, V-258016, V-258017, V-258019, V-258020
#   V-258021, V-258022, V-258023, V-258024, V-258025, V-258026, V-258027, V-258030
#   V-258031, V-258032, V-258033
# RHEL 10:
#   V-281225, V-281226, V-281273, V-281274, V-281276, V-281277, V-281278, V-281279
#   V-281280, V-281281, V-281282, V-281284, V-281285, V-281286, V-281287, V-281291
#   V-281292
class stigs::dconf {
  file { 'stig directory /etc/dconf':
    ensure => directory,
    path   => '/etc/dconf',
  }
  file { 'stig directory /etc/dconf/db':
    ensure => directory,
    path   => '/etc/dconf/db',
  }
  file { 'stig directory /etc/dconf/db/local.d':
    ensure => directory,
    path   => '/etc/dconf/db/local.d',
  }
  file { 'stig directory /etc/dconf/db/local.d/locks':
    ensure => directory,
    path   => '/etc/dconf/db/local.d/locks',
  }
  file { 'stig /etc/dconf/db/local.d/00-screensaver':
    ensure       => file,
    path         => '/etc/dconf/db/local.d/00-screensaver',
    owner        => 'root',
    group        => 'root',
    mode         => '0644',
    source       => stigs::source_candidates('puppet:///modules/stigs/dconf/db/local.d/00-screensaver'),
    sourceselect => 'first',
    notify       => Exec['update dconf database'],
  }
  if $facts['os']['release']['major'] =~ /^(9|10)$/ {
      file { 'stig /etc/dconf/db/local.d/00-security-settings':
        ensure       => file,
        path         => '/etc/dconf/db/local.d/00-security-settings',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/dconf/db/local.d/00-security-settings'),
        sourceselect => 'first',
        notify       => Exec['update dconf database'],
      }
  }
  if $facts['os']['release']['major'] == '10' {
    file { 'stig /etc/dconf/db/local.d/00-media-keys':
      ensure       => file,
      path         => '/etc/dconf/db/local.d/00-media-keys',
      owner        => 'root',
      group        => 'root',
      mode         => '0644',
      source       => stigs::source_candidates('puppet:///modules/stigs/dconf/db/local.d/00-media-keys'),
      sourceselect => 'first',
      notify       => Exec['update dconf database'],
    }
  }
  file { 'stig /etc/dconf/db/local.d/01-banner-message':
    ensure       => file,
    path         => '/etc/dconf/db/local.d/01-banner-message',
    owner        => 'root',
    group        => 'root',
    mode         => '0644',
    source       => stigs::source_candidates('puppet:///modules/stigs/dconf/db/local.d/01-banner-message'),
    sourceselect => 'first',
    notify       => Exec['update dconf database'],
  }
  file { 'stig /etc/dconf/db/local.d/02-login-screen':
    ensure       => file,
    path         => '/etc/dconf/db/local.d/02-login-screen',
    owner        => 'root',
    group        => 'root',
    mode         => '0644',
    source       => stigs::source_candidates('puppet:///modules/stigs/dconf/db/local.d/02-login-screen'),
    sourceselect => 'first',
    notify       => Exec['update dconf database'],
  }
  if $facts['os']['release']['major'] =~ /^(9|10)$/ {
      file { 'stig /etc/dconf/db/local.d/locks/00-security-settings-lock':
        ensure       => file,
        path         => '/etc/dconf/db/local.d/locks/00-security-settings-lock',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/dconf/db/local.d/locks/00-security-settings-lock'),
        sourceselect => 'first',
        notify       => Exec['update dconf database'],
      }
  }
  case $facts['os']['release']['major'] {
    '8': {
      file { 'stig /etc/dconf/db/local.d/locks/session':
        ensure       => file,
        path         => '/etc/dconf/db/local.d/locks/session',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/dconf/db/local.d/locks/session'),
        sourceselect => 'first',
        notify       => Exec['update dconf database'],
      }
    }
    '9': {
      file { 'stig /etc/dconf/db/local.d/locks/session':
        ensure       => file,
        path         => '/etc/dconf/db/local.d/locks/session',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/dconf/db/local.d/locks/session'),
        sourceselect => 'first',
        notify       => Exec['update dconf database'],
      }
    }
    '10': {
      file { 'stig /etc/dconf/db/local.d/locks/session':
        ensure       => file,
        path         => '/etc/dconf/db/local.d/locks/session',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/dconf/db/local.d/locks/session'),
        sourceselect => 'first',
        notify       => Exec['update dconf database'],
      }
    }
    default: {
      fail('stigs::dconf supports RHEL major versions 8, 9, and 10 only')
    }
  }
}

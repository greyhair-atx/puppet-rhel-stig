# @summary
#   Creates the shared dconf directories and refresh command used by this module.
class custom::dconf {
  file { 'custom dconf directory':
    ensure => directory,
    path   => '/etc/dconf',
  }

  file { 'custom dconf database directory':
    ensure => directory,
    path   => '/etc/dconf/db',
  }

  file { 'custom gdm dconf directory':
    ensure => directory,
    path   => '/etc/dconf/db/gdm.d',
  }

  file { 'custom gdm dconf locks directory':
    ensure => directory,
    path   => '/etc/dconf/db/gdm.d/locks',
  }

  file { 'custom local dconf directory':
    ensure => directory,
    path   => '/etc/dconf/db/local.d',
  }

  file { 'custom local dconf locks directory':
    ensure => directory,
    path   => '/etc/dconf/db/local.d/locks',
  }

  exec { 'update custom dconf databases':
    command     => '/usr/bin/dconf update',
    refreshonly => true,
    require     => [
      File['custom gdm dconf directory'],
      File['custom gdm dconf locks directory'],
      File['custom local dconf directory'],
      File['custom local dconf locks directory'],
    ],
  }
}

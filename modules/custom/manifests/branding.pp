# @summary
#   Installs a site logo and applies it to the GNOME login screen.
#
# @param manage_gui
#   Whether to manage graphical branding. Defaults to the custom_gui fact.
# @param logo_source
#   Default Puppet source URI for the common logo image.
# @param logo_path
#   Absolute destination path for the logo on managed systems.
class custom::branding (
  Boolean   $manage_gui  = $facts['custom_gui'] ? {
    true    => true,
    default => false,
  },
  String[1] $logo_source = 'puppet:///modules/custom/branding/corp-logo.png',
  String[1] $logo_path   = '/usr/local/share/corp/corp-logo.png',
) {
  if $facts['os']['family'] != 'RedHat' or $facts['os']['release']['major'] !~ /^(8|9|10)$/ {
    fail('custom::branding supports only RHEL 8, RHEL 9, and RHEL 10')
  }

  if $manage_gui {
    contain custom::dconf

    file { 'custom branding directory':
      ensure => directory,
      path   => '/usr/local/share/corp',
      owner  => 'root',
      group  => 'root',
      mode   => '0755',
    }

    file { 'custom branding logo':
      ensure       => file,
      path         => $logo_path,
      owner        => 'root',
      group        => 'root',
      mode         => '0644',
      source       => custom::source_candidates($logo_source),
      sourceselect => 'first',
      require      => File['custom branding directory'],
    }

    file { 'custom gdm logo configuration':
      ensure  => file,
      path    => '/etc/dconf/db/gdm.d/01-override-logo',
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => epp('custom/override-logo.epp', {
        'logo_path' => $logo_path,
      }),
      require => File['custom branding logo'],
      notify  => Exec['update custom dconf databases'],
    }

    file { 'custom gdm logo lock':
      ensure  => file,
      path    => '/etc/dconf/db/gdm.d/locks/01-override-logo',
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => "# Managed by corp Puppet.\n# Manual changes will be replaced.\n/org/gnome/login-screen/logo\n",
      notify  => Exec['update custom dconf databases'],
    }
  }
}

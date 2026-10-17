# @summary
#   Installs and configures GNOME classification banners by trusted network.
#
# @param manage_gui
#   Whether to manage the graphical banner. Defaults to the custom_gui fact.
# @param pp_network
#   Network profile name. Defaults to the pp_network trusted extension.
# @param network_profiles
#   Banner settings keyed by the pp_network trusted extension.
class custom::classification_banner (
  Boolean $manage_gui = $facts['custom_gui'] ? {
    true    => true,
    default => false,
  },
  Optional[String] $pp_network = $trusted['extensions']['pp_network'],
  Hash[Enum['network1', 'network2', 'network3', 'network4'], Struct[{
    'background_color' => String[1],
    'message'          => String[1],
    'top_banner'       => Boolean,
    'bottom_banner'    => Boolean,
    'system_info'      => Boolean,
    'color'            => String[1],
  }]] $network_profiles = {
    'network1' => {
      'background_color' => 'rgba(200,16,46,0.75)',
      'message'          => 'Network 1 Banner message',
      'top_banner'       => true,
      'bottom_banner'    => false,
      'system_info'      => true,
      'color'            => 'rgb(255,255,255)',
    },
    'network2' => {
      'background_color' => 'rgba(200,16,46,0.75)',
      'message'          => 'Network 2 Banner message',
      'top_banner'       => true,
      'bottom_banner'    => false,
      'system_info'      => true,
      'color'            => 'rgb(255,255,255)',
    },
    'network3' => {
      'background_color' => 'rgba(200,16,46,0.75)',
      'message'          => 'Network 3 Banner message',
      'top_banner'       => true,
      'bottom_banner'    => false,
      'system_info'      => true,
      'color'            => 'rgb(255,255,255)',
    },
    'network4' => {
      'background_color' => 'rgba(200,16,46,0.75)',
      'message'          => 'Network 4 Banner message',
      'top_banner'       => true,
      'bottom_banner'    => false,
      'system_info'      => true,
      'color'            => 'rgb(255,255,255)',
    },
  },
) {
  if $facts['os']['family'] != 'RedHat' {
    fail('custom::classification_banner supports only Red Hat family operating systems')
  }

  $os_major = $facts['os']['release']['major']

  case $os_major {
    '8': {
      if Integer($facts['os']['release']['minor']) < 6 and $manage_gui {
        fail('custom::classification_banner requires RHEL 8.6 or newer because the package is unavailable on earlier RHEL 8 releases')
      }
    }
    '9', '10': { }
    default: {
      fail('custom::classification_banner supports only RHEL major versions 8, 9, and 10')
    }
  }

  if $manage_gui {
    if $pp_network == undef or $pp_network == '' {
      fail('custom::classification_banner requires the pp_network trusted extension')
    }
    if !($pp_network in $network_profiles) {
      fail("custom::classification_banner has no banner profile for pp_network '${pp_network}'")
    }

    $profile = $network_profiles[$pp_network]
    $banner_content = epp('custom/classification-banner.epp', $profile)
    $lock_content = @("LOCKS"/L)
      # Managed by CES Puppet.
      # Manual changes will be replaced.
      /org/gnome/shell/enabled-extensions
      /org/gnome/shell/extensions/classification-banner/background-color
      /org/gnome/shell/extensions/classification-banner/message
      /org/gnome/shell/extensions/classification-banner/top-banner
      /org/gnome/shell/extensions/classification-banner/bottom-banner
      /org/gnome/shell/extensions/classification-banner/system-info
      /org/gnome/shell/extensions/classification-banner/color
      | LOCKS

    contain custom::dconf

    package { 'gnome-shell-extension-classification-banner':
      ensure => installed,
      notify => Exec['update custom dconf databases'],
    }

    file { 'custom gdm classification banner':
      ensure  => file,
      path    => '/etc/dconf/db/gdm.d/99-class-banner',
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => $banner_content,
      require => Package['gnome-shell-extension-classification-banner'],
      notify  => Exec['update custom dconf databases'],
    }

    file { 'custom gdm classification banner lock':
      ensure  => file,
      path    => '/etc/dconf/db/gdm.d/locks/99-class-banner',
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => $lock_content,
      require => Package['gnome-shell-extension-classification-banner'],
      notify  => Exec['update custom dconf databases'],
    }

    file { 'custom local classification banner':
      ensure  => file,
      path    => '/etc/dconf/db/local.d/99-class-banner',
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => $banner_content,
      require => Package['gnome-shell-extension-classification-banner'],
      notify  => Exec['update custom dconf databases'],
    }

    file { 'custom local classification banner lock':
      ensure  => file,
      path    => '/etc/dconf/db/local.d/locks/99-class-banner',
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => $lock_content,
      require => Package['gnome-shell-extension-classification-banner'],
      notify  => Exec['update custom dconf databases'],
    }
  }
}

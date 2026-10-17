# @summary
#   Persistently manages SELinux booleans selected by RHEL major version.
# @param set_booleans
#   OS major -> boolean name -> quoted 'on' or 'off'. Deep-merged by Hiera.
class custom::selinux_boolean (
  Hash[Enum['8', '9', '10'], Hash[Pattern[/\A[a-zA-Z][a-zA-Z0-9_]*\z/], Enum['on', 'off']]] $set_booleans = {},
) {
  if $facts['os']['family'] != 'RedHat' or $facts['os']['release']['major'] !~ /\A(8|9|10)\z/ {
    fail('custom::selinux_boolean supports only RHEL 8, 9, and 10')
  }

  $os_major = $facts['os']['release']['major']
  $selected = $set_booleans[$os_major] ? {
    undef   => {},
    default => $set_booleans[$os_major],
  }

  if $selected != {} {
    include custom::rpm_install

    $required_packages = ['libselinux-utils', 'policycoreutils', 'policycoreutils-python-utils']
    $required_packages.each |String $package_name| {
      if $package_name in $custom::rpm_install::xrpms {
        fail("custom::selinux_boolean requires ${package_name}; it cannot be in custom::rpm_install::xrpms")
      }
      if !($package_name in $custom::rpm_install::rpms) {
        package { $package_name:
          ensure => installed,
        }
      }
    }

    file { 'custom SELinux boolean helper':
      ensure       => file,
      path         => '/usr/local/sbin/ces-selinux-boolean',
      owner        => 'root',
      group        => 'root',
      mode         => '0755',
      source       => custom::source_candidates('puppet:///modules/custom/selinux/selinux_boolean.rb'),
      sourceselect => 'first',
    }

    $selected.each |String $boolean_name, String $value| {
      exec { "custom SELinux boolean ${boolean_name}":
        command   => "/opt/puppetlabs/puppet/bin/ruby /usr/local/sbin/ces-selinux-boolean --apply ${boolean_name} ${value}",
        unless    => "/opt/puppetlabs/puppet/bin/ruby /usr/local/sbin/ces-selinux-boolean --check ${boolean_name} ${value}",
        timeout   => 300,
        logoutput => 'on_failure',
        require   => [File['custom SELinux boolean helper'], Package[$required_packages]],
      }
    }
  }
}

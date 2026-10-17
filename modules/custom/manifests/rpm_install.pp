# @summary
#   Installs RPM packages supplied through Hiera.
#
# @param rpms
#   Package names to install. Hiera merges this array uniquely across all
#   hierarchy levels.
# @param xrpms
#   Package names to remove. Hiera merges this array uniquely across all
#   hierarchy levels.
class custom::rpm_install (
  Array[String[1]] $rpms = [],
  Array[String[1]] $xrpms = [],
) {
  if $facts['os']['family'] != 'RedHat' {
    fail('custom::rpm_install supports only Red Hat family operating systems')
  }

  $conflicting_rpms = $rpms.filter |String[1] $rpm| {
    $rpm in $xrpms
  }
  if $conflicting_rpms != [] {
    fail("custom::rpm_install cannot install and remove the same packages: ${conflicting_rpms.join(', ')}")
  }

  $rpms.each |String[1] $rpm| {
    package { $rpm:
      ensure => installed,
    }
  }

  $xrpms.each |String[1] $rpm| {
    package { $rpm:
      ensure => absent,
    }
  }
}

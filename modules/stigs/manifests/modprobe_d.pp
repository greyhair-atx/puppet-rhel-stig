# DISA STIG vulnerability IDs implemented by this class:
# RHEL 8:
#   V-230493, V-230494, V-230495, V-230496, V-230497, V-230498, V-230499, V-230503
#   V-230507
# RHEL 9:
#   V-257804, V-257805, V-257806, V-257807, V-257808, V-257880, V-258034, V-258039
# RHEL 10:
#   V-281288, V-281289, V-281312, V-281313, V-281314
class stigs::modprobe_d {
  $disabled_modules = $facts['os']['release']['major'] ? {
    /^(8|9|10)$/ => [
      'atm',
      'bluetooth',
      'can',
      'cramfs',
      'firewire-core',
      'sctp',
      'tipc',
      'usb-storage',
      'uvcvideo',
    ],
    default      => [],
  }

  file { 'stig directory /etc/modprobe.d':
    ensure => directory,
    path   => '/etc/modprobe.d',
  }

  $disabled_modules.each |String $module_name| {
    file { "stig /etc/modprobe.d/${module_name}.conf":
      ensure       => file,
      path         => "/etc/modprobe.d/${module_name}.conf",
      owner        => 'root',
      group        => 'root',
      mode         => '0644',
      source       => stigs::source_candidates("puppet:///modules/stigs/modprobe.d/${module_name}.conf"),
      sourceselect => 'first',
    }
  }
}

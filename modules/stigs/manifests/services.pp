# DISA STIG vulnerability IDs implemented by this class:
# RHEL 8:
#   V-230285, V-230298, V-230310, V-230502, V-230506, V-230526, V-230529, V-244542
#   V-244544, V-244545, V-244548
# RHEL 9:
#   V-257783, V-257785, V-257786, V-257815, V-257818, V-257849, V-257936, V-257944
#   V-257979, V-258035, V-258036, V-258040, V-258049, V-258090, V-258125, V-258142
#   V-258152
# RHEL 10:
#   V-280094, V-280956, V-280959, V-280963, V-280970, V-280973, V-280984, V-280994
#   V-281002, V-281096, V-281290, V-281299, V-281320, V-281322, V-281323
class stigs::services {
  $common_services = {
    'auditd.service'      => { ensure => running, enable => true },
    'ctrl-alt-del.target' => { enable => false, masked => true },
    'fapolicyd.service'   => { ensure => running, enable => true },
    'firewalld.service'   => { ensure => running, enable => true },
    'rsyslog.service'     => { ensure => running, enable => true },
    'sshd.service'        => { ensure => running, enable => true },
    'usbguard.service'    => { ensure => running, enable => true },
  }
  $release_services = $facts['os']['release']['major'] ? {
    '8'     => {
        'autofs.service'      => { ensure => stopped, enable => false },
        'debug-shell.service' => { ensure => stopped, enable => false, masked => true },
        'kdump.service'       => { ensure => stopped, enable => false },
        'rngd.service'        => { ensure => running, enable => true },
    },
    '9'     => {
        'autofs.service'           => { enable => false, masked => true },
        'chronyd.service'          => { ensure => running, enable => true },
        'debug-shell.service'      => { enable => false, masked => true },
        'kdump.service'            => { enable => false, masked => true },
        'pcscd.service'            => { ensure => running, enable => true },
        'systemd-coredump.socket'  => { enable => false, masked => true },
        'systemd-journald.service' => { ensure => running, enable => true },
    },
    '10'    => {
        'autofs.service'           => { enable => false, masked => true },
        'chronyd.service'          => { ensure => running, enable => true },
        'debug-shell.service'      => { enable => false, masked => true },
        'kdump.service'            => { enable => false, masked => true },
        'pcscd.socket'             => { ensure => running, enable => true },
        'systemd-coredump.socket'  => { enable => false, masked => true },
        'systemd-journald.service' => { ensure => running },
    },
    default => {},
  }
  if $facts['os']['release']['major'] =~ /^(8|9|10)$/ {
    ($common_services + $release_services).each |String $service_name, Hash $attributes| {
      if $attributes['masked'] {
        exec { "mask ${service_name}":
          command => "/usr/bin/systemctl mask --now ${service_name}",
          unless  => "/usr/bin/systemctl is-enabled ${service_name} | /usr/bin/grep -qx masked",
        }
      } else {
        service { $service_name: * => $attributes }
      }
    }
    exec { 'disable wireless radios':
      command => '/usr/bin/nmcli radio all off',
      unless  => '/usr/bin/test x$(/usr/bin/nmcli -t -f WIFI,WWAN general) = xdisabled:disabled',
      onlyif  => '/usr/bin/test -x /usr/bin/nmcli',
    }
  }
  if $facts['os']['release']['major'] == '9' {
    exec { 'set inactive account default':
      command => '/usr/sbin/useradd -D -f 35',
      unless  => "/usr/sbin/useradd -D | /usr/bin/grep -qx 'INACTIVE=35'",
    }
  }
  exec { 'reload audit rules':
    command     => '/usr/sbin/augenrules --load',
    refreshonly => true,
    onlyif      => '/usr/bin/test -x /usr/sbin/augenrules',
  }
  exec { 'reload sysctl settings':
    command     => '/usr/sbin/sysctl --system',
    refreshonly => true,
    onlyif      => '/usr/bin/test -x /usr/sbin/sysctl',
  }
  exec { 'update dconf database':
    command     => '/usr/bin/dconf update',
    refreshonly => true,
    onlyif      => '/usr/bin/test -x /usr/bin/dconf',
  }
  exec { 'systemd daemon reload': command => '/usr/bin/systemctl daemon-reload', refreshonly => true }
  exec { 'reload rsyslog configuration':
    command     => "/bin/sh -c '/usr/sbin/rsyslogd -N1 && /usr/bin/systemctl try-reload-or-restart rsyslog.service'",
    refreshonly => true,
    onlyif      => '/usr/bin/test -x /usr/sbin/rsyslogd',
  }
  exec { 'reload sshd configuration':
    command     => "/bin/sh -c '/usr/sbin/sshd -t && /usr/bin/systemctl reload sshd.service'",
    refreshonly => true,
    onlyif      => '/usr/bin/test -x /usr/sbin/sshd',
  }
  exec { 'validate and restart sssd':
    command     => "/bin/sh -c '/usr/sbin/sssctl config-check && /usr/bin/systemctl try-restart sssd.service'",
    refreshonly => true,
    onlyif      => '/usr/bin/test -x /usr/sbin/sssctl',
  }
}

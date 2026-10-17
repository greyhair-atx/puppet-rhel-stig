# DISA STIG vulnerability IDs implemented by this class:
# RHEL 8:
#   V-230239, V-230241, V-230273, V-230275, V-230285, V-230389, V-230411, V-230477
#   V-230478, V-230487, V-230488, V-230489, V-230492, V-230505, V-230523, V-230526
#   V-230533, V-230558, V-230559, V-230560, V-230561, V-237640, V-244527, V-244547
#   V-244549, V-251710, V-256974, V-279933
# RHEL 9:
#   V-257825, V-257827, V-257828, V-257829, V-257830, V-257831, V-257832, V-257833
#   V-257834, V-257835, V-257836, V-257838, V-257839, V-257840, V-257841, V-257842
#   V-257888, V-257935, V-257943, V-257954, V-257978, V-257980, V-258035, V-258081
#   V-258082, V-258083, V-258089, V-258124, V-258126, V-258134, V-258140, V-258141
#   V-258151, V-258175, V-258234, V-272488
# RHEL 10:
#   V-280943, V-280944, V-280945, V-280946, V-280947, V-280948, V-280949, V-280950
#   V-280951, V-280952, V-280953, V-280954, V-280955, V-280958, V-280962, V-280966
#   V-280967, V-280968, V-280972, V-280974, V-280975, V-280977, V-280983, V-280992
#   V-280993, V-280995, V-280996, V-281000, V-281001, V-281003, V-281005, V-281006
#   V-281007
class stigs::packages (
  Hash[String, Struct[{
    'ensure' => Enum['installed', 'absent'],
  }]] $package_overrides = {},
) {
  $common_packages = {
    'aide'            => { ensure => installed },
    'audit'           => { ensure => installed },
    'crypto-policies' => { ensure => installed },
    'epel-release'    => { ensure => absent },
    'fapolicyd'       => { ensure => installed },
    'gssproxy'        => { ensure => absent },
    'iprutils'        => { ensure => absent },
    'opensc'          => { ensure => installed },
    'openssl-pkcs11'  => { ensure => installed },
    'policycoreutils' => { ensure => installed },
    'postfix'         => { ensure => installed },
    'rng-tools'       => { ensure => installed },
    'rsyslog'         => { ensure => installed },
    'rsyslog-gnutls'  => { ensure => installed },
    'sendmail'        => { ensure => absent },
    'telnet-server'   => { ensure => absent },
    'tftp-server'     => { ensure => absent },
    'tuned'           => { ensure => absent },
    'usbguard'        => { ensure => installed },
  }
  $release_packages = $facts['os']['release']['major'] ? {
    '8'     => {
        'abrt*'                 => { ensure => absent },
        'firewalld.noarch'      => { ensure => installed },
        'krb5-server'           => { ensure => absent },
        'krb5-workstation'      => { ensure => absent },
        'mailx'                 => { ensure => installed },
        'openssh-server.x86_64' => { ensure => installed },
        'vsftpd'                => { ensure => absent },
    },
    '9'     => {
        'audispd-plugins'              => { ensure => installed },
        'chrony'                       => { ensure => installed },
        'cronie'                       => { ensure => installed },
        'firewalld'                    => { ensure => installed },
        'gnutls-utils'                 => { ensure => installed },
        'libreswan'                    => { ensure => installed },
        'nfs-utils'                    => { ensure => absent },
        'nss-tools'                    => { ensure => installed },
        'openssh-clients'              => { ensure => installed },
        'openssh-server'               => { ensure => installed },
        'pcsc-lite'                    => { ensure => installed },
        'policycoreutils-python-utils' => { ensure => installed },
        'quagga'                       => { ensure => absent },
        's-nail'                       => { ensure => installed },
        'subscription-manager'         => { ensure => installed },
        'sudo'                         => { ensure => installed },
        'ypserv'                       => { ensure => absent },
    },
    '10'    => {
        'audispd-plugins'              => { ensure => installed },
        'chrony'                       => { ensure => installed },
        'cronie'                       => { ensure => installed },
        'firewalld'                    => { ensure => installed },
        'gdm'                          => { ensure => absent },
        'gnutls-utils'                 => { ensure => installed },
        'libreswan'                    => { ensure => installed },
        'nfs-utils'                    => { ensure => absent },
        'nss-tools'                    => { ensure => installed },
        'openssh-clients'              => { ensure => installed },
        'openssh-server'               => { ensure => installed },
        'pcsc-lite'                    => { ensure => installed },
        'pcsc-lite-ccid'               => { ensure => installed },
        'pkcs11-provider'              => { ensure => installed },
        'policycoreutils-python-utils' => { ensure => installed },
        's-nail'                       => { ensure => installed },
        'subscription-manager'         => { ensure => installed },
        'sudo'                         => { ensure => installed },
        'tftp'                         => { ensure => absent },
        'unbound'                      => { ensure => absent },
        'vsftpd'                       => { ensure => absent },
    },
    default => {},
  }
  if $facts['os']['release']['major'] =~ /^(8|9|10)$/ {
    $default_packages = $common_packages + $release_packages
    $unknown_packages = $package_overrides.keys - $default_packages.keys
    if $unknown_packages != [] {
      fail("stigs::packages package_overrides contains packages without defaults for this OS: ${unknown_packages}")
    }

    $default_packages.each |String $package_name, Hash $default_attributes| {
      $override_attributes = $package_overrides[$package_name] ? {
        undef   => {},
        default => $package_overrides[$package_name],
      }
      $effective_attributes = $default_attributes + $override_attributes
      package { $package_name: * => $effective_attributes }
    }
  }
}

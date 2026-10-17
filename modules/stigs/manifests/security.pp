# DISA STIG vulnerability IDs implemented by this class:
# RHEL 8:
#   V-230313, V-230346, V-230357, V-230358, V-230359, V-230360, V-230361, V-230362
#   V-230363, V-230369, V-230375, V-230377
# RHEL 9:
#   V-257814, V-258054, V-258055, V-258056, V-258057, V-258060, V-258069, V-258070
#   V-258101, V-258102, V-258103, V-258107, V-258109, V-258110, V-258111, V-258112
#   V-258113, V-258114, V-258115
# RHEL 10:
#   V-281100, V-281181, V-281182, V-281183, V-281184, V-281185, V-281187, V-281188
#   V-281189, V-281190, V-281191, V-281193, V-281194, V-281195, V-281196, V-281197
#   V-281198, V-281203, V-281204, V-281319
class stigs::security {
  file { 'stig directory /etc/security':
    ensure => directory,
    path   => '/etc/security',
  }
  if $facts['os']['release']['major'] =~ /^(9|10)$/ {
      file { 'stig /etc/security/faillock.conf':
        ensure       => file,
        path         => '/etc/security/faillock.conf',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/security/faillock.conf'),
        sourceselect => 'first',
      }
  }
  if $facts['os']['release']['major'] =~ /^(8|9|10)$/ {
    file { 'stig /etc/security/limits.conf':
      ensure       => file,
      path         => '/etc/security/limits.conf',
      owner        => 'root',
      group        => 'root',
      mode         => '0644',
      source       => stigs::source_candidates('puppet:///modules/stigs/security/limits.conf'),
      sourceselect => 'first',
    }
    file { 'stig /etc/security/pwquality.conf':
      ensure       => file,
      path         => '/etc/security/pwquality.conf',
      owner        => 'root',
      group        => 'root',
      mode         => '0644',
      source       => stigs::source_candidates('puppet:///modules/stigs/security/pwquality.conf'),
      sourceselect => 'first',
    }
  }
}

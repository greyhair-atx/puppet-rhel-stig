# DISA STIG vulnerability IDs implemented by this class:
# RHEL 8:
#   V-230386, V-230388, V-230390, V-230392, V-230393, V-230394, V-230395, V-230402
#   V-230403, V-230404, V-230405, V-230406, V-230407, V-230408, V-230409, V-230410
#   V-230412, V-230413, V-230418, V-230419, V-230421, V-230422, V-230423, V-230424
#   V-230425, V-230426, V-230427, V-230428, V-230429, V-230430, V-230431, V-230432
#   V-230433, V-230434, V-230435, V-230436, V-230437, V-230438, V-230439, V-230444
#   V-230446, V-230447, V-230448, V-230449, V-230455, V-230456, V-230462, V-230463
#   V-230464, V-230465, V-230466, V-230467, V-230480, V-230483, V-244543, V-274877
# RHEL 9:
#   V-258153, V-258154, V-258156, V-258157, V-258158, V-258159, V-258160, V-258161
#   V-258162, V-258163, V-258164, V-258168, V-258169, V-258170, V-258176, V-258177
#   V-258178, V-258179, V-258180, V-258181, V-258182, V-258183, V-258184, V-258185
#   V-258186, V-258187, V-258188, V-258189, V-258190, V-258191, V-258192, V-258193
#   V-258194, V-258195, V-258196, V-258197, V-258198, V-258199, V-258200, V-258201
#   V-258202, V-258203, V-258204, V-258205, V-258206, V-258207, V-258208, V-258209
#   V-258210, V-258211, V-258212, V-258213, V-258214, V-258215, V-258216, V-258217
#   V-258218, V-258219, V-258220, V-258221, V-258222, V-258223, V-258224, V-258225
#   V-258227, V-258228, V-258229, V-279936
# RHEL 10:
#   V-281098, V-281099, V-281103, V-281104, V-281105, V-281107, V-281108, V-281109
#   V-281110, V-281111, V-281113, V-281114, V-281116, V-281117, V-281118, V-281119
#   V-281120, V-281121, V-281122, V-281123, V-281124, V-281125, V-281126, V-281127
#   V-281128, V-281129, V-281130, V-281131, V-281132, V-281133, V-281134, V-281135
#   V-281136, V-281137, V-281138, V-281139, V-281140, V-281141, V-281142, V-281143
#   V-281144, V-281145, V-281146, V-281147, V-281148, V-281149, V-281150, V-281151
#   V-281152, V-281153, V-281154, V-281155, V-281156, V-281157, V-281158, V-281159
#   V-281160, V-281161, V-281162, V-281163, V-281164, V-281165, V-281365
class stigs::audit {
  file { 'stig directory /etc/audit':
    ensure => directory,
    path   => '/etc/audit',
  }
  file { 'stig directory /etc/audit/rules.d':
    ensure => directory,
    path   => '/etc/audit/rules.d',
  }
  case $facts['os']['release']['major'] {
    '8': {
      file { 'stig /etc/audit/auditd.conf':
        ensure       => file,
        path         => '/etc/audit/auditd.conf',
        owner        => 'root',
        group        => 'root',
        mode         => '0640',
        source       => stigs::source_candidates('puppet:///modules/stigs/audit/auditd.conf'),
        sourceselect => 'first',
        notify       => Exec['reload audit rules'],
      }
    }
    '9': {
      file { 'stig /etc/audit/auditd.conf':
        ensure       => file,
        path         => '/etc/audit/auditd.conf',
        owner        => 'root',
        group        => 'root',
        mode         => '0640',
        source       => stigs::source_candidates('puppet:///modules/stigs/audit/auditd.conf'),
        sourceselect => 'first',
        notify       => Exec['reload audit rules'],
      }
    }
    '10': {
      file { 'stig /etc/audit/auditd.conf':
        ensure       => file,
        path         => '/etc/audit/auditd.conf',
        owner        => 'root',
        group        => 'root',
        mode         => '0640',
        source       => stigs::source_candidates('puppet:///modules/stigs/audit/auditd.conf'),
        sourceselect => 'first',
        notify       => Exec['reload audit rules'],
      }
    }
    default: {
      fail('stigs::audit supports RHEL major versions 8, 9, and 10 only')
    }
  }
  case $facts['os']['release']['major'] {
    '8': {
      file { 'stig /etc/audit/rules.d/audit.rules':
        ensure       => file,
        path         => '/etc/audit/rules.d/audit.rules',
        owner        => 'root',
        group        => 'root',
        mode         => '0640',
        source       => stigs::source_candidates('puppet:///modules/stigs/audit/rules.d/audit.rules'),
        sourceselect => 'first',
        notify       => Exec['reload audit rules'],
      }
    }
    '9': {
      file { 'stig /etc/audit/rules.d/audit.rules':
        ensure       => file,
        path         => '/etc/audit/rules.d/audit.rules',
        owner        => 'root',
        group        => 'root',
        mode         => '0640',
        source       => stigs::source_candidates('puppet:///modules/stigs/audit/rules.d/audit.rules'),
        sourceselect => 'first',
        notify       => Exec['reload audit rules'],
      }
    }
    '10': {
      file { 'stig /etc/audit/rules.d/audit.rules':
        ensure       => file,
        path         => '/etc/audit/rules.d/audit.rules',
        owner        => 'root',
        group        => 'root',
        mode         => '0600',
        source       => stigs::source_candidates('puppet:///modules/stigs/audit/rules.d/audit.rules'),
        sourceselect => 'first',
        notify       => Exec['reload audit rules'],
      }
    }
    default: {
      fail('stigs::audit supports RHEL major versions 8, 9, and 10 only')
    }
  }
}

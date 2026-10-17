# DISA STIG vulnerability IDs implemented by this class:
# RHEL 8:
#   V-230245, V-230246, V-230247, V-230248, V-230249, V-230250
# RHEL 9:
#   V-257790, V-257791, V-257885, V-257886, V-257891, V-257892, V-257893, V-257894
#   V-257895, V-257896, V-257897, V-257898, V-257899, V-257900, V-257901, V-257902
#   V-257903, V-257904, V-257905, V-257906, V-257907, V-257908, V-257909, V-257910
#   V-257911, V-257912, V-257913, V-257914, V-257915, V-257916, V-257917, V-257934
# RHEL 10:
#   V-281017, V-281018, V-281019, V-281020, V-281021, V-281022, V-281023, V-281024
#   V-281025, V-281026, V-281027, V-281028, V-281029, V-281030, V-281031, V-281032
#   V-281033, V-281034, V-281035, V-281036, V-281061, V-281062, V-281066, V-281067
#   V-281068, V-281069, V-281070, V-281071, V-281072, V-281076
class stigs::permissions (
  Hash[String[1], Struct[{
    Optional['owner'] => String[1],
    Optional['group'] => String[1],
    Optional['mode']  => Pattern[/^[0-7]{4}$/],
  }]] $file_overrides = {},
) {
  $account_file_permissions = {
    '/etc/group'    => { owner => 'root', group => 'root', mode => '0644' },
    '/etc/group-'   => { owner => 'root', group => 'root', mode => '0644' },
    '/etc/gshadow'  => { owner => 'root', group => 'root', mode => '0000' },
    '/etc/gshadow-' => { owner => 'root', group => 'root', mode => '0000' },
    '/etc/passwd'   => { owner => 'root', group => 'root', mode => '0644' },
    '/etc/passwd-'  => { owner => 'root', group => 'root', mode => '0644' },
    '/etc/shadow'   => { owner => 'root', group => 'root', mode => '0000' },
    '/etc/shadow-'  => { owner => 'root', group => 'root', mode => '0000' },
  }
  $log_file_permissions = {
    '/var/log'          => { owner => 'root', group => 'root', mode => '0755' },
    '/var/log/messages' => { owner => 'root', group => 'root', mode => '0640' },
  }
  $release_permissions = $facts['os']['release']['major'] ? {
    '8'     => $log_file_permissions,
    '9'     => $account_file_permissions + $log_file_permissions + {
      '/boot/grub2/grub.cfg' => { owner => 'root', group => 'root' },
    },
    '10'    => $account_file_permissions + $log_file_permissions,
    default => {},
  }

  if $facts['os']['release']['major'] =~ /^(8|9|10)$/ {
    $unknown_files = $file_overrides.keys - $release_permissions.keys
    if $unknown_files != [] {
      fail("stigs::permissions file_overrides contains paths without defaults for this OS: ${unknown_files}")
    }

    $release_permissions.each |String $file_path, Hash $default_attributes| {
      $override_attributes = $file_overrides[$file_path] ? {
        undef   => {},
        default => $file_overrides[$file_path],
      }
      $effective_attributes = $default_attributes + $override_attributes
      file { "stig permissions ${file_path}":
        path => $file_path,
        *    => $effective_attributes,
      }
    }
  }
}

# Returns node, project, role, network default, then shared default candidates.
# Each tier tries the OS major version first, then its version-independent file.
# Pass the base filename without an OS suffix (see NETWORK_OVERRIDES.md).
function stigs::source_candidates(String[1] $default_source) >> Array[String] {
  $network = $trusted['extensions']['pp_network']
  $project = $trusted['extensions']['pp_project']
  $role = $trusted['extensions']['pp_role']
  $certname = $trusted['certname']
  $os_major = $facts.dig('os', 'release', 'major')

  if $os_major != undef and $os_major != '' {
    if $os_major !~ String or $os_major !~ /\A[0-9]+\z/ {
      fail('stigs::source_candidates OS major version must contain only digits')
    }
  }

  if $network == undef or $network == '' {
    $suffixes = ['']
  } else {
    # Reject path traversal and URI delimiters in filename suffixes.
    [$network, $project, $role, $certname].each |$identity| {
      if $identity != undef and $identity != '' {
        if $identity !~ String or $identity !~ /\A[A-Za-z0-9][A-Za-z0-9_.-]*\z/ {
          fail('stigs::source_candidates identities must start with a letter or digit and contain only letters, digits, underscores, dots, or hyphens')
        }
      }
    }
    $node_suffixes = $certname ? {
      undef => [], '' => [], default => [".${network}.${certname}"],
    }
    $project_suffixes = $project ? {
      undef => [], '' => [], default => [".${network}.${project}"],
    }
    $role_suffixes = $role ? {
      undef => [], '' => [], default => [".${network}.${role}"],
    }
    $suffixes = $node_suffixes + $project_suffixes + $role_suffixes + [".${network}", '']
  }

  $suffixes.reduce([]) |$candidates, $suffix| {
    if $os_major == undef or $os_major == '' {
      $candidates + ["${default_source}${suffix}"]
    } else {
      $candidates + ["${default_source}.${os_major}${suffix}", "${default_source}${suffix}"]
    }
  }
}

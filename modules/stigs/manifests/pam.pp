# Control PAM files directly (no authselect).
#
# fingerprint-auth
# password-auth
# postlogin
# smartcard-auth
# switchable-auth
# system-auth
# vlock

# @summary
#   Manages the RHEL PAM authentication stacks and service files.
#
# @param include_sssd_rules
#   Whether to include SSSD authentication, account, password, and session rules.
# @param enable_smartcard
#   Whether to enable SSSD smart-card authentication in system-auth.
# @param smartcard_in_password_auth
#   Whether to include smart-card authentication in password-auth when
#   smart-card authentication is enabled.
# @param suppress_missing_sssd_errors
#   Whether PAM should ignore module-load errors when pam_sss.so is unavailable.
# @param password_history
#   Number of previous passwords that pam_pwhistory prevents users from reusing.
class stigs::pam (
  Boolean    $include_sssd_rules            = false,
  Boolean    $enable_smartcard              = false,
  Boolean    $smartcard_in_password_auth    = false,
  Boolean    $suppress_missing_sssd_errors  = true,
  Integer[5] $password_history              = 5,
) {

  if $facts['os']['family'] != 'RedHat' {
    fail('stigs::pam supports only Red Hat family operating systems')
  }

  $os_major = Integer($facts['os']['release']['major'])

  case $os_major {
    8: {
      $hash_rounds       = 100000
      $pwquality_control = 'requisite'
      $pwhistory_control = 'requisite'
    }

    9: {
      $hash_rounds       = 100000
      $pwquality_control = 'required'
      $pwhistory_control = 'required'
    }

    10: {
      $hash_rounds       = 100000
      $pwquality_control = 'required'
      $pwhistory_control = 'required'
    }

    default: {
      fail('stigs::pam supports RHEL major versions 8, 9, and 10 only')
    }
  }

  if $enable_smartcard and !$include_sssd_rules {
    fail('stigs::pam: enable_smartcard requires include_sssd_rules => true')
  }

  $sssd_type_prefix = $suppress_missing_sssd_errors ? {
    true    => '-',
    default => '',
  }

  file { 'stig directory /etc/pam.d':
    ensure => directory,
    path   => '/etc/pam.d',
  }

  file { 'stig /etc/pam.d/fingerprint-auth':
    ensure       => file,
    path         => '/etc/pam.d/fingerprint-auth',
    owner        => 'root',
    group        => 'root',
    mode         => '0644',
    source       => stigs::source_candidates('puppet:///modules/stigs/pam.d/fingerprint-auth'),
    sourceselect => 'first',
  }

  file { 'stig /etc/pam.d/postlogin':
    ensure       => file,
    path         => '/etc/pam.d/postlogin',
    owner        => 'root',
    group        => 'root',
    mode         => '0644',
    source       => stigs::source_candidates('puppet:///modules/stigs/pam.d/postlogin'),
    sourceselect => 'first',
  }

  file { 'stig /etc/pam.d/smartcard-auth':
    ensure       => file,
    path         => '/etc/pam.d/smartcard-auth',
    owner        => 'root',
    group        => 'root',
    mode         => '0644',
    source       => stigs::source_candidates('puppet:///modules/stigs/pam.d/smartcard-auth'),
    sourceselect => 'first',
  }

  file { 'stig /etc/pam.d/vlock':
    ensure       => file,
    path         => '/etc/pam.d/vlock',
    owner        => 'root',
    group        => 'root',
    mode         => '0644',
    source       => stigs::source_candidates('puppet:///modules/stigs/pam.d/vlock'),
    sourceselect => 'first',
  }

  if $os_major == 10 {
    file { 'stig /etc/pam.d/switchable-auth':
      ensure       => file,
      path         => '/etc/pam.d/switchable-auth',
      owner        => 'root',
      group        => 'root',
      mode         => '0644',
      source       => stigs::source_candidates('puppet:///modules/stigs/pam.d/switchable-auth'),
      sourceselect => 'first',
    }
  }

  file { '/etc/pam.d/system-auth':
    ensure    => file,
    owner     => 'root',
    group     => 'root',
    mode      => '0644',
    links     => 'manage',
    replace   => true,
    backup    => '.puppet-bak',
    show_diff => true,
    content   => epp('stigs/pam-auth.epp', {
      'pam_name'           => 'system-auth',
      'os_major'           => $os_major,
      'hash_rounds'        => $hash_rounds,
      'pwquality_control'  => $pwquality_control,
      'pwhistory_control'  => $pwhistory_control,
      'password_history'   => $password_history,
      'include_sssd_rules' => $include_sssd_rules,
      'enable_smartcard'   => $enable_smartcard,
      'sssd_type_prefix'   => $sssd_type_prefix,
    }),
  }

  file { '/etc/pam.d/password-auth':
    ensure    => file,
    owner     => 'root',
    group     => 'root',
    mode      => '0644',
    links     => 'manage',
    replace   => true,
    backup    => '.puppet-bak',
    show_diff => true,
    content   => epp('stigs/pam-auth.epp', {
      'pam_name'           => 'password-auth',
      'os_major'           => $os_major,
      'hash_rounds'        => $hash_rounds,
      'pwquality_control'  => $pwquality_control,
      'pwhistory_control'  => $pwhistory_control,
      'password_history'   => $password_history,
      'include_sssd_rules' => $include_sssd_rules,

      # Smart-card authentication normally belongs in system-auth,
      # not password-auth.
      'enable_smartcard'   => (
        $enable_smartcard and $smartcard_in_password_auth
      ),

      'sssd_type_prefix'   => $sssd_type_prefix,
    }),
  }
}

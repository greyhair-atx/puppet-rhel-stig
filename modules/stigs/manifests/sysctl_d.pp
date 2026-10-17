# DISA STIG vulnerability IDs implemented by this class:
# RHEL 8:
#   V-230266, V-230267, V-230268, V-230269, V-230270, V-230280, V-230311, V-230535
#   V-230536, V-230537, V-230538, V-230539, V-230540, V-230541, V-230542, V-230543
#   V-230544, V-230545, V-230546, V-230547, V-230548, V-230549, V-244550, V-244551
#   V-244552, V-244553, V-244554, V-284947, V-284948, V-284949
# RHEL 9:
#   V-257797, V-257798, V-257799, V-257800, V-257801, V-257802, V-257803, V-257809
#   V-257810, V-257811, V-257816, V-257942, V-257957, V-257958, V-257959, V-257960
#   V-257961, V-257962, V-257963, V-257964, V-257965, V-257966, V-257967, V-257968
#   V-257969, V-257970, V-257971, V-257972, V-257973, V-257974, V-257975, V-257976
#   V-257977
# RHEL 10:
#   V-281305, V-281306, V-281307, V-281308, V-281309, V-281310, V-281311, V-281315
#   V-281316, V-281335, V-281337, V-281340, V-281341, V-281342, V-281343, V-281344
#   V-281345, V-281346, V-281347, V-281348, V-281349, V-281350, V-281351, V-281352
#   V-281353, V-281354, V-281355, V-281356, V-281357, V-281358, V-281359, V-281360
class stigs::sysctl_d {
  file { 'stig directory /etc/sysctl.d':
    ensure => directory,
    path   => '/etc/sysctl.d',
  }
  if $facts['os']['release']['major'] == '8' {
      file { 'stig /etc/sysctl.d/99-disable-coredump.conf':
        ensure       => file,
        path         => '/etc/sysctl.d/99-disable-coredump.conf',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/sysctl.d/99-disable-coredump.conf'),
        sourceselect => 'first',
        notify       => Exec['reload sysctl settings'],
      }
  }
  file { 'stig /etc/sysctl.d/99-dmesg_restrict.conf':
    ensure       => file,
    path         => '/etc/sysctl.d/99-dmesg_restrict.conf',
    owner        => 'root',
    group        => 'root',
    mode         => '0644',
    source       => stigs::source_candidates('puppet:///modules/stigs/sysctl.d/99-dmesg_restrict.conf'),
    sourceselect => 'first',
    notify       => Exec['reload sysctl settings'],
  }
  file { 'stig /etc/sysctl.d/99-fs_protected_hardlinks.conf':
    ensure       => file,
    path         => '/etc/sysctl.d/99-fs_protected_hardlinks.conf',
    owner        => 'root',
    group        => 'root',
    mode         => '0644',
    source       => stigs::source_candidates('puppet:///modules/stigs/sysctl.d/99-fs_protected_hardlinks.conf'),
    sourceselect => 'first',
    notify       => Exec['reload sysctl settings'],
  }
  file { 'stig /etc/sysctl.d/99-fs_protected_symlinks.conf':
    ensure       => file,
    path         => '/etc/sysctl.d/99-fs_protected_symlinks.conf',
    owner        => 'root',
    group        => 'root',
    mode         => '0644',
    source       => stigs::source_candidates('puppet:///modules/stigs/sysctl.d/99-fs_protected_symlinks.conf'),
    sourceselect => 'first',
    notify       => Exec['reload sysctl settings'],
  }
  if $facts['os']['release']['major'] =~ /^(9|10)$/ {
      file { 'stig /etc/sysctl.d/99-ipv4_accept_redirects.conf':
        ensure       => file,
        path         => '/etc/sysctl.d/99-ipv4_accept_redirects.conf',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/sysctl.d/99-ipv4_accept_redirects.conf'),
        sourceselect => 'first',
        notify       => Exec['reload sysctl settings'],
      }
  }
  if $facts['os']['release']['major'] =~ /^(9|10)$/ {
      file { 'stig /etc/sysctl.d/99-ipv4_accept_source.conf':
        ensure       => file,
        path         => '/etc/sysctl.d/99-ipv4_accept_source.conf',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/sysctl.d/99-ipv4_accept_source.conf'),
        sourceselect => 'first',
        notify       => Exec['reload sysctl settings'],
      }
  }
  if $facts['os']['release']['major'] =~ /^(9|10)$/ {
      file { 'stig /etc/sysctl.d/99-ipv4_accept_source_route.conf':
        ensure       => file,
        path         => '/etc/sysctl.d/99-ipv4_accept_source_route.conf',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/sysctl.d/99-ipv4_accept_source_route.conf'),
        sourceselect => 'first',
        notify       => Exec['reload sysctl settings'],
      }
  }
  if $facts['os']['release']['major'] =~ /^(9|10)$/ {
      file { 'stig /etc/sysctl.d/99-ipv4_log_martians.conf':
        ensure       => file,
        path         => '/etc/sysctl.d/99-ipv4_log_martians.conf',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/sysctl.d/99-ipv4_log_martians.conf'),
        sourceselect => 'first',
        notify       => Exec['reload sysctl settings'],
      }
  }
  if $facts['os']['release']['major'] =~ /^(9|10)$/ {
      file { 'stig /etc/sysctl.d/99-ipv4_rp_filter.conf':
        ensure       => file,
        path         => '/etc/sysctl.d/99-ipv4_rp_filter.conf',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/sysctl.d/99-ipv4_rp_filter.conf'),
        sourceselect => 'first',
        notify       => Exec['reload sysctl settings'],
      }
  }
  if $facts['os']['release']['major'] =~ /^(9|10)$/ {
      file { 'stig /etc/sysctl.d/99-ipv4_tcp_syncookies.conf':
        ensure       => file,
        path         => '/etc/sysctl.d/99-ipv4_tcp_syncookies.conf',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/sysctl.d/99-ipv4_tcp_syncookies.conf'),
        sourceselect => 'first',
        notify       => Exec['reload sysctl settings'],
      }
  }
  if $facts['os']['release']['major'] =~ /^(9|10)$/ {
      file { 'stig /etc/sysctl.d/99-kernel_core_pattern.conf':
        ensure       => file,
        path         => '/etc/sysctl.d/99-kernel_core_pattern.conf',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/sysctl.d/99-kernel_core_pattern.conf'),
        sourceselect => 'first',
        notify       => Exec['reload sysctl settings'],
      }
  }
  file { 'stig /etc/sysctl.d/99-kernel_kexec_load_disabled.conf':
    ensure       => file,
    path         => '/etc/sysctl.d/99-kernel_kexec_load_disabled.conf',
    owner        => 'root',
    group        => 'root',
    mode         => '0644',
    source       => stigs::source_candidates('puppet:///modules/stigs/sysctl.d/99-kernel_kexec_load_disabled.conf'),
    sourceselect => 'first',
    notify       => Exec['reload sysctl settings'],
  }
  file { 'stig /etc/sysctl.d/99-kernel_kptr_restrict.conf':
    ensure       => file,
    path         => '/etc/sysctl.d/99-kernel_kptr_restrict.conf',
    owner        => 'root',
    group        => 'root',
    mode         => '0644',
    source       => stigs::source_candidates('puppet:///modules/stigs/sysctl.d/99-kernel_kptr_restrict.conf'),
    sourceselect => 'first',
    notify       => Exec['reload sysctl settings'],
  }
  file { 'stig /etc/sysctl.d/99-kernel_perf_event_paranoid.conf':
    ensure       => file,
    path         => '/etc/sysctl.d/99-kernel_perf_event_paranoid.conf',
    owner        => 'root',
    group        => 'root',
    mode         => '0644',
    source       => stigs::source_candidates('puppet:///modules/stigs/sysctl.d/99-kernel_perf_event_paranoid.conf'),
    sourceselect => 'first',
    notify       => Exec['reload sysctl settings'],
  }
  file { 'stig /etc/sysctl.d/99-kernel_randomize_va_space.conf':
    ensure       => file,
    path         => '/etc/sysctl.d/99-kernel_randomize_va_space.conf',
    owner        => 'root',
    group        => 'root',
    mode         => '0644',
    source       => stigs::source_candidates('puppet:///modules/stigs/sysctl.d/99-kernel_randomize_va_space.conf'),
    sourceselect => 'first',
    notify       => Exec['reload sysctl settings'],
  }
  if $facts['os']['release']['major'] =~ /^(9|10)$/ {
      file { 'stig /etc/sysctl.d/99-kernel_unprivileged_bpf_disabled.conf':
        ensure       => file,
        path         => '/etc/sysctl.d/99-kernel_unprivileged_bpf_disabled.conf',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/sysctl.d/99-kernel_unprivileged_bpf_disabled.conf'),
        sourceselect => 'first',
        notify       => Exec['reload sysctl settings'],
      }
  }
  if $facts['os']['release']['major'] =~ /^(9|10)$/ {
      file { 'stig /etc/sysctl.d/99-kernel_yama.ptrace_scope.conf':
        ensure       => file,
        path         => '/etc/sysctl.d/99-kernel_yama.ptrace_scope.conf',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/sysctl.d/99-kernel_yama.ptrace_scope.conf'),
        sourceselect => 'first',
        notify       => Exec['reload sysctl settings'],
      }
  }
  if $facts['os']['release']['major'] =~ /^(9|10)$/ {
      file { 'stig /etc/sysctl.d/99-net_core-bpf_jit_harden.conf':
        ensure       => file,
        path         => '/etc/sysctl.d/99-net_core-bpf_jit_harden.conf',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/sysctl.d/99-net_core-bpf_jit_harden.conf'),
        sourceselect => 'first',
        notify       => Exec['reload sysctl settings'],
      }
  }
  if $facts['os']['release']['major'] == '8' {
      file { 'stig /etc/sysctl.d/99-ptrace-restrict.conf':
        ensure       => file,
        path         => '/etc/sysctl.d/99-ptrace-restrict.conf',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/sysctl.d/99-ptrace-restrict.conf'),
        sourceselect => 'first',
        notify       => Exec['reload sysctl settings'],
      }
  }
  if $facts['os']['release']['major'] == '8' {
      file { 'stig /etc/sysctl.d/99-rhel8-stig.conf':
        ensure       => file,
        path         => '/etc/sysctl.d/99-rhel8-stig.conf',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/sysctl.d/99-rhel8-stig.conf'),
        sourceselect => 'first',
        notify       => Exec['reload sysctl settings'],
      }
  }
  if $facts['os']['release']['major'] == '8' {
      file { 'stig /etc/sysctl.d/99-sysctl.conf':
        ensure       => file,
        path         => '/etc/sysctl.d/99-sysctl.conf',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/sysctl.d/99-sysctl.conf'),
        sourceselect => 'first',
        notify       => Exec['reload sysctl settings'],
      }
  }
  if $facts['os']['release']['major'] == '9' {
      file { 'stig /etc/sysctl.d/99-user_max_user_namespaces.conf':
        ensure       => file,
        path         => '/etc/sysctl.d/99-user_max_user_namespaces.conf',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/sysctl.d/99-user_max_user_namespaces.conf'),
        sourceselect => 'first',
        notify       => Exec['reload sysctl settings'],
      }
  }
  if $facts['os']['release']['major'] =~ /^(9|10)$/ {
      file { 'stig /etc/sysctl.d/ipv4_accept_ra.conf':
        ensure       => file,
        path         => '/etc/sysctl.d/ipv4_accept_ra.conf',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/sysctl.d/ipv4_accept_ra.conf'),
        sourceselect => 'first',
        notify       => Exec['reload sysctl settings'],
      }
  }
  if $facts['os']['release']['major'] =~ /^(9|10)$/ {
      file { 'stig /etc/sysctl.d/ipv4_forwarding.conf':
        ensure       => file,
        path         => '/etc/sysctl.d/ipv4_forwarding.conf',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/sysctl.d/ipv4_forwarding.conf'),
        sourceselect => 'first',
        notify       => Exec['reload sysctl settings'],
      }
  }
  if $facts['os']['release']['major'] =~ /^(9|10)$/ {
      file { 'stig /etc/sysctl.d/ipv4_icmp_echo_ignore_broadcasts.conf':
        ensure       => file,
        path         => '/etc/sysctl.d/ipv4_icmp_echo_ignore_broadcasts.conf',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/sysctl.d/ipv4_icmp_echo_ignore_broadcasts.conf'),
        sourceselect => 'first',
        notify       => Exec['reload sysctl settings'],
      }
  }
  if $facts['os']['release']['major'] =~ /^(9|10)$/ {
      file { 'stig /etc/sysctl.d/ipv4_icmp_ignore_bogus_error_responses.conf':
        ensure       => file,
        path         => '/etc/sysctl.d/ipv4_icmp_ignore_bogus_error_responses.conf',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/sysctl.d/ipv4_icmp_ignore_bogus_error_responses.conf'),
        sourceselect => 'first',
        notify       => Exec['reload sysctl settings'],
      }
  }
  if $facts['os']['release']['major'] == '8' {
      file { 'stig /etc/sysctl.d/ipv4_log_martians.conf':
        ensure       => file,
        path         => '/etc/sysctl.d/ipv4_log_martians.conf',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/sysctl.d/ipv4_log_martians.conf'),
        sourceselect => 'first',
        notify       => Exec['reload sysctl settings'],
      }
  }
  case $facts['os']['release']['major'] {
    '8': {
      file { 'stig /etc/sysctl.d/ipv4_rp_filter.conf':
        ensure       => file,
        path         => '/etc/sysctl.d/ipv4_rp_filter.conf',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/sysctl.d/ipv4_rp_filter.conf'),
        sourceselect => 'first',
        notify       => Exec['reload sysctl settings'],
      }
    }
    '9': {
      file { 'stig /etc/sysctl.d/ipv4_rp_filter.conf':
        ensure       => file,
        path         => '/etc/sysctl.d/ipv4_rp_filter.conf',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/sysctl.d/ipv4_rp_filter.conf'),
        sourceselect => 'first',
        notify       => Exec['reload sysctl settings'],
      }
    }
    '10': {
      file { 'stig /etc/sysctl.d/ipv4_rp_filter.conf':
        ensure       => file,
        path         => '/etc/sysctl.d/ipv4_rp_filter.conf',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/sysctl.d/ipv4_rp_filter.conf'),
        sourceselect => 'first',
        notify       => Exec['reload sysctl settings'],
      }
    }
    default: {
      fail('stigs::sysctl_d supports RHEL major versions 8, 9, and 10 only')
    }
  }
  if $facts['os']['release']['major'] == '9' {
      file { 'stig /etc/sysctl.d/ipv4_send_redirect.conf':
        ensure       => file,
        path         => '/etc/sysctl.d/ipv4_send_redirect.conf',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/sysctl.d/ipv4_send_redirect.conf'),
        sourceselect => 'first',
        notify       => Exec['reload sysctl settings'],
      }
  }
  if $facts['os']['release']['major'] =~ /^(9|10)$/ {
      file { 'stig /etc/sysctl.d/ipv4_send_redirects.conf':
        ensure       => file,
        path         => '/etc/sysctl.d/ipv4_send_redirects.conf',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/sysctl.d/ipv4_send_redirects.conf'),
        sourceselect => 'first',
        notify       => Exec['reload sysctl settings'],
      }
  }
  if $facts['os']['release']['major'] =~ /^(9|10)$/ {
      file { 'stig /etc/sysctl.d/ipv6_accept_ra.conf':
        ensure       => file,
        path         => '/etc/sysctl.d/ipv6_accept_ra.conf',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/sysctl.d/ipv6_accept_ra.conf'),
        sourceselect => 'first',
        notify       => Exec['reload sysctl settings'],
      }
  }
  if $facts['os']['release']['major'] =~ /^(9|10)$/ {
      file { 'stig /etc/sysctl.d/ipv6_accept_redirects.conf':
        ensure       => file,
        path         => '/etc/sysctl.d/ipv6_accept_redirects.conf',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/sysctl.d/ipv6_accept_redirects.conf'),
        sourceselect => 'first',
        notify       => Exec['reload sysctl settings'],
      }
  }
  if $facts['os']['release']['major'] =~ /^(9|10)$/ {
      file { 'stig /etc/sysctl.d/ipv6_accept_source_route.conf':
        ensure       => file,
        path         => '/etc/sysctl.d/ipv6_accept_source_route.conf',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/sysctl.d/ipv6_accept_source_route.conf'),
        sourceselect => 'first',
        notify       => Exec['reload sysctl settings'],
      }
  }
  if $facts['os']['release']['major'] =~ /^(9|10)$/ {
      file { 'stig /etc/sysctl.d/ipv6_forwarding.conf':
        ensure       => file,
        path         => '/etc/sysctl.d/ipv6_forwarding.conf',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/sysctl.d/ipv6_forwarding.conf'),
        sourceselect => 'first',
        notify       => Exec['reload sysctl settings'],
      }
  }
}

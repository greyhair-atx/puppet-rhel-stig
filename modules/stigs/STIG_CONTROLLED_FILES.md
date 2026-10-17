# STIG-controlled files

This inventory records the destination files whose content is represented by
the RHEL 8 V2R8, RHEL 9 V2R9, and RHEL 10 V1R2 STIG assets. It was verified on
2026-07-18 against the `R8-STIG` RHEL 8.10, `R9-STIG` RHEL 9.8, and `R10-STIG`
RHEL 10.2 reference VMs.

The exemplar merge starts with an existing VM file when one is present and
overwrites or appends the entries controlled by the STIG. If the destination
does not exist, the STIG fragment becomes the complete asset. After generation,
Puppet treats every resulting asset under `modules/stigs/files/` as authoritative for
the entire destination file, as described in `README.md`.

The RHEL 8/9 implementation has 79 unique content-managed destinations: 35 are
managed on both releases, 9 only on RHEL 8, and 35 only on RHEL 9. The reviewed
RHEL 10 STIG asset set covers 68 destinations and adds one new destination, for
80 unique paths across all three releases. The RHEL 10 catalog manages four
additional common-hardening module files, for 72 managed RHEL 10 destinations.
RHEL 10 uses `.10` assets when content differs and shared unnumbered assets for
exact matches, selected in the existing functional manifests. Package,
service-state, permission, and other non-file RHEL 10 behavior remains outside
the catalog pending review.

`stigs::modprobe_d` intentionally applies a common nine-file module deny policy
to RHEL 8, RHEL 9, and RHEL 10. All nine have direct RHEL 8 controls.
`uvcvideo` is common defense-in-depth on RHEL 9, while `atm`, `cramfs`,
`firewire-core`, and `uvcvideo` are common defense-in-depth on RHEL 10 and are
not counted among the direct RHEL 10 V1R2 controls below.

## RHEL 8 and RHEL 9

- `/etc/audit/auditd.conf`
- `/etc/audit/rules.d/audit.rules`
- `/etc/dconf/db/local.d/00-screensaver`
- `/etc/dconf/db/local.d/01-banner-message`
- `/etc/dconf/db/local.d/02-login-screen`
- `/etc/dconf/db/local.d/locks/session`
- `/etc/dnf/dnf.conf`
- `/etc/issue`
- `/etc/login.defs`
- `/etc/rsyslog.conf`
- `/etc/security/limits.conf`
- `/etc/security/pwquality.conf`
- `/etc/selinux/config`
- `/etc/ssh/sshd_config`
- `/etc/sssd/conf.d/certificate_verification.conf`
- `/etc/sysctl.d/99-dmesg_restrict.conf`
- `/etc/sysctl.d/99-fs_protected_hardlinks.conf`
- `/etc/sysctl.d/99-fs_protected_symlinks.conf`
- `/etc/sysctl.d/99-kernel_kexec_load_disabled.conf`
- `/etc/sysctl.d/99-kernel_kptr_restrict.conf`
- `/etc/sysctl.d/99-kernel_perf_event_paranoid.conf`
- `/etc/sysctl.d/99-kernel_randomize_va_space.conf`
- `/etc/sysctl.d/ipv4_rp_filter.conf`
- `/etc/systemd/coredump.conf`
- `/etc/systemd/system.conf.d/55-CtrlAltDel-BurstAction.conf`
- `/usr/lib/systemd/system/emergency.service`

## RHEL 8 only

- `/etc/aliases`
- `/etc/gdm/custom.conf`
- `/etc/profile.d/tmout.sh`
- `/etc/sysctl.d/99-disable-coredump.conf`
- `/etc/sysctl.d/99-ptrace-restrict.conf`
- `/etc/sysctl.d/99-rhel8-stig.conf`
- `/etc/sysctl.d/99-sysctl.conf`
- `/etc/sysctl.d/ipv4_log_martians.conf`
- `/usr/lib/systemd/system/rescue.service`

## RHEL 9 only

- `/etc/bashrc`
- `/etc/chrony.conf`
- `/etc/csh.cshrc`
- `/etc/dconf/db/local.d/00-security-settings`
- `/etc/dconf/db/local.d/locks/00-security-settings-lock`
- `/etc/firewalld/firewalld.conf`
- `/etc/libuser.conf`
- `/etc/modprobe.d/atm.conf`
- `/etc/modprobe.d/bluetooth.conf`
- `/etc/modprobe.d/can.conf`
- `/etc/modprobe.d/cramfs.conf`
- `/etc/modprobe.d/firewire-core.conf`
- `/etc/modprobe.d/sctp.conf`
- `/etc/modprobe.d/tipc.conf`
- `/etc/modprobe.d/usb-storage.conf`
- `/etc/modprobe.d/uvcvideo.conf`
- `/etc/NetworkManager/NetworkManager.conf`
- `/etc/opensc.conf`
- `/etc/profile`
- `/etc/security/faillock.conf`
- `/etc/sssd/sssd.conf`
- `/etc/sudoers`
- `/etc/sysctl.d/99-ipv4_accept_redirects.conf`
- `/etc/sysctl.d/99-ipv4_accept_source.conf`
- `/etc/sysctl.d/99-ipv4_accept_source_route.conf`
- `/etc/sysctl.d/99-ipv4_log_martians.conf`
- `/etc/sysctl.d/99-ipv4_rp_filter.conf`
- `/etc/sysctl.d/99-ipv4_tcp_syncookies.conf`
- `/etc/sysctl.d/99-kernel_core_pattern.conf`
- `/etc/sysctl.d/99-kernel_unprivileged_bpf_disabled.conf`
- `/etc/sysctl.d/99-kernel_yama.ptrace_scope.conf`
- `/etc/sysctl.d/99-net_core-bpf_jit_harden.conf`
- `/etc/sysctl.d/99-user_max_user_namespaces.conf`
- `/etc/sysctl.d/ipv4_accept_ra.conf`
- `/etc/sysctl.d/ipv4_forwarding.conf`
- `/etc/sysctl.d/ipv4_icmp_echo_ignore_broadcasts.conf`
- `/etc/sysctl.d/ipv4_icmp_ignore_bogus_error_responses.conf`
- `/etc/sysctl.d/ipv4_send_redirect.conf`
- `/etc/sysctl.d/ipv4_send_redirects.conf`
- `/etc/sysctl.d/ipv6_accept_ra.conf`
- `/etc/sysctl.d/ipv6_accept_redirects.conf`
- `/etc/sysctl.d/ipv6_accept_source_route.conf`
- `/etc/sysctl.d/ipv6_forwarding.conf`
- `/etc/usbguard/usbguard-daemon.conf`

## RHEL 10 V1R2

- `/etc/aliases`
- `/etc/audit/auditd.conf`
- `/etc/audit/rules.d/audit.rules`
- `/etc/bashrc`
- `/etc/chrony.conf`
- `/etc/csh.cshrc`
- `/etc/dconf/db/local.d/00-media-keys`
- `/etc/dconf/db/local.d/00-screensaver`
- `/etc/dconf/db/local.d/00-security-settings`
- `/etc/dconf/db/local.d/01-banner-message`
- `/etc/dconf/db/local.d/02-login-screen`
- `/etc/dconf/db/local.d/locks/00-security-settings-lock`
- `/etc/dconf/db/local.d/locks/session`
- `/etc/dnf/dnf.conf`
- `/etc/firewalld/firewalld.conf`
- `/etc/gdm/custom.conf`
- `/etc/issue`
- `/etc/libuser.conf`
- `/etc/login.defs`
- `/etc/modprobe.d/bluetooth.conf`
- `/etc/modprobe.d/can.conf`
- `/etc/modprobe.d/sctp.conf`
- `/etc/modprobe.d/tipc.conf`
- `/etc/modprobe.d/usb-storage.conf`
- `/etc/NetworkManager/NetworkManager.conf`
- `/etc/profile`
- `/etc/profile.d/tmout.sh`
- `/etc/rsyslog.conf`
- `/etc/security/faillock.conf`
- `/etc/security/limits.conf`
- `/etc/security/pwquality.conf`
- `/etc/selinux/config`
- `/etc/ssh/sshd_config`
- `/etc/sssd/conf.d/certificate_verification.conf`
- `/etc/sssd/sssd.conf`
- `/etc/sudoers`
- `/etc/sysctl.d/99-dmesg_restrict.conf`
- `/etc/sysctl.d/99-fs_protected_hardlinks.conf`
- `/etc/sysctl.d/99-fs_protected_symlinks.conf`
- `/etc/sysctl.d/99-ipv4_accept_redirects.conf`
- `/etc/sysctl.d/99-ipv4_accept_source.conf`
- `/etc/sysctl.d/99-ipv4_accept_source_route.conf`
- `/etc/sysctl.d/99-ipv4_log_martians.conf`
- `/etc/sysctl.d/99-ipv4_rp_filter.conf`
- `/etc/sysctl.d/99-ipv4_tcp_syncookies.conf`
- `/etc/sysctl.d/99-kernel_core_pattern.conf`
- `/etc/sysctl.d/99-kernel_kexec_load_disabled.conf`
- `/etc/sysctl.d/99-kernel_kptr_restrict.conf`
- `/etc/sysctl.d/99-kernel_perf_event_paranoid.conf`
- `/etc/sysctl.d/99-kernel_randomize_va_space.conf`
- `/etc/sysctl.d/99-kernel_unprivileged_bpf_disabled.conf`
- `/etc/sysctl.d/99-kernel_yama.ptrace_scope.conf`
- `/etc/sysctl.d/99-net_core-bpf_jit_harden.conf`
- `/etc/sysctl.d/ipv4_accept_ra.conf`
- `/etc/sysctl.d/ipv4_forwarding.conf`
- `/etc/sysctl.d/ipv4_icmp_echo_ignore_broadcasts.conf`
- `/etc/sysctl.d/ipv4_icmp_ignore_bogus_error_responses.conf`
- `/etc/sysctl.d/ipv4_rp_filter.conf`
- `/etc/sysctl.d/ipv4_send_redirects.conf`
- `/etc/sysctl.d/ipv6_accept_ra.conf`
- `/etc/sysctl.d/ipv6_accept_redirects.conf`
- `/etc/sysctl.d/ipv6_accept_source_route.conf`
- `/etc/sysctl.d/ipv6_forwarding.conf`
- `/etc/systemd/coredump.conf`
- `/etc/systemd/system.conf.d/55-CtrlAltDel-BurstAction.conf`
- `/etc/usbguard/usbguard-daemon.conf`
- `/usr/lib/systemd/system/emergency.service`
- `/usr/lib/systemd/system/rescue.service`

This list covers files whose content is sourced from `modules/stigs/files/`. It does
not include files for which the module manages only permissions, package or
service state, systemd masks, or runtime commands.

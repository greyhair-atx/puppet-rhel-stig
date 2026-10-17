# SSG STIG profile comparison

This comparison records the Security Content Automation Protocol (SCAP)
content collected read-only from the three reference VMs on 2026-07-16. The
large datastreams remain under the ignored `.ps_sandbox/ssg_datastreams`
directory and are not deployed by the Puppet module.

## Source inventory

| Release | Reference system | `scap-security-guide` | STIG profile | Selected rules | Bash fixes | Puppet fixes | SHA-256 |
| --- | --- | --- | --- | ---: | ---: | ---: | --- |
| 8 | Rocky Linux 8.10 | 0.1.81 | DISA STIG V2R7 | 392 | 355 | 44 | `05166035517969e5244488679c87ed91652b42cf110f09050a4f0dec0fb84432` |
| 9 | Rocky Linux 9.8 | 0.1.81 | DISA STIG V2R8 | 488 | 447 | 48 | `4fbcf88cbc56a62f8dd5b926aeeb6ec29fab26d343c7f01da2c9b452a0689fb9` |
| 10 | Rocky Linux 10.2 | 0.1.81 | Red Hat STIG (no DISA version in the profile) | 509 | 468 | 52 | `ffc22d86bf1ad0ea949bcb76111e68bf57331cf6eabdfc3be3c51886d7fbc73b` |

The source files were `/usr/share/xml/scap/ssg/content/ssg-rhel8-ds.xml`,
`ssg-rhel9-ds.xml`, and `ssg-rhel10-ds.xml`. The local hashes were compared
with `sha256sum` output from each VM after collection.

The module's primary RHEL 8 and RHEL 9 sources are the newer DISA Ansible
roles (V2R8 and V2R9). SSG 0.1.81 is therefore used to discover omissions and
cross-check semantics, not to roll the module back to the older profile
versions. A change was implemented only when it also agreed with the newer
manual XCCDF shipped in those Ansible roles.

Run the repeatable profile inventory after recollecting the datastreams:

```powershell
./tools/compare_ssg_profiles.ps1
```

## Implemented findings

| Area | Finding | Module change |
| --- | --- | --- |
| Packages | RHEL 8 lacked AIDE, fapolicyd, Postfix, and USBGuard installation and did not remove `krb5-server`; RHEL 9 lacked AIDE, `cronie`, and explicit `tftp-server` removal. | Updated `stigs::packages` with common and release-specific resources. |
| Services | RHEL 8 did not enforce running fapolicyd, firewalld, sshd, or USBGuard and did not stop the debug shell and kdump. | Updated the RHEL 8 branch of `stigs::services`. |
| SSSD | The profile selects OCSP verification and one-day offline credential expiration on all releases. The selected digest is SHA-1 on RHEL 8 and SHA-512 on RHEL 9 and 10. | Added release-specific mode-`0600` `certificate_verification.conf` assets under `conf.d`, and applied the existing protected `sssd.conf` to RHEL 8 as well as RHEL 9. |
| Audit | The RHEL 9 asset omitted `umount`/`umount2`, 32-bit identity/logon rules, and cron watches; it also used `/etc/opasswd` instead of `/etc/security/opasswd`. | Corrected the path and added the current V2R9 rules with architecture-specific entries and the current `privileged-umount` key. |

The SSG-generated Puppet fixes were reviewed but not imported wholesale. They
cover only 44 to 52 selected rules per release and consist primarily of
package and service resources. Existing native Puppet resources and reviewed
whole-file assets continue to implement the rest.

## RHEL 10 differences

The RHEL 10 profile selects 34 logical rules not selected by either RHEL 8 or
RHEL 9:

- audit additions: `fchmodat2`, `renameat2`, `tallylog`, `modprobe`, `pkexec`,
  `rmmod`, and separate unsuccessful `rename`, `renameat`, `unlink`, and
  `unlinkat` rules;
- boot and cryptography: FIPS enablement/boot verification and the Kerberos
  crypto-policy link;
- packages and services: removal of GDM, TFTP, and Unbound; installation of
  `pcsc-lite-ccid`, `sequoia-sq`, and SSSD; and enablement of SSSD;
- scheduled work and updates: a periodic AIDE check, automatic DNF updates,
  and ownership/mode checks for `cron.allow` and `crontab`;
- SSH and networking: an SSH client rekey limit, IPv4 forwarding disabled,
  and `net.ipv4.tcp_invalid_ratelimit` set to the profile selector value 500;
- account/file checks: last-login display, user initialization file modes, and
  preventing initialization files from running world-writable programs; and
- site-dependent NFS controls requiring Kerberos security for mounts and
  exports.

At the time of this SSG comparison, RHEL 10 was not enabled in `stigs::main`
and the SSG profile was not treated as a versioned DISA benchmark. The later
official V1R2 XCCDF review added the file catalog documented in
`RHEL10_V1R2_FILE_REVIEW.md`; package, service-state, permission, and complete
VM catalog/OpenSCAP validation remain outstanding. The collected differences
above remain part of that non-file implementation backlog.

## Remaining boundaries

The comparison does not turn site-specific settings into universal files.
FIPS activation, fapolicyd policy, AIDE database/schedule and notification,
PAM/authselect design, NFS mount/export policy, USBGuard allowlists, remote log
endpoints, repository configuration, and organizational trust anchors remain
explicit deployment decisions in `CONTROL_GAPS.md`.

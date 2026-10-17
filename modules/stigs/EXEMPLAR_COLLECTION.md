# RHEL exemplar collection and comparison

This document describes how to collect configuration evidence from disposable
RHEL 8, 9, and 10 reference VMs, compare it with this module, and create
reviewed assets below `modules/stigs/files/`.

## SSH key location

Keep the private key outside this repository and outside the OneDrive-backed
workspace. On the workstation used for this repository, the recommended path
is:

```text
C:\Users\chris\.ssh\openvox_stig_audit_rsa
```

The corresponding `.pub` file may be copied to the VMs. Never copy the private
key into `puppet-rhel-stig`, commit it, or place it in a shared or synchronized folder.

Use RSA 3072 for compatibility with reference VMs that may have FIPS mode
enabled. From PowerShell:

```powershell
New-Item -ItemType Directory -Force "$HOME\.ssh" | Out-Null
ssh-keygen -t rsa -b 3072 -a 100 -f "$HOME\.ssh\openvox_stig_audit_rsa" -C "openvox STIG reference audit"
```

Set a passphrase. Load the key into an SSH agent before collection, or enter
the passphrase when SSH prompts for it. Do not send the passphrase through
chat or store it in an SSH config file.

An optional per-user SSH config at `C:\Users\chris\.ssh\config` can give the
VMs stable aliases:

```sshconfig
Host openvox-rhel8
    HostName 192.0.2.8
    User stig-audit
    IdentityFile ~/.ssh/openvox_stig_audit_rsa
    IdentitiesOnly yes

Host openvox-rhel9
    HostName 192.0.2.9
    User stig-audit
    IdentityFile ~/.ssh/openvox_stig_audit_rsa
    IdentitiesOnly yes

Host openvox-rhel10
    HostName 192.0.2.10
    User stig-audit
    IdentityFile ~/.ssh/openvox_stig_audit_rsa
    IdentitiesOnly yes
```

Replace the documentation-only addresses with the VM addresses. On first
connection, verify each displayed host-key fingerprint using the VM console.
Do not disable `StrictHostKeyChecking`.

## Reference VM preparation

Prepare one clean VM for each major release and record the exact RHEL release,
OpenSCAP profile, benchmark version, tailoring file, remediation command, and
scan results. Take a snapshot after installing RHEL and another after applying
remediation so findings can be reproduced.

Create the same temporary `stig-audit` account on each VM and install only the
public key in its `~/.ssh/authorized_keys`. The account needs ordinary SSH
access plus read access to the configuration paths under review. Some files,
including `/etc/sssd/sssd.conf`, are root-readable only.

Prefer either of these access models:

1. Run a reviewed, root-owned collection script locally on each VM. The script
   copies only an explicit allowlist of paths into a root-owned staging area,
   removes secrets, and makes the resulting archive readable by `stig-audit`.
2. On disposable, isolated lab VMs only, grant the temporary account narrowly
   scoped passwordless sudo access to a root-owned read-only wrapper. The
   wrapper must accept only allowlisted paths and operations. Do not grant
   unrestricted `sudo`, shell access as root, or broad commands such as
   `find`, `tar`, or an editor.

Remove the account, public key, sudo rule, and staging archive when the work is
complete. The private key can also be deleted if it was created only for this
exercise.

## Information needed when the VMs are ready

Provide the three SSH aliases, confirm that their host keys were verified, and
identify the allowed sudo or collection mechanism. Also provide the OpenSCAP
profile and benchmark details. Do not provide private keys, passwords, or
tokens; the key remains at the workstation path above.

Before collecting files, the workflow will verify each host with read-only
commands such as:

```sh
cat /etc/redhat-release
uname -r
rpm -q scap-security-guide openscap-scanner
```

## Collection boundaries

The initial allowlist is derived from Puppet `source` paths in
`modules/stigs/manifests/` and their corresponding destinations. Related drop-in
directories may be inventoried because the effective setting can come from a
different file. Collection remains read-only and does not rerun remediation,
restart services, or change a VM.

The following must be removed or replaced with documented placeholders before
an exemplar is saved:

- password hashes, private keys, tokens, and credentials;
- host certificates, machine IDs, and generated identifiers;
- organization-specific hostnames, addresses, domains, users, and endpoints;
- SSSD secrets and environment-specific identity-provider data;
- site-specific log, mail, proxy, repository, and time sources unless they are
  deliberately represented as parameters.

File content, owner, group, mode, SELinux context, package provenance, and the
effective configuration are evidence. Raw collections and normalized scratch
files are temporary artifacts and must not be added below `modules/stigs/files/`.

## Comparison and normalization

Every raw file is hashed and retained unchanged in a temporary directory for
the duration of the review. A separate normalized representation may then be
used to detect equivalent RHEL 8 and 9 content despite harmless ordering or
formatting differences.

Normalization is format-aware:

- unordered sets of independent entries may be sorted for comparison;
- comments, blank lines, whitespace, and generated headers may be normalized
  only when they do not change meaning;
- INI sections and repeated keys are compared within their semantic scope;
- `sshd_config`, sudoers, PAM configuration, audit rules, systemd units and
  drop-ins, shell files, and other precedence-sensitive files are not blindly
  sorted;
- effective-output tools such as `sshd -T`, `systemd-analyze cat-config`,
  `sysctl`, and `auditctl` may supplement file comparisons when available.

Sorting is therefore a comparison aid, not a rewrite rule. A deployable
exemplar preserves a valid and intentional order.

For each destination, compare:

1. the raw files from RHEL 8, 9, and 10;
2. normalized semantic representations where safe;
3. the current asset below `modules/stigs/files/`;
4. the effective configuration and relevant OpenSCAP finding;
5. vendor defaults versus changes introduced by remediation.

## Exemplar naming and Puppet changes

An unnumbered asset should ultimately mean that its content is valid for every
supported release. Use `.8`, `.9`, or `.10` when content is release-specific.
If two releases share content and a third differs, a shared suffix such as
`.8-9` may be used only after the corresponding manifest explicitly maps both
releases to it.

The existing module predates RHEL 10 support: some unnumbered files currently
mean only “identical on RHEL 8 and 9,” and `stigs::main` currently rejects
release 10. Do not reinterpret those assets or enable RHEL 10 merely because a
reference file was collected. RHEL 10 facts, packages, services, controls,
file sources, and catalog behavior require a separate manifest review.

Only sanitized, reviewed exemplars are written below `modules/stigs/files/`. When an
asset changes, update its functional manifest in the same change and preserve
whole-file ownership warnings from the module README.

## Validation and deliverables

Before accepting an exemplar change:

- validate syntax with the configuration's native checker where one exists;
- compile Puppet catalogs for every affected RHEL major release;
- verify file source paths, ownership, mode, and service notifications;
- rerun the relevant OpenSCAP checks on disposable snapshots when possible;
- review the Git diff for secrets and unintended site-specific values.

The final handoff should include the exemplar files, necessary Puppet changes,
a per-file comparison table, the normalization method used, unresolved
differences, validation results, and the source release/profile metadata.

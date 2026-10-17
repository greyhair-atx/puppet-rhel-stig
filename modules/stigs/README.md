# stigs

This repository provides STIG hardening automation for RHEL 8, 9, and 10 using Puppet and OpenVox. STIG compliance has not been validated, and the code has not been rigorously tested. Implemented controls and coverage reports do not establish host compliance. Review site-specific settings, test on disposable systems, and validate applicable STIG requirements before production use.

Native Puppet STIG hardening automation for the controls in the RHEL 8 V2R8 and RHEL 9
V2R9 STIG Ansible roles, plus the reviewed whole-file controls from the RHEL
10 V1R2 manual XCCDF. The module has no Puppet Forge dependencies.

## Usage

Use environment Hiera `classes` to assign `stigs::main` globally in
`data/common.yaml` or only in selected node/project files. See
[HIERA.md](../../HIERA.md) for the environment layout and merge behavior.

```puppet
include stigs::main
```

The compatibility entry point below applies the same catalog:

```puppet
include stigs
```

## Whole-file ownership

Every file represented under `files/` is authoritative. Puppet replaces the
entire destination file with the module asset; it does not edit individual
lines. Settings that existed on a node but are absent from an asset are
removed. Review site-specific settings before deployment, especially:

- `/etc/ssh/sshd_config`
- `/etc/login.defs`
- `/etc/rsyslog.conf`
- `/etc/audit/auditd.conf`
- `/etc/audit/rules.d/audit.rules`
- `/etc/selinux/config`

Files below `/etc` mirror their destination directory beneath `files/`. The
two vendor systemd unit files from the Ansible role are stored below
`files/usr/lib/systemd/system/`.

Files with identical content across their applicable releases use one
unnumbered asset. When content differs, `.8`, `.9`, and `.10` assets are
selected in the same functional manifest using
`$facts['os']['release']['major']`. Controls present on only one release are
guarded by that same fact; separate OS-specific manifests are not used.

RHEL 10 uses `.10` assets where its complete content differs and shared
unnumbered assets where it is identical, selected in the same functional
manifests as RHEL 8 and RHEL 9. The RHEL 10 branches manage only the reviewed
files; the package, service-state, and permission resources remain guarded for
RHEL 8/9. Review and parameterize the site-specific values documented in
`RHEL10_V1R2_FILE_REVIEW.md`, especially the preserved `logcollector` rsyslog
endpoint, before deployment.

## Site-specific file sources

Every STIG-controlled file uses network node (trusted certname), network
project, network role, network default, then shared default precedence. At each level, the OS major version variant is tried before the generic file.
Overrides use dot suffixes beside each default file; the existing reviewed
assets remain the shared defaults. Pass base filenames without OS suffixes to the helper; it inserts the OS major version before the network suffix.
See [Network overrides](../../NETWORK_OVERRIDES.md) for exact paths, examples,
missing-value behavior, and migration from the old suffix-based overrides.

## Package-state overrides

`stigs::packages` retains its current RHEL 8 and RHEL 9 package states as the
defaults. A Hiera entry can explicitly replace `ensure` with `installed` or
`absent`, including reversing the module default. Package override data is
deep-merged across matching files in the environment's `hiera.yaml` order:
node, project, role, region, zone, network, environment defaults, then common in the supplied hierarchy.
Module `data/common.yaml` supplies built-in defaults only. See
[HIERA.md](../../HIERA.md) for network-qualified filenames and migration.

For example, to install `nfs-utils` on a RHEL 9 host even though the STIG
default is `absent`, place this in the applicable hierarchy file:

```yaml
stigs::packages::package_overrides:
  nfs-utils:
    ensure: installed
```

To reverse an installed default, explicitly select `absent`:

```yaml
stigs::packages::package_overrides:
  usbguard:
    ensure: absent
```

Overrides may target only packages in the effective default map for the
node's OS; unknown names fail catalog compilation instead of being silently
ignored. The class manages package state on RHEL 8, RHEL 9, and RHEL 10.

## File-permission overrides

`stigs::permissions` manages the fixed-path owner, group, and mode controls
from the three reviewed STIGs. The defaults cover `/var/log` and
`/var/log/messages` on all three releases, the account database and backup
files on RHEL 9 and RHEL 10, and `/boot/grub2/grub.cfg` ownership on RHEL 9.

Each attribute can be overridden independently at the network node (certname), project, or
role hierarchy level. For example, this changes only the group for one file
and retains its default owner and mode:

```yaml
stigs::permissions::file_overrides:
  /var/log/messages:
    group: adm
```

All three attributes may be replaced together:

```yaml
stigs::permissions::file_overrides:
  /var/log/messages:
    owner: root
    group: root
    mode: '0600'
```

Modes must be quoted four-digit octal strings. Overrides may target only
paths with defaults for the node's OS; unknown paths fail catalog compilation
to catch misspellings. Dynamic STIG checks covering collections such as all
system commands, libraries, audit logs, or user home directories are not
represented as fixed paths in this class.

As an explicit common hardening policy, `stigs::modprobe_d` applies a common
nine-module deny list to RHEL 8, RHEL 9, and RHEL 10. All nine files have
direct RHEL 8 vulnerability IDs. On RHEL 9, `uvcvideo` is additional
defense-in-depth; on RHEL 10, `atm`, `cramfs`, `firewire-core`, and `uvcvideo`
are defense-in-depth settings rather than claims of direct release-specific
control coverage.

Packages, services, ownership, modes, and directories use native Puppet
resources. Commands are limited to operations for which core Puppet has no
equivalent resource type: systemd masking/reload, audit rule loading, sysctl
loading, dconf database updates, and disabling wireless radios.

## Regeneration

The `ansible/` directory is not required to deploy or run this Puppet module
and is no longer tracked. Regeneration and XCCDF audit tools still use it as
an optional local input directory, excluded by `.gitignore`. Before running
those tools on a fresh checkout, obtain the source DISA packages separately
and extract them into the paths expected by the scripts:

```text
ansible/U_RHEL_8_V2R8_STIG_Ansible/rhel8STIG-ansible/roles/rhel8STIG/
ansible/U_RHEL_9_V2R9_STIG_Ansible/rhel9STIG-ansible/roles/rhel9STIG/
ansible/U_RHEL_10_V1R2_STIG/U_RHEL_10_V1R2_Manual_STIG/
```

The RHEL 8/9 role directories include their corresponding manual XCCDF files.
Use the exact package revisions named above to reproduce the existing reports.

Run from the repository root after changing the source Ansible role. When VM
snapshots are available, pass their root so the generated STIG fragments are
overlaid onto the release-specific vendor files before assets are selected:

```powershell
./tools/merge_rhel8_rhel9_stigs.ps1 `
  -SnapshotRoot .ps_sandbox/vm-file-munging
```

`generate_rhel8_stigs.ps1` is the single-role normalization helper called by
the merge generator and is not required when deploying the Puppet module.
Omitting `-SnapshotRoot` regenerates fragment-only assets and does not preserve
the full vendor configurations collected from the reference VMs.

## Collecting exemplar files from reference systems

See [EXEMPLAR_COLLECTION.md](EXEMPLAR_COLLECTION.md) for the SSH setup,
reference-VM preparation, collection boundaries, normalization rules, and
review workflow for comparing RHEL 8, 9, and 10 systems.

## Comparing installed SSG profiles

Collect `ssg-rhel8-ds.xml`, `ssg-rhel9-ds.xml`, and `ssg-rhel10-ds.xml` from
`/usr/share/xml/scap/ssg/content/` into the ignored
`.ps_sandbox/ssg_datastreams/` directory, then run:

```powershell
./tools/compare_ssg_profiles.ps1
```

See [SSG_COMPARISON.md](SSG_COMPARISON.md) for source hashes, profile counts,
implemented findings, RHEL 10 deltas, and the boundary between automatically
deployable controls and site-specific policy.

## Known gaps and site-specific controls

See [CONTROL_GAPS.md](CONTROL_GAPS.md) for SCC comparison findings, incomplete
controls that require design decisions, and files that must not be replaced
with universal whole-file assets. See
[MANUAL_XCCDF_GAPS.md](MANUAL_XCCDF_GAPS.md) for the generated, `V-`-keyed
comparison of the RHEL 8 V2R8, RHEL 9 V2R9, and RHEL 10 V1R2 manual XCCDF
settings that are not represented in the current files and manifests. The
complete covered/not-covered matrix, including the matching Puppet manifest
for every covered `V-` ID, is in
[MANUAL_XCCDF_MODULE_COVERAGE.md](MANUAL_XCCDF_MODULE_COVERAGE.md).

## License

Original project code and documentation are licensed under the [MIT License](../../LICENSE), copyright (c) 2026 Chris Thornton. Third-party material retains its applicable licenses; see [third-party notices](../../THIRD_PARTY_NOTICES.md).

# Network-specific files and settings

Both `custom` and `stigs` support one mirrored codebase containing every
network's configuration. The network comes from
`$trusted['extensions']['pp_network']`; project and role come from `pp_project`
and `pp_role` in the same hash. Node identity is `$trusted['certname']`.

## File selection

Overrides sit beside the shared default, using dot-separated suffixes.
Puppet selects the first existing source in this order:

| Priority | Filename |
| --- | --- |
| 1: OS network node | `filename.ending.<os>.<network>.<certname>` |
| 2: Network node | `filename.ending.<network>.<certname>` |
| 3: OS network project | `filename.ending.<os>.<network>.<project>` |
| 4: Network project | `filename.ending.<network>.<project>` |
| 5: OS network role | `filename.ending.<os>.<network>.<role>` |
| 6: Network role | `filename.ending.<network>.<role>` |
| 7: OS network default | `filename.ending.<os>.<network>` |
| 8: Network default | `filename.ending.<network>` |
| 9: OS shared default | `filename.ending.<os>` |
| 10: Shared default | `filename.ending` |

For RHEL 9 audit configuration on network `A1`, project `alpha`, role
`workstation`, and certname `pc01.example.test`, put any overrides alongside
the default in `modules/stigs/files/audit/`:

```text
auditd.conf.9.A1.pc01.example.test
auditd.conf.A1.pc01.example.test
auditd.conf.9.A1.alpha
auditd.conf.A1.alpha
auditd.conf.9.A1.workstation
auditd.conf.A1.workstation
auditd.conf.9.A1
auditd.conf.A1
auditd.conf.9
auditd.conf
```

For dnsmasq, the same pattern applies in `modules/custom/files/dnsmasq/dnsmasq.d/`:

```text
custom.conf.A1.pc01.example.test
custom.conf.A1.alpha
custom.conf.A1.workstation
custom.conf.A1
custom.conf
```

Only create the variants you need; OS-specific and generic files can coexist.
`<os>` is `$facts['os']['release']['major']`, such as `8`, `9`, or `10`.
Each level tries its OS-specific file before its generic file. A generic node
file therefore wins over an OS-specific project file. The dnsmasq example above
works for every supported release; add `.9` immediately after `custom.conf`
for any variant that should apply only to RHEL 9.

Call `custom::source_candidates` or `stigs::source_candidates` with the base
source URI without an OS suffix, for example
`stigs::source_candidates('puppet:///modules/stigs/audit/auditd.conf')`.
The function adds the suffix; it does not strip numbers from the supplied name.
Contents are replaced as a whole, not merged. A missing file
falls through to the next candidate; if none exists, the file resource fails.
Missing or empty network tries the OS shared default, then the generic shared
default. Missing or empty project, role, or certname omits both candidates at
that level. Missing or empty OS major version omits OS-specific candidates;
a nonempty OS major version must be a string of digits. Identifiers must start with
a letter or digit and contain only letters, digits, underscores, dots, or
hyphens; invalid identifiers fail compilation when a network is selected.

Because these suffixes have no type labels, identical project, role, or
certname values refer to the same file. Choose distinct identities when
separate files are needed. Also avoid dotted network names that can collide
with another network plus an identity (for example `A1.alpha` versus network
`A1` with project `alpha`).

All module `source` file resources use this selection, including both dnsmasq
configurations, branding, logrotate, timers, helpers, and STIG assets.
Templates and generated `content` resources continue to render their data;
configure those through Hiera.

## Hiera settings

Environment Hiera controls class assignment and settings through node, project,
role, region, zone, network, and common data. See [HIERA.md](HIERA.md) and the
root-level `hiera.yaml` and `manifests/site.pp`. Module Hiera files contain only built-in
defaults. The dot-separated filenames above apply to managed file sources, not
the environment's YAML search hierarchy.

## Migration

Before deploying, rename existing overrides for their intended network:

- `<filename>.<hostname>` becomes `<filename>.<network>.<certname>`.
- `<filename>.<project>` becomes `<filename>.<network>.<project>`.
- `<filename>.<role>` becomes `<filename>.<network>.<role>`.
- Existing custom `<filename>.<network>` overrides stay in place.

Old unscoped node/project/role overrides are no longer selected as those tiers.
Review legacy suffixes that happen to equal a network name: they now identify
that network's default. Existing OS-specific overrides such as `auditd.conf.9.A1` stay in place. A generic override such as `auditd.conf.A1` now applies across releases. For RHEL 10, overrides of the session lock, certificate verification, or reverse-path filter previously named `.9.<network>...` must be copied to `.10.<network>...` or renamed without the OS suffix if intended for both releases. Shared source assets stay in place. See
[HIERA.md](HIERA.md) for environment data migration. No production network identities or override
contents are invented by this change. PDF guides and ZIP snapshots remain
historical artifacts; these Markdown guides describe the current source.

## Validation

With Puppet's Ruby environment loaded, run `ruby tools/test_network_sources.rb`.
The checks compile catalogs without applying resources, verify source ordering,
missing/invalid identity behavior, and dnsmasq integration. Run
`ruby tools/test_environment_hiera.rb` separately for environment Hiera checks.
Run `ruby tools/test_stig_sources.rb` to compile the complete STIG catalogs for
RHEL 8, 9, and 10 and check that every managed source resolves to a shipped file.

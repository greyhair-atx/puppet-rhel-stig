# custom

This repository provides STIG hardening automation for RHEL 8, 9, and 10 using Puppet and OpenVox. STIG compliance has not been validated, and the code has not been rigorously tested. Implemented controls and coverage reports do not establish host compliance. Review site-specific settings, test on disposable systems, and validate applicable STIG requirements before production use.

Site-specific branding and GNOME classification banners for RHEL 8, 9, and
10.

## Usage

For Hiera-driven class assignment and settings, see [HIERA.md](../../HIERA.md).
The environment controls the node/project/role/region/zone hierarchy; this
module's Hiera configuration supplies built-in defaults only.

```puppet
include custom::branding
include custom::classification_banner
```

The two classes are independent. Include either one or both, as needed. Each
class declares the shared `custom::dconf` class when graphical management is
enabled.

The module manages graphical resources only when the `custom_gui` fact is
true. The fact requires an X11 or Wayland session definition together with a
graphical default target, configured display manager, or active graphical
session. Override
`custom::branding::manage_gui` and
`custom::classification_banner::manage_gui` through Hiera for unusual desktop
configurations.

## Branding image

Before applying `custom::branding` to a graphical system, add the logo here:

```text
modules/custom/files/branding/corp-logo.png
```

The image is installed as `/usr/local/share/corp/corp-logo.png`. Red Hat
recommends a universally readable image of approximately 48 pixels in height.
The same default image is used on RHEL 8, 9, and 10.

File sources use network node (trusted certname), network project, network role,
network default, then shared default precedence. At each level, the OS major version variant is tried before the generic file. See
[Network overrides](../../NETWORK_OVERRIDES.md) for the filename suffixes, Hiera
settings, and required migration from the old suffix-based overrides.

## Classification banners

The trusted extension `pp_network` must be one of `network1`, `network2`,
`network3`, or `network4`. Each has an explicit profile in
`custom::classification_banner::network_profiles`.

The package is available on RHEL 8.6 and newer and under the same package name
on RHEL 9 and RHEL 10. The module manages both the GDM login-screen database
and the local user-session database, locks the configured keys, and runs
`dconf update` after changes.

## Log rotation

Include `custom::logrotate` to manage `/etc/logrotate.conf` and
`/etc/logrotate.d/rsyslog`. Their module source files contain the site rotation
policy and can use the normal `custom::source_candidates` overrides.

## Puppet agent timer

Include `custom::puppet_timer` to install and enable
`ces-puppet-agent-run.timer`. It runs
`/opt/puppetlabs/bin/puppet agent -t` on the configured weekday and weekend
schedules. Changes to either systemd unit invoke `systemctl daemon-reload` and
refresh the timer.

## RPM installation

Include `custom::rpm_install` to install package names supplied by Hiera:

```puppet
include custom::rpm_install
```

The `custom::rpm_install::rpms` array uses Hiera's `unique` merge strategy, so
packages can be added at multiple hierarchy levels without replacing entries
from lower-priority data:

```yaml
custom::rpm_install::rpms:
  - package-one
  - package-two

custom::rpm_install::xrpms:
  - unwanted-package
```

Both arrays use a unique merge across the Hiera hierarchy. Packages in `rpms`
are installed and packages in `xrpms` are removed. A package cannot appear in
both arrays. The configured package repositories must provide each package
listed in `rpms`.

## Controlled hosts

Include `custom::hosts` to manage the workstation, OpenVox server, and any
additional controlled records in `/etc/hosts`:

```puppet
include custom::hosts
```

Set `custom::hosts::site_defaults` in any matching environment Hiera file.
For example, use `code/production/data/network/A1.yaml` for network defaults:

```yaml
custom::hosts::site_defaults:
  openvox_entry:
    ip: 192.0.2.10
    fqdn: openvox.chicago.example.test
    hostname: openvox
    alias: puppet
  additional_entries:
    - ip: 192.0.2.11
      fqdn: dc01.chicago.example.test
      hostname: dc01
      alias: domain-controller
```

The workstation record continues to come from the device's networking facts.
The site/network file controls the other records.

A project can explicitly replace the OpenVox entry, the complete additional
entry list, or both in `data/project/<pp_network>.<pp_project>.yaml`:

```yaml
custom::hosts::project_overrides:
  additional_entries: []
```

Omitted keys retain their site/network defaults. An explicit empty
`additional_entries` array removes all additional site/network records.

## DNS resolver

Include `custom::resolver` to manage `/etc/resolv.conf` and prevent
NetworkManager from replacing it:

```puppet
include custom::resolver
```

Place resolver defaults in the same environment Hiera file used by
`custom::hosts`. This allows every network at a site to have different DNS
settings:

```yaml
# code/production/data/network/A1.yaml
custom::resolver::site_defaults:
  custom_ns:
    - 192.0.2.53
    - 192.0.2.54
  custom_search:
    - chicago.example.test
    - example.test
```

Declare overrides explicitly in `data/project/<pp_network>.<pp_project>.yaml`. The
manifest merges `project_overrides` over `site_defaults`; any key the project
omits continues to come from the site/network settings:

```yaml
# data/project/A1.special-project.yaml
custom::resolver::project_overrides:
  custom_ns:
    - 203.0.113.53
    - 203.0.113.54
  custom_search:
    - special.example.test
```

Set `custom_search: []` inside `project_overrides` to explicitly replace the
site/network search list and omit the `search` line. Every node using this class
must receive resolver `site_defaults` with at least one `custom_ns`;
`custom_search` defaults to an empty array when omitted from both structures.

## Dnsmasq

Include `custom::dnsmasq` to install dnsmasq on RHEL 8, 9, or 10, manage its
configuration, and enable and start its service:

```puppet
include custom::dnsmasq
```

The class includes `custom::rpm_install` and reuses its dnsmasq package when
`dnsmasq` is listed in `custom::rpm_install::rpms`. Otherwise it declares the
package itself with `ensure => installed`, leaving an already installed version
in place. Listing `dnsmasq` in `custom::rpm_install::xrpms` is an error.

The common configuration is copied from `modules/custom/files/dnsmasq/dnsmasq.conf`
to `/etc/dnsmasq.conf`. Keep its `conf-dir=/etc/dnsmasq.d,*.conf` directive
so dnsmasq loads the project configuration.

For network projects that need their own settings, copy `custom.conf.example`
beside the default file with network and project suffixes, for example:

```text
modules/custom/files/dnsmasq/dnsmasq.d/custom.conf.A1.alpha
```

Both dnsmasq files use the shared source selection helper. Node overrides
use trusted certnames; project and role overrides are scoped to the trusted
network. See [Network overrides](../../NETWORK_OVERRIDES.md) for all five
selection levels. With no network, the OS shared default is tried before the generic shared default.
The selected project configuration is installed as `/etc/dnsmasq.d/custom.conf`;
changing network or project replaces the same destination. Other files in
`/etc/dnsmasq.d` are left in place. Changes to either managed configuration
restart dnsmasq. Invalid path identifiers fail compilation; if no candidate
exists, the file resource fails and blocks its dependent service action.

## SELinux booleans

Add `custom::selinux_boolean` to your environment Hiera `classes` list, and
define booleans by quoted RHEL major version, boolean name, and quoted state:

```yaml
classes:
  - custom::selinux_boolean

custom::selinux_boolean::set_booleans:
  '8':
    httpd_can_network_connect: 'on'
    httpd_enable_homedirs: 'off'
  '9':
    httpd_can_network_connect: 'off'
    httpd_enable_homedirs: 'on'
  '10':
    httpd_can_network_connect: 'off'
```

These are format examples, not recommended policy choices. Use boolean names
provided by your installed SELinux policy. Both OS keys and `on`/`off` values
must be quoted; YAML can otherwise interpret them as numbers or true/false.
Only the current OS's entries are managed. Missing or empty OS entries declare
no boolean resources. The class supports RHEL 8, 9, and 10.

The hash deep-merges across your environment Hiera hierarchy. A node or project
file can add booleans or replace individual states while retaining other
inherited entries. For example, a project can override only this RHEL 8 value:

```yaml
custom::selinux_boolean::set_booleans:
  '8':
    httpd_can_network_connect: 'off'
```

An empty hash does not remove inherited entries under deep merging. Removing
an entry from the effective configuration leaves that boolean unmanaged; it
does not reset its existing value.

The class installs `libselinux-utils`, `policycoreutils`, and
`policycoreutils-python-utils` when it has booleans to manage. It reuses package
declarations from `custom::rpm_install` and rejects those packages in `xrpms`.
No external Puppet module is required.

The helper checks both active and saved values with `semanage boolean --list`
and runs `setsebool -P` only when either differs. Settings persist across reboots.
Disabled SELinux, an unknown boolean, or a command failure causes a resource
failure instead of silently skipping the requested setting. The class does
not enable SELinux or install custom policy modules. Its helper source supports
the standard network/node/project/role filename overrides.

Run `ruby tools/test_selinux_boolean.rb` from the repository root with Puppet's
Ruby. It checks catalog generation, Hiera merging, and helper behavior using
simulated SELinux commands; live RHEL enforcement must be verified on a test node.

## LVM filesystem growth

Include `custom::lvm_resize` to grow configured LVM-backed filesystems:

```puppet
include custom::lvm_resize
```

The default targets are `/` and `/var`, each at `24G`. Override them through
Hiera when a role or project needs different whole-GiB targets:

```yaml
custom::lvm_resize::partitions:
  - mount: /
    size: 32G
  - mount: /var
    size: 48G
```

The class never shrinks storage. Facter first determines whether growth is
needed. Immediately before changing storage, a live check verifies that every
target is an LVM logical volume, that all targets share one volume group, and
that the group has enough free space for all required growth. The resize uses
`lvextend --resizefs` so the logical volume and filesystem grow together.

## PDF documentation

Landscape PDF guides for every custom class are in the repository's `doc`
directory. Regenerate them after module changes with:

```powershell
.\tools\generate_custom_module_docs.ps1
```

## License

Original project code and documentation are licensed under the [MIT License](../../LICENSE), copyright (c) 2026 Chris Thornton. Third-party material retains its applicable licenses; see [third-party notices](../../THIRD_PARTY_NOTICES.md).

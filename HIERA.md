# Environment Hiera and class assignment

The repository root is a complete Puppet environment: `hiera.yaml`,
`environment.conf`, `manifests/site.pp`, `data/`, and `modules/` are ready to
install together under your server's environment directory. See
[DEPLOYMENT.md](DEPLOYMENT.md) for installation and Git-based deployment to
`production`, `corp`, and `test`. Merge existing site data before replacing
an existing environment. This repository change does not deploy anything.

## Search order

The environment's `hiera.yaml` controls lookup order, highest priority first:

1. `data/node/<network>.<certname>.yaml`, then `data/node/<certname>.yaml`
2. `data/project/<network>.<project>.yaml`, then `data/project/<project>.yaml`
3. `data/role/<network>.<role>.yaml`, then `data/role/<role>.yaml`
4. `data/region/<network>.<region>.yaml`, then `data/region/<region>.yaml`
5. `data/zone/<network>.<zone>.yaml`, then `data/zone/<zone>.yaml`
6. `data/network/<network>.yaml`
7. `data/environment/<environment>.yaml`
8. `data/common.yaml`

Missing files are skipped. Network-qualified files are optional: use
`node/node.domain.name.yaml` and `project/alpha.yaml` for shared settings, or
`project/A1.alpha.yaml` when the same project needs different settings on A1.
All matching files participate according to each key's merge strategy.
Without matching specific or environment-default files, only `common.yaml` contributes;
module built-in defaults still supply otherwise undefined module parameters.

Certname is `trusted.certname`. The supplied hierarchy uses trusted extensions
`pp_network`, `pp_project`, `pp_role`, `pp_region`, and `pp_zone`. Region and zone
are assumed extension names: change those interpolation expressions if your
certificates or facts use different names. Environment defaults use `server_facts.environment`, so the same commit can supply different defaults in production, corp, and test. The directory names are singular,
matching your `node/`, `project/`, `role/`, `region/`, and `zone/` layout.
Do not create filenames with empty identifiers such as `.yaml` or `A1..yaml`.
Network-qualified and unqualified filenames share a directory; avoid identity
names that collide with a network-prefixed name.

## Combining classes and settings

`manifests/site.pp` uniquely merges the `classes` array from every matching
file and includes those classes. Class parameters are then resolved through
Puppet automatic parameter lookup using keys such as `custom::rpm_install::rpms`.
Hiera keys do not automatically become arbitrary Puppet variables.

Example `data/common.yaml`:

```yaml
lookup_options:
  classes:
    merge: unique
classes:
  - custom::rpm_install
custom::rpm_install::rpms:
  - common-package
```

Example `data/project/alpha.yaml`:

```yaml
classes:
  - stigs::main
custom::rpm_install::rpms:
  - project-package
```

Example `data/node/node.domain.name.yaml`:

```yaml
classes:
  - custom::logrotate
custom::rpm_install::rpms:
  - node-package
```

That node receives all three classes and all three package entries. With no
matching node/project files (and no other matching hierarchy files), it receives
only the common class and package. To apply STIGs everywhere, put `stigs::main`
in common's `classes`; to apply them only to selected projects, put it in those
projects' files. An empty class array does not subtract inherited classes.
The repository ships with `classes: []` so classification remains your choice.

Merging is per key, not a wholesale merge of YAML documents:

- Classes combine uniquely, enforced by `site.pp`.
- Scalars use the first value found (node before project before common).
- Arrays/hashes also use the first value unless `lookup_options` specifies a merge.
- The existing RPM arrays use `unique`; STIG package/permission override hashes
  use `deep`, as declared in module defaults.
- For another hash that should combine across levels, set its `lookup_options`
  strategy to `deep` in environment data. Do not enable deep merge globally:
  some arrays intentionally replace inherited values.

## Modules and migration

Both module-level `hiera.yaml` files now read only their `data/common.yaml`.
They define built-in defaults and merge policies, not node classification.
Environment data overrides these defaults; global Hiera, if configured, has
higher precedence than environment data.

Move any site data previously stored inside module data directories to the
environment. The earlier dot-suffixed Hiera examples map as follows:

- `common.yaml.<network>.<certname>` -> `node/<network>.<certname>.yaml`
- `common.yaml.<network>.<project>` -> `project/<network>.<project>.yaml`
- `common.yaml.<network>.<role>` -> `role/<network>.<role>.yaml`
- `common.yaml.<network>` -> `network/<network>.yaml`

For existing `sites/<location>_<network>.yaml`, either add that path to your
environment hierarchy at the desired priority or move its values to the
appropriate region/zone/network files. Hosts/resolver parameter names
`site_defaults` and `project_overrides` remain compatible and can be set from
any environment hierarchy level; their names do not select data directories.

Managed file sources still use the dot-suffix order in
[NETWORK_OVERRIDES.md](NETWORK_OVERRIDES.md). That source fallback selects file
contents; environment Hiera selects classes and parameter values independently.

## Checks

With Puppet's Ruby available, run `ruby tools/test_environment_hiera.rb` and
`ruby tools/test_network_sources.rb`. These compile catalogs without applying
resources. Puppet documents this model in its
[lookup reference](https://help.puppet.com/core/current/Content/PuppetCore/puppet_lookup.htm)
and [Hiera layers reference](https://help.puppet.com/core/current/Content/PuppetCore/hiera_config_layers.htm).

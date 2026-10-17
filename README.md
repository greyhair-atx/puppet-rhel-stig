# puppet-rhel-stig

STIG hardening automation for RHEL 8, 9, and 10 using Puppet and OpenVox.

This repository provides STIG hardening automation for RHEL 8, 9, and 10 using Puppet and OpenVox. STIG compliance has not been validated, and the code has not been rigorously tested. Implemented controls and coverage reports do not establish host compliance. Review site-specific settings, test on disposable systems, and validate applicable STIG requirements before production use.

This repository is one complete OpenVox/Puppet environment. Transfer a ZIP of
the repository to the remote network, import its extracted contents into one
Gitea repository, and create `test`, `corp`, and `production` branches from the
same initial commit.

Edit code in Gitea on `test`. After validation, use Gitea pull requests to
promote changes from `test` to `corp`, then from `corp` to `production`.
Each Puppet server environment is a Git checkout tracking its matching branch.
An existing scheduled job pulls updates every two minutes using `git pull
--ff-only`. This workflow uses Git, Gitea, and Puppet; r10k and Gitea Actions
are not used.

Install each checkout directly at `<environmentpath>/<environment>`, with
`hiera.yaml` at its root. Modules are included under `modules/` and need no
separate copy step.

```text
hiera.yaml
environment.conf
Puppetfile
manifests/site.pp
data/
  common.yaml
  node/
  project/
  role/
  region/
  zone/
  network/
  environment/{production,corp,test}.yaml
modules/
  custom/
  stigs/
```

[DEPLOYMENT.md](DEPLOYMENT.md) explains the initial ZIP import, branch creation,
server checkouts, web-based promotion, and scheduled pulls. The deployment job
must be configured on the remote network; this repository does not schedule
it automatically. Changes reach corp or production only after their branch
is updated and pulled. Puppet Server's cache refresh and subsequent agent runs
determine when nodes receive the new configuration.

[HIERA.md](HIERA.md) describes class assignment and parameter merging through
node, project, role, region, zone, network, environment, and common data.
Environment-specific defaults live in `data/environment/<environment>.yaml`,
so the same code can serve all three environments.
[NETWORK_OVERRIDES.md](NETWORK_OVERRIDES.md) describes the dot-separated
managed-file selection hierarchy. The trusted `pp_network` value and the
Puppet environment are independent selectors.

The initial class list is empty. Add classes to matching Hiera data before
expecting a catalog to manage resources. The `custom` and `stigs` modules are
tracked directly in this repository. The empty Puppetfile is not used by the
Git-pull workflow; no external Puppet modules need to be downloaded.

Run from the repository root using Puppet's Ruby:

```text
ruby tools/test_network_sources.rb
ruby tools/test_stig_sources.rb
ruby tools/test_environment_hiera.rb
ruby tools/test_environment_layout.rb
ruby tools/test_selinux_boolean.rb
```

PDF usage guides are in `doc/`. For transfer to the remote network, use a ZIP
of the complete current repository. Obsolete individual module ZIPs and the
duplicate root-level PDF are no longer included.

The deployed Puppet modules do not require Ansible. Source STIG packages under
`ansible/` are optional, ignored development inputs, not part of this repository's
current contents. Regeneration and audit tools require those inputs to be
obtained separately; see [STIG regeneration](modules/stigs/README.md#regeneration).

## License

Original project code and documentation are licensed under the [MIT License](LICENSE), copyright (c) 2026 Chris Thornton. Third-party material retains its applicable licenses; see [third-party notices](THIRD_PARTY_NOTICES.md).

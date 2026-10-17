# Deploying through Gitea: test, corp, and production

This repository provides STIG hardening automation for RHEL 8, 9, and 10 using Puppet and OpenVox. STIG compliance has not been validated, and the code has not been rigorously tested. Implemented controls and coverage reports do not establish host compliance. Review site-specific settings, test on disposable systems, and validate applicable STIG requirements before production use.

Use **one repository with three branches**, all sharing the same initial
history:

```text
test -> corp -> production
```

Transfer the code to the remote network as a ZIP. After the initial import,
edit files and promote changes through that network's Gitea web interface.
The Puppet server pulls each branch into its matching environment every two
minutes. This workflow needs only Git, Gitea, Puppet, and your scheduled update
job; it does not require r10k or a Gitea Actions runner.

## 1. Import the ZIP once

On a workstation inside the remote network:

1. Extract the ZIP.
2. Create an **empty repository** named `puppet-rhel-stig` in the remote Gitea. Do not initialize it
   with a README, license, or gitignore.
3. Open a terminal in the extracted directory containing `hiera.yaml`,
   `environment.conf`, `manifests/`, `data/`, and `modules/`.
4. Run the following commands, replacing the remote URL with the SSH clone
   URL shown by that Gitea repository:

```sh
git init
git add .
git commit -m "Initial Puppet environment"
git branch -M test
git remote add origin <SSH-URL-FROM-REMOTE-GITEA>
git push -u origin test

git branch corp
git branch production
git push origin corp production
```

A source ZIP contains files rather than Git history. These commands establish
new history on the remote network and create all three branches from the same
initial commit. Do not create three separate repositories or import the ZIP
independently into each branch. Git must have an author name/email configured,
and the workstation must have permission to push to the remote repository.

All three branches initially contain the same code. Configure class assignment
in Hiera before expecting managed resources: the supplied `data/common.yaml`
starts with `classes: []`.

## 2. Set up the Puppet server checkouts

Confirm the server's environment directory:

```sh
puppet config print environmentpath --section server
```

The commands below assume `/etc/puppetlabs/code/environments`. Substitute your
configured path if different. Clone into new, empty destinations, using the
remote network's Gitea SSH URL:

```sh
git clone --branch test --single-branch \
  <SSH-URL-FROM-REMOTE-GITEA> \
  /etc/puppetlabs/code/environments/test

git clone --branch corp --single-branch \
  <SSH-URL-FROM-REMOTE-GITEA> \
  /etc/puppetlabs/code/environments/corp

git clone --branch production --single-branch \
  <SSH-URL-FROM-REMOTE-GITEA> \
  /etc/puppetlabs/code/environments/production
```

Each checkout tracks its corresponding branch. If the environments are on
separate servers, clone only the branch needed by each server. Preserve and
merge existing environment data before replacing an existing installation.
The Puppet Server service account must be able to read the files. The account
running the update job needs write access to its checkouts and noninteractive
Git access; a read-only Gitea deploy key is sufficient for pulling.

The repository root is the environment root. Do not put an extra repository
folder between `production/` and `hiera.yaml`.

## 3. Edit and test using Gitea

In the Gitea repository's branch selector, choose **test**. Edit files and
commit changes to that branch.

Your Puppet server's two-minute update job pulls the test branch into its
test environment. Validate the resulting catalogs and behavior on test nodes
before promoting the changes. Each web edit is a commit that the next update
may deploy; for changes spanning several files, prepare them on a temporary
branch and merge the completed change into test together.

## 4. Promote test to corp

In Gitea:

1. Open **Pull Requests -> New Pull Request**.
2. Select **target/base: corp**.
3. Select **source/compare: test**.
4. Review the changes, create the pull request, and merge it.

The merge updates the corp branch. Its next scheduled pull receives those
changes. Validate the behavior on corp nodes before promoting further.

## 5. Promote corp to production

Repeat the pull-request process with the following branch selections:

| Promotion | Source/compare | Target/base |
| --- | --- | --- |
| Test to Corp | `test` | `corp` |
| Corp to Production | `corp` | `production` |

Keep all three branches after merging. Use regular merges and make ongoing
code edits in test so changes follow the same promotion path. Review the full
pull-request diff: it includes all pending changes from its source branch.

Nothing reaches corp or production merely because you edited test. The Gitea
merge is the promotion decision; the scheduled pull performs deployment.

## 6. Pull each branch every two minutes

Configure your existing scheduled update job to run:

```sh
git -C /etc/puppetlabs/code/environments/test pull --ff-only
git -C /etc/puppetlabs/code/environments/corp pull --ff-only
git -C /etc/puppetlabs/code/environments/production pull --ff-only
```

On separate servers, run only the command for that server's environment.
Check and log each command's exit status, and prevent overlapping runs against
the same checkout. `--ff-only` stops if the server checkout has diverged instead
of creating a deployment-side merge. Keep server checkouts clean; make durable
changes in Gitea.

These commands update files in place. Coordinate updates with catalog
compilation if a change must become visible as a complete unit. Puppet Server's
environment cache must refresh before it serves the new code, and agents apply
it on their subsequent runs. A two-minute Git update interval does not mean
all nodes apply the change within two minutes.

## Environment-specific settings

The same code can carry settings for all three environments:

```text
data/environment/test.yaml
data/environment/corp.yaml
data/environment/production.yaml
```

The hierarchy selects the matching file through `server_facts.environment`.
These defaults are below node, project, role, region, zone, and network data,
and above `common.yaml`. Track all three files in every branch so code can be
promoted without maintaining different edits to the same configuration file
on each branch. Class lists combine; environment data does not remove classes
inherited from common data. See [HIERA.md](HIERA.md) for merging behavior.

Agents must be assigned to the intended environment through their configuration
or your classifier. For an agent configured directly, for example:

```ini
[agent]
environment = test
```

The trusted `pp_network` extension remains separate from the Puppet environment.
Managed file variants continue to follow [NETWORK_OVERRIDES.md](NETWORK_OVERRIDES.md).

You can use master instead of test, but naming the branch test makes its
relationship to the Puppet environment clearer.

## References

- [Gitea pull requests](https://docs.gitea.com/usage/issues-prs/pull-request/)
- [Git clone](https://git-scm.com/docs/git-clone)
- [Git pull and --ff-only](https://git-scm.com/docs/git-pull)

# Third-party licensing

The MIT license covers original project code and documentation. It does not
relicense third-party material. Existing upstream notices and applicable
licenses continue to apply to bundled or derived content.

The following systemd-derived files retain their GNU Lesser General Public
License, version 2.1 or later, notices:

- `modules/stigs/files/systemd/coredump.conf`
- `modules/stigs/files/usr/lib/systemd/system/emergency.service`
- `modules/stigs/files/usr/lib/systemd/system/rescue.service`

License texts are included in `licenses/LGPL-2.1.txt` and `licenses/GPL-2.0.txt`
(the GPL text referenced by LGPL 2.1). The `stigs` module metadata lists both
MIT and LGPL-2.1-or-later because the module bundles material under different
licenses; it does not offer a choice to relicense the upstream files as MIT.

STIG-derived material and vendor configuration exemplars retain any applicable
upstream rights and terms. The source packages and revisions are documented in
`modules/stigs/README.md`. This notice is not a claim that all upstream content
is owned by this project's author or a complete provenance audit.

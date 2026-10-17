#!/usr/bin/env python3
"""Generate a data-driven Puppet module from RHEL STIG XCCDF XML files."""
from __future__ import annotations
import json, re, textwrap, xml.etree.ElementTree as ET
from hashlib import sha1
from pathlib import Path

ROOT = Path(__file__).resolve().parent
XML_DIR = ROOT / 'stig_xmls'
MODULE_DIR = ROOT / 'modules' / 'openvox_stig'
NS = {'xccdf': 'http://checklists.nist.gov/xccdf/1.1'}
FUNCTION_KEYWORDS = [
    ('ssh', ('ssh', 'sshd', 'secure shell')),
    ('audit', ('audit', 'auditd', 'audisp')),
    ('authentication', ('password', 'pki', 'certificate', 'pam', 'smart card', 'login', 'logon', 'account')),
    ('boot', ('grub', 'boot', 'ctrl-alt-delete', 'single-user', 'rescue', 'emergency')),
    ('crypto', ('fips', 'crypto', 'cryptographic', 'tls', 'ssl', 'hashing', 'encryption')),
    ('filesystem', ('partition', 'filesystem', 'file system', 'mount', '/tmp', '/home', '/var', 'permission', 'ownership')),
    ('network', ('firewall', 'nftables', 'network', 'ipv6', 'tcp', 'udp', 'wireless', 'bluetooth')),
    ('logging', ('rsyslog', 'journald', 'log file', 'logging', 'syslog')),
    ('packages', ('package', 'software', 'dnf', 'yum', 'rpm')),
    ('services', ('service', 'daemon', 'systemctl', 'timer')),
    ('kernel', ('kernel', 'sysctl', 'module', 'modprobe', 'kmod')),
    ('selinux', ('selinux', 'semanage', 'security context')),
    ('sudo', ('sudo', 'privilege', 'su command')),
    ('time', ('chrony', 'ntp', 'time synchronization')),
    ('aide', ('aide', 'integrity')),
    ('containers', ('container', 'podman', 'docker')),
    ('gui', ('graphical', 'gdm', 'dconf', 'gnome', 'x windows')),
]

def text_of(node):
    return '' if node is None or node.text is None else re.sub(r'\s+', ' ', node.text).strip()

def block_text(node):
    return '' if node is None else re.sub(r'\r\n?', '\n', ''.join(node.itertext())).strip()

def normalize_title(title):
    value = re.sub(r'\bRHEL\s+(8|9|10)\b', 'RHEL', title, flags=re.I)
    value = re.sub(r'\bRed Hat Enterprise Linux\s+(8|9|10)\b', 'Red Hat Enterprise Linux', value, flags=re.I)
    return re.sub(r'\s+', ' ', value).strip().lower()

def slugify(value):
    value = re.sub(r'[^a-z0-9]+', '_', normalize_title(value)).strip('_')
    return value[:70] or 'stig_control'

def classify(title, fixtext, check):
    haystack = f'{title}\n{fixtext}\n{check}'.lower()
    for function_name, keywords in FUNCTION_KEYWORDS:
        if any(keyword in haystack for keyword in keywords):
            return function_name
    return 'system'

def command_lines(fixtext):
    commands = []
    for raw in fixtext.splitlines():
        line = re.sub(r'^\$+\s*', '', raw.strip())
        line = re.sub(r'^sudo\s+', '', line)
        if re.match(r'^(dnf|yum|systemctl|authselect|grubby|chmod|chown|restorecon|setsebool|semanage|sysctl|update-crypto-policies|fips-mode-setup)\b', line):
            commands.append(line)
    return commands

def infer_actions(fixtext):
    actions = {key: [] for key in ('packages_present', 'packages_absent', 'services_enabled', 'services_disabled', 'services_masked', 'exec_commands')}
    for command in command_lines(fixtext):
        actions['packages_present'].extend(re.findall(r'\b(?:dnf|yum)\s+(?:-y\s+)?(?:install|install\s+-y)\s+([A-Za-z0-9_.+:-]+)', command))
        actions['packages_absent'].extend(re.findall(r'\b(?:dnf|yum)\s+(?:-y\s+)?(?:remove|erase|remove\s+-y)\s+([A-Za-z0-9_.+:-]+)', command))
        match = re.search(r'\bsystemctl\s+(?:enable\s+--now|enable|start)\s+([A-Za-z0-9_.@:-]+)', command)
        if match: actions['services_enabled'].append(match.group(1))
        match = re.search(r'\bsystemctl\s+(?:disable\s+--now|disable|stop)\s+([A-Za-z0-9_.@:-]+)', command)
        if match: actions['services_disabled'].append(match.group(1))
        match = re.search(r'\bsystemctl\s+mask(?:\s+--now)?\s+([A-Za-z0-9_.@:-]+)', command)
        if match: actions['services_masked'].append(match.group(1))
        actions['exec_commands'].append(command)
    return {key: sorted(set(value)) for key, value in actions.items()}

def parse_file(path):
    os_major = re.search(r'RHEL_(\d+)_', path.name).group(1)
    xml = ET.parse(path)
    rules = []
    for group in xml.findall('xccdf:Group', NS):
        rule = group.find('xccdf:Rule', NS)
        if rule is None: continue
        title = text_of(rule.find('xccdf:title', NS))
        fixtext = block_text(rule.find('xccdf:fixtext', NS))
        check = block_text(rule.find('xccdf:check/xccdf:check-content', NS))
        rules.append({
            'os': os_major, 'vuln_id': group.attrib.get('id', ''), 'srg': text_of(group.find('xccdf:title', NS)),
            'rule_id': rule.attrib.get('id', ''), 'severity': rule.attrib.get('severity', 'unknown'),
            'version': text_of(rule.find('xccdf:version', NS)), 'title': title,
            'cci': [text_of(ident) for ident in rule.findall('xccdf:ident', NS)], 'fixtext': fixtext, 'check': check,
            'function': classify(title, fixtext, check), 'actions': infer_actions(fixtext),
        })
    return os_major, rules

def build_controls():
    grouped, counts = {}, {}
    for path in sorted(XML_DIR.glob('U_RHEL_*_STIG_*_Manual-xccdf.xml')):
        os_major, rules = parse_file(path)
        counts[os_major] = len(rules)
        for rule in rules:
            key = normalize_title(rule['title'])
            control_id = f"{slugify(rule['title'])}_{sha1(key.encode()).hexdigest()[:8]}"
            control = grouped.setdefault(control_id, {
                'function': rule['function'],
                'title': re.sub(r'\bRHEL\s+(8|9|10)\b', 'RHEL', rule['title']),
                'severity': rule['severity'],
                'variants': {},
            })
            control['variants'][rule['os']] = {
                'vuln_id': rule['vuln_id'], 'rule_id': rule['rule_id'], 'version': rule['version'],
                'srg': rule['srg'], 'severity': rule['severity'], 'cci': rule['cci'], 'title': rule['title'],
                'fixtext': rule['fixtext'], 'check': rule['check'], **rule['actions'],
            }
    return dict(sorted(grouped.items())), counts

def write(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding='utf-8')

def pp_array(values):
    return '[' + ', '.join(f"'{value}'" for value in values) + ']'

def emit_module(controls, counts):
    functions = sorted({control['function'] for control in controls.values()})
    write(MODULE_DIR / 'metadata.json', json.dumps({
        'name': 'openvox-openvox_stig', 'version': '0.1.0', 'author': 'Generated from DISA RHEL STIG XML',
        'summary': 'Data-driven RHEL 8, 9, and 10 STIG Puppet module', 'license': 'Apache-2.0', 'source': 'local',
        'dependencies': [], 'operatingsystem_support': [{'operatingsystem': 'RedHat', 'operatingsystemrelease': ['8', '9', '10']}],
    }, indent=2) + '\n')
    write(MODULE_DIR / 'hiera.yaml', '---\nversion: 5\nhierarchy:\n  - name: "Generated STIG control data"\n    path: "common.json"\n    data_hash: json_data\n')
    write(MODULE_DIR / 'data' / 'common.json', json.dumps({
        'openvox_stig::controls': controls,
        'openvox_stig::enabled_functions': functions,
        'openvox_stig::manage_execs': False,
    }, indent=2, ensure_ascii=True) + '\n')
    write(MODULE_DIR / 'manifests' / 'init.pp', textwrap.dedent('''\
        # @summary Applies generated RHEL STIG controls for the current OS major version.
        class openvox_stig (
          Hash $controls = lookup('openvox_stig::controls'),
          Array[String] $enabled_functions = lookup('openvox_stig::enabled_functions'),
          Boolean $manage_execs = lookup('openvox_stig::manage_execs', { 'default_value' => false }),
        ) {
          $major = $facts['os']['release']['major']

          case $major {
            '8', '9', '10': {
              $controls.each |String $control_id, Hash $control| {
                if $control['function'] in $enabled_functions and has_key($control['variants'], $major) {
                  $variant = $control['variants'][$major]
                  openvox_stig::rule { $control_id:
                    title_text        => $variant['title'],
                    function_name     => $control['function'],
                    vuln_id           => $variant['vuln_id'],
                    rule_id           => $variant['rule_id'],
                    version           => $variant['version'],
                    srg               => $variant['srg'],
                    severity          => $variant['severity'],
                    cci               => pick($variant['cci'], []),
                    packages_present  => pick($variant['packages_present'], []),
                    packages_absent   => pick($variant['packages_absent'], []),
                    services_enabled  => pick($variant['services_enabled'], []),
                    services_disabled => pick($variant['services_disabled'], []),
                    services_masked   => pick($variant['services_masked'], []),
                    exec_commands     => pick($variant['exec_commands'], []),
                    manage_execs      => $manage_execs,
                  }
                }
              }
            }
            default: { fail("openvox_stig supports RHEL major versions 8, 9, and 10; got ${major}") }
          }
        }
        '''))
    write(MODULE_DIR / 'manifests' / 'rule.pp', textwrap.dedent('''\
        # @summary Applies the machine-manageable actions inferred for one STIG control.
        define openvox_stig::rule (
          String $title_text,
          String $function_name,
          String $vuln_id,
          String $rule_id,
          String $version,
          String $srg,
          String $severity,
          Array[String] $cci = [],
          Array[String] $packages_present = [],
          Array[String] $packages_absent = [],
          Array[String] $services_enabled = [],
          Array[String] $services_disabled = [],
          Array[String] $services_masked = [],
          Array[String] $exec_commands = [],
          Boolean $manage_execs = false,
        ) {
          $packages_present.each |String $package_name| {
            if ! defined(Package[$package_name]) { package { $package_name: ensure => installed } }
          }
          $packages_absent.each |String $package_name| {
            if ! defined(Package[$package_name]) { package { $package_name: ensure => absent } }
          }
          $services_enabled.each |String $service_name| {
            if ! defined(Service[$service_name]) { service { $service_name: ensure => running, enable => true } }
          }
          $services_disabled.each |String $service_name| {
            if ! defined(Service[$service_name]) { service { $service_name: ensure => stopped, enable => false } }
          }
          $services_masked.each |String $service_name| {
            exec { "openvox_stig ${name} mask ${service_name}":
              command => "/usr/bin/systemctl mask --now ${service_name}",
              unless  => "/usr/bin/systemctl is-enabled ${service_name} | /usr/bin/grep -q '^masked$'",
              path    => ['/usr/bin', '/bin'],
            }
          }
          if $manage_execs {
            $exec_commands.each |String $command_line| {
              exec { "openvox_stig ${name} ${command_line}":
                command   => $command_line,
                path      => ['/usr/local/sbin', '/usr/local/bin', '/usr/sbin', '/usr/bin', '/sbin', '/bin'],
                logoutput => on_failure,
              }
            }
          }
        }
        '''))
    for function_name in functions:
        write(MODULE_DIR / 'manifests' / f'{function_name}.pp', textwrap.dedent(f'''\
            # @summary Applies generated RHEL STIG controls in the {function_name} function group.
            class openvox_stig::{function_name} (
              Boolean $manage_execs = lookup('openvox_stig::manage_execs', {{ 'default_value' => false }}),
            ) {{
              class {{ 'openvox_stig':
                enabled_functions => {pp_array([function_name])},
                manage_execs      => $manage_execs,
              }}
            }}
            '''))
    function_list = '\n'.join(f'- `{name}`' for name in functions)
    write(MODULE_DIR / 'README.md', textwrap.dedent(f'''\
        # openvox_stig

        Generated Puppet module for DISA RHEL STIG XML content in `stig_xmls/`.

        This module groups controls by function and uses a `case` on `$facts['os']['release']['major']` to select RHEL 8, 9, or 10 variants only when the implementation data differs.

        ## Generated input counts

        - RHEL 8: {counts.get('8', 0)} rules
        - RHEL 9: {counts.get('9', 0)} rules
        - RHEL 10: {counts.get('10', 0)} rules
        - Grouped controls: {len(controls)}

        ## Usage

        Include all generated function groups:

        ```puppet
        include openvox_stig
        ```

        Include one function group:

        ```puppet
        include openvox_stig::ssh
        ```

        Select function groups with Hiera:

        ```yaml
        openvox_stig::enabled_functions:
          - ssh
          - audit
          - authentication
        ```

        By default, the module manages inferred native Puppet `package` and `service` resources and masks services where the STIG fix explicitly calls for `systemctl mask`. Other generated command lines are retained in `data/common.json` for traceability but are not executed unless `openvox_stig::manage_execs` is set to `true`.

        ## Function Groups

        {function_list}

        ## Regeneration

        ```powershell
        python generate_stig_module.py
        ```
        '''))

def main():
    controls, counts = build_controls()
    emit_module(controls, counts)
    print(f'Generated {len(controls)} grouped controls from {sum(counts.values())} STIG rules.')
    print(f'Wrote module to {MODULE_DIR.relative_to(ROOT)}')

if __name__ == '__main__':
    main()

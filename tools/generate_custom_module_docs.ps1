[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
    [string[]]$ModuleName
)

$ErrorActionPreference = 'Stop'

$chromeCandidates = @(
    (Join-Path $env:ProgramFiles 'Google\Chrome\Application\chrome.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'Google\Chrome\Application\chrome.exe'),
    (Join-Path $env:ProgramFiles 'Microsoft\Edge\Application\msedge.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe')
)
$chrome = $chromeCandidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
if (-not $chrome) {
    throw 'Google Chrome or Microsoft Edge is required to generate the PDF documentation.'
}

$docDirectory = Join-Path $RepositoryRoot 'doc'
$scratchDirectory = Join-Path $RepositoryRoot '.ps_sandbox\custom-module-docs'
$profileDirectory = Join-Path $scratchDirectory 'browser-profile'
New-Item -ItemType Directory -Force -Path $docDirectory, $scratchDirectory, $profileDirectory | Out-Null

function ConvertTo-HtmlText {
    param([AllowEmptyString()][string]$Text)
    [System.Net.WebUtility]::HtmlEncode($Text)
}

function Get-ModuleLayout {
    param([string[]]$Files)
    $lines = @('modules/custom/')
    foreach ($file in $Files) {
        $lines += "  $($file.Replace('\', '/'))"
    }
    $lines -join "`n"
}

$modules = @(
    @{
        Name = 'SELinux Boolean'
        FileName = 'Puppet_SELinux_Boolean_RHEL8-10.pdf'
        Purpose = 'Manage active and persistent SELinux boolean settings from OS-keyed Hiera data on RHEL 8, 9, and 10.'
        Behavior = 'Only the current RHEL major version is selected. Hiera deep-merges individual boolean entries; missing OS entries manage nothing. Quote OS keys and on/off values. The helper checks active and saved values, runs setsebool -P only on drift, and verifies convergence. Disabled SELinux, unknown booleans, and command failures fail the resource. Required RHEL packages are installed or reused from rpm_install; conflicting xrpms fail compilation. No external Puppet module is required. Removing an entry leaves it unmanaged, and an empty hash does not erase inherited entries.'
        Configuration = @'
# Environment Hiera; examples, not prescribed policy.
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
'@
        Files = @('manifests/selinux_boolean.pp', 'files/selinux/selinux_boolean.rb', 'functions/source_candidates.pp', 'manifests/rpm_install.pp', 'data/common.yaml')
    },
    @{
        Name = 'Dnsmasq'
        FileName = 'Puppet_Dnsmasq_RHEL8-10.pdf'
        Purpose = 'Install dnsmasq and manage its main and project-specific configuration on RHEL 8, 9, and 10.'
        Behavior = 'Both configuration files select network node (trusted certname), network project, network role, network default, then shared default. Overrides sit beside the default with .<network>.<certname>, .<network>.<project>, .<network>.<role>, or .<network> suffixes. Each level tries an optional OS major version suffix before the network suffix, then the generic file. Missing network tries the OS shared default, then the generic shared default. Invalid path identifiers fail catalog compilation. Puppet includes rpm_install, avoids duplicate package ownership, and rejects dnsmasq in xrpms. Configuration files are root-owned with mode 0644; changes notify the enabled, running dnsmasq service. The shipped default project configuration contains comments only.'
        Configuration = @'
include custom::dnsmasq

# Set trusted certificate extensions pp_network and pp_project.
# Copy files/dnsmasq/dnsmasq.d/custom.conf.example to
# files/dnsmasq/dnsmasq.d/custom.conf.<pp_network>.<pp_project>.
# Example project setting:
server=/project.example/192.0.2.53

# Keep dnsmasq out of custom::rpm_install::xrpms.
'@
        Files = @('manifests/dnsmasq.pp', 'files/dnsmasq/dnsmasq.conf', 'files/dnsmasq/dnsmasq.d/custom.conf', 'files/dnsmasq/dnsmasq.d/custom.conf.example', 'manifests/rpm_install.pp', 'data/common.yaml')
    },
    @{
        Name = 'Branding'
        FileName = 'Puppet_Branding_RHEL8-10.pdf'
        Purpose = 'Install a site logo and apply it to the GNOME login screen on graphical RHEL systems.'
        Behavior = 'The custom_gui fact gates graphical changes. The logo source supports network node (certname), network project, network role, and network default overrides, with optional OS-specific files at each level. Puppet writes and locks the GDM dconf key, then refreshes the dconf databases.'
        Configuration = @'
include custom::branding

custom::branding::manage_gui: true
custom::branding::logo_source: puppet:///modules/custom/branding/corp-logo.png
custom::branding::logo_path: /usr/local/share/corp/corp-logo.png
'@
        Files = @('manifests/branding.pp', 'manifests/dconf.pp', 'functions/source_candidates.pp', 'templates/override-logo.epp', 'files/branding/README.md')
    },
    @{
        Name = 'Classification Banner'
        FileName = 'Puppet_Classification_Banner_RHEL8-10.pdf'
        Purpose = 'Install and configure the GNOME classification banner for login and local user sessions.'
        Behavior = 'A trusted pp_network value selects one of four typed banner profiles. Puppet installs the extension, manages both GDM and local dconf databases and locks, and runs dconf update when content changes. RHEL 8 requires release 8.6 or newer.'
        Configuration = @'
include custom::classification_banner

# Override profiles through Hiera when site-specific text or colors are needed.
custom::classification_banner::manage_gui: true
'@
        Files = @('manifests/classification_banner.pp', 'manifests/dconf.pp', 'templates/classification-banner.epp')
    },
    @{
        Name = 'Dconf Support'
        FileName = 'Puppet_Dconf_RHEL8-10.pdf'
        Purpose = 'Provide the shared dconf directories and refresh command used by graphical custom classes.'
        Behavior = 'The support class creates the GDM and local databases and their lock directories. Its refresh-only exec runs dconf update after subscribing resources notify it.'
        Configuration = @'
# Normally contained automatically by branding or classification_banner.
contain custom::dconf
'@
        Files = @('manifests/dconf.pp')
    },
    @{
        Name = 'Controlled Hosts'
        FileName = 'Puppet_Hosts_RHEL8-10.pdf'
        Purpose = 'Maintain the workstation, OpenVox server, and additional controlled records in /etc/hosts.'
        Behavior = 'Site/network defaults and explicit project overrides are merged before Puppet renders a protected records file. A Ruby helper updates only the Puppet-controlled block in /etc/hosts and provides an idempotent check mode.'
        Configuration = @'
include custom::hosts

custom::hosts::site_defaults:
  openvox_entry:
    ip: 192.0.2.10
    fqdn: openvox.example.test
    hostname: openvox
    alias: puppet
  additional_entries: []
'@
        Files = @('manifests/hosts.pp', 'types/hostentry.pp', 'files/ces-puppet-hosts.rb')
    },
    @{
        Name = 'Log Rotation'
        FileName = 'Puppet_Logrotate_RHEL8-10.pdf'
        Purpose = 'Manage the main logrotate configuration and the rsyslog rotation policy.'
        Behavior = 'Both files use the standard custom source-candidate order, allowing network node (certname), network project, network role, and network default variants while retaining common defaults. Each level tries the OS-specific file before the generic file.'
        Configuration = @'
include custom::logrotate
'@
        Files = @('manifests/logrotate.pp', 'functions/source_candidates.pp', 'files/etc/logrotate.conf', 'files/etc/logrotate.d/rsyslog')
    },
    @{
        Name = 'LVM Resize'
        FileName = 'Puppet_LVM_Resize_RHEL8-10.pdf'
        Purpose = 'Grow configured LVM-backed filesystems when their current Facter size is below the desired target.'
        Behavior = 'Facter performs the catalog-level size gate. Immediately before resizing, a live check verifies that every mount is LVM-backed, every logical volume shares one volume group, and the group can satisfy all required growth. lvextend --resizefs grows the logical volume and filesystem together. The module never shrinks storage.'
        Configuration = @'
include custom::lvm_resize

custom::lvm_resize::partitions:
  - mount: /
    size: 24G
  - mount: /var
    size: 24G
'@
        Files = @('manifests/lvm_resize.pp', 'functions/source_candidates.pp', 'files/lvm_resize/check_lvm_resize.sh', 'files/lvm_resize/resize_lvm.sh')
    },
    @{
        Name = 'Puppet Agent Timer'
        FileName = 'Puppet_Agent_Timer_RHEL8-10.pdf'
        Purpose = 'Install and enable a business-hours-aware systemd timer for Puppet agent runs.'
        Behavior = 'Puppet manages the service and timer units through the standard source-candidate order. Unit changes trigger systemctl daemon-reload and refresh the enabled timer.'
        Configuration = @'
include custom::puppet_timer
'@
        Files = @('manifests/puppet_timer.pp', 'functions/source_candidates.pp', 'files/puppet_timer/ces-puppet-agent-run.service', 'files/puppet_timer/ces-puppet-agent-run.timer')
    },
    @{
        Name = 'DNS Resolver'
        FileName = 'Puppet_Resolver_RHEL8-10.pdf'
        Purpose = 'Manage a static resolver configuration and prevent NetworkManager from replacing it.'
        Behavior = 'Project settings explicitly override site/network defaults. Puppet configures NetworkManager for unmanaged resolver handling and renders /etc/resolv.conf with one or more nameservers and an optional search line.'
        Configuration = @'
include custom::resolver

custom::resolver::site_defaults:
  custom_ns:
    - 192.0.2.53
    - 192.0.2.54
  custom_search:
    - example.test
'@
        Files = @('manifests/resolver.pp', 'templates/resolv.conf.epp')
    },
    @{
        Name = 'RPM Installation'
        FileName = 'Puppet_RPM_Install_RHEL8-10.pdf'
        Purpose = 'Install and remove package names supplied through Hiera.'
        Behavior = 'The rpms and xrpms arrays use unique Hiera merges. Puppet rejects any package present in both lists, installs requested packages, and removes explicitly unwanted packages.'
        Configuration = @'
include custom::rpm_install

custom::rpm_install::rpms:
  - package-one
custom::rpm_install::xrpms:
  - unwanted-package
'@
        Files = @('manifests/rpm_install.pp', 'data/common.yaml')
    }
)

$css = @'
@page { size: Letter landscape; margin: 0.42in 0.52in 0.42in 0.52in; }
* { box-sizing: border-box; }
body { margin: 0; color: #17202a; font-family: Arial, Helvetica, sans-serif; font-size: 10pt; line-height: 1.35; }
h1 { margin: 0 0 0.08in; color: #7a1424; font-size: 27pt; font-weight: 650; }
h2 { margin: 0 0 0.12in; color: #7a1424; font-size: 17pt; }
h3 { margin: 0; font-size: 10pt; font-weight: 600; }
p { margin: 0 0 0.14in; }
.subtitle { color: #4d5966; font-size: 14pt; }
.cover { min-height: 6.55in; display: flex; flex-direction: column; }
.rule { width: 100%; height: 3px; margin: 0.14in 0 0.22in; background: #7a1424; }
.callout { margin: 0.12in 0 0.22in; padding: 0.16in 0.20in; border-left: 5px solid #7a1424; background: #f5f0f1; font-size: 11pt; }
.grid { display: grid; grid-template-columns: 1fr 1fr; gap: 0.28in; }
.panel { padding: 0.16in; border: 1px solid #d5d9dc; border-radius: 5px; }
.layout, .configuration { margin: 0; font: 8.2pt/1.35 Consolas, 'Courier New', monospace; white-space: pre-wrap; }
.compatibility { margin-top: auto; color: #56606a; font-size: 9pt; }
.source { break-before: page; page-break-before: always; }
.source-header { display: flex; justify-content: space-between; align-items: baseline; padding-bottom: 0.07in; border-bottom: 2px solid #7a1424; }
.path { color: #4d5966; font: 9pt Consolas, 'Courier New', monospace; }
.code { margin: 0.12in 0 0; font: 6.8pt/1.22 Consolas, 'Courier New', monospace; white-space: pre-wrap; overflow-wrap: anywhere; tab-size: 2; }
'@

if ($ModuleName) {
    foreach ($name in $ModuleName) {
        if ($name -notin $modules.Name) {
            throw "Unknown module name: $name. Available modules: $($modules.Name -join ', ')"
        }
    }
    $modules = @($modules | Where-Object { $_.Name -in $ModuleName })
}

foreach ($module in $modules) {
    $moduleCss = if ($module.Name -eq 'Branding') {
        '.code { line-height: 1.1; } .configuration { font-size: 7.4pt; }'
    } else { '' }
    $layout = ConvertTo-HtmlText (Get-ModuleLayout -Files $module.Files)
    $configuration = ConvertTo-HtmlText $module.Configuration.Trim()
    $sourceSections = foreach ($relativeFile in $module.Files) {
        $sourcePath = Join-Path (Join-Path $RepositoryRoot 'modules/custom') $relativeFile
        if (-not (Test-Path -LiteralPath $sourcePath)) {
            throw "Document source file not found: $sourcePath"
        }
        $code = ConvertTo-HtmlText (Get-Content -LiteralPath $sourcePath -Raw)
        $label = ConvertTo-HtmlText $relativeFile
        "<section class=`"source`"><div class=`"source-header`"><h3>$($module.Name)</h3><span class=`"path`">modules/custom/$label</span></div><pre class=`"code`">$code</pre></section>"
    }

    $title = ConvertTo-HtmlText "Puppet $($module.Name) Module"
    $purpose = ConvertTo-HtmlText $module.Purpose
    $behavior = ConvertTo-HtmlText $module.Behavior
    $html = @"
<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><title>$title - RHEL 8/9/10</title><style>$css`n$moduleCss</style></head>
<body>
<section class="cover">
  <h1>$title</h1>
  <div class="subtitle">RHEL 8 / 9 / 10 - custom OpenVox/Puppet module documentation</div>
  <div class="rule"></div>
  <div class="callout"><strong>Purpose:</strong> $purpose</div>
  <div class="grid">
    <div class="panel"><h2>Module layout</h2><pre class="layout">$layout</pre></div>
    <div class="panel"><h2>Configuration</h2><pre class="configuration">$configuration</pre></div>
  </div>
  <div class="callout"><strong>Behavior and safety:</strong> $behavior</div>
  <p><strong>Validation status:</strong> This module is part of a STIG hardening automation repository. STIG compliance has not been validated, and the code has not been rigorously tested. Review and test in an isolated environment before production use.</p>
  <div class="compatibility">Target platform: Red Hat Enterprise Linux 8, 9, and 10. Generated from the repository sources; rerun <strong>tools/generate_custom_module_docs.ps1</strong> after code changes.</div>
</section>
$($sourceSections -join "`n")
</body>
</html>
"@

    $htmlPath = Join-Path $scratchDirectory ($module.FileName -replace '\.pdf$', '.html')
    $pdfPath = Join-Path $docDirectory $module.FileName
    [System.IO.File]::WriteAllText($htmlPath, $html, [System.Text.UTF8Encoding]::new($false))
    $htmlUri = [System.Uri]::new($htmlPath).AbsoluteUri

    $arguments = @(
        '--headless=new',
        '--disable-gpu',
        '--no-pdf-header-footer',
        "--user-data-dir=$profileDirectory",
        "--print-to-pdf=$pdfPath",
        $htmlUri
    )
    $process = Start-Process -FilePath $chrome -ArgumentList $arguments -Wait -PassThru -WindowStyle Hidden
    if ($process.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $pdfPath)) {
        throw "Failed to generate $pdfPath (browser exit code $($process.ExitCode))."
    }
    Write-Output "Generated $pdfPath"
}

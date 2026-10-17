param(
  [string]$XccdfPath = (Join-Path $PSScriptRoot '..\ansible\U_RHEL_10_V1R2_STIG\U_RHEL_10_V1R2_Manual_STIG\U_RHEL_10_STIG_V1R2_Manual-xccdf.xml'),
  [Parameter(Mandatory)]
  [string]$OutputRoot
)

$ErrorActionPreference = 'Stop'
$utf8NoBom = [Text.UTF8Encoding]::new($false)
$xccdfNamespace = 'http://checklists.nist.gov/xccdf/1.1'

[xml]$xccdf = Get-Content -Raw -LiteralPath (Resolve-Path $XccdfPath)
$namespace = [Xml.XmlNamespaceManager]::new($xccdf.NameTable)
$namespace.AddNamespace('x', $xccdfNamespace)
$release = $xccdf.SelectSingleNode('/x:Benchmark/x:plain-text[@id="release-info"]', $namespace).InnerText
if ($release -notmatch 'Release:\s*2\b' -or $release -notmatch '01 Jul 2026') {
  throw "Expected the RHEL 10 V1R2 benchmark dated 01 Jul 2026; found: $release"
}

$groups = @{}
foreach ($group in $xccdf.SelectNodes('/x:Benchmark/x:Group', $namespace)) {
  $groups[$group.id] = $group
}

$resolvedOutput = [IO.Path]::GetFullPath($OutputRoot)
if (Test-Path -LiteralPath $resolvedOutput) {
  throw "OutputRoot already exists: $resolvedOutput"
}

$report = [Collections.Generic.List[object]]::new()
function Add-Overlay([string]$Relative, [string[]]$ControlIds, [string[]]$Lines) {
  foreach ($controlId in $ControlIds) {
    if (-not $groups.ContainsKey($controlId)) { throw "Unknown RHEL 10 V1R2 control: $controlId" }
  }
  $path = Join-Path $resolvedOutput "10\files\$($Relative.Replace('/', '\'))"
  New-Item -ItemType Directory -Force (Split-Path -Parent $path) | Out-Null
  $content = (($Lines | ForEach-Object { $_.TrimEnd() }) -join "`n").TrimEnd() + "`n"
  [IO.File]::WriteAllText($path, $content, $utf8NoBom)
  $report.Add([pscustomobject]@{
    source = $Relative
    destination = if ($Relative.StartsWith('etc/') -or $Relative.StartsWith('usr/')) { "/$Relative" } else { "/etc/$Relative" }
    controls = $ControlIds
  })
}

$repo = Resolve-Path (Join-Path $PSScriptRoot '..')
$bannerIssue = [IO.File]::ReadAllLines((Join-Path $repo 'modules\stigs\files\etc\issue'))
$bannerFixtext = $groups['V-281225'].SelectSingleNode('x:Rule/x:fixtext', $namespace).InnerText
$bannerMatch = [regex]::Match($bannerFixtext, '(?m)^banner-message-text=(.+)$')
if (-not $bannerMatch.Success) { throw 'Could not extract the V-281225 dconf banner text' }
$bannerDconf = @('[org/gnome/login-screen]', "banner-message-text=$($bannerMatch.Groups[1].Value.Trim())", 'banner-message-enable=true')

Add-Overlay 'audit/auditd.conf' @(
  'V-281098','V-281099','V-281104','V-281105','V-281107','V-281108','V-281109',
  'V-281110','V-281111','V-281113','V-281114'
) @(
  'local_events = yes',
  'write_logs = yes',
  'space_left = 25%',
  'name_format = hostname',
  'admin_space_left = 5%',
  'admin_space_left_action = single',
  'overflow_action = syslog',
  'log_format = ENRICHED',
  'freq = 100',
  'space_left_action = email',
  'action_mail_acct = root'
)

$auditRuleIds = @(
  'V-281103','V-281116','V-281117','V-281118','V-281119','V-281120','V-281121',
  'V-281122','V-281123','V-281124','V-281125','V-281126','V-281127','V-281128',
  'V-281129','V-281130','V-281131','V-281132','V-281133','V-281134','V-281135',
  'V-281136','V-281137','V-281138','V-281139','V-281140','V-281141','V-281142',
  'V-281143','V-281144','V-281145','V-281146','V-281147','V-281148','V-281149',
  'V-281150','V-281151','V-281152','V-281153','V-281154','V-281155','V-281156',
  'V-281157','V-281158','V-281159','V-281160','V-281161','V-281162','V-281163',
  'V-281164','V-281165','V-281365'
)
$auditRules = [Collections.Generic.List[string]]::new()
foreach ($controlId in $auditRuleIds) {
  if (-not $groups.ContainsKey($controlId)) { throw "Unknown audit control: $controlId" }
  $fixtext = $groups[$controlId].SelectSingleNode('x:Rule/x:fixtext', $namespace).InnerText
  foreach ($line in ($fixtext -split "`r?`n")) {
    $candidate = $line.Trim()
    if ($candidate -notmatch '^-(?:a|w|f|e)\s+') { continue }
    # V-281158 contains an obvious unmatched parenthesis before the opasswd
    # path. The check text and the companion b32 rule show the intended path.
    $candidate = $candidate.Replace('path=(/etc/security/opasswd', 'path=/etc/security/opasswd')
    if (-not $auditRules.Contains($candidate)) { $auditRules.Add($candidate) }
  }
}
Add-Overlay 'audit/rules.d/audit.rules' $auditRuleIds $auditRules.ToArray()

Add-Overlay 'dnf/dnf.conf' @('V-280932','V-280933','V-280942') @(
  '[main]', 'gpgcheck=1', 'localpkg_gpgcheck=1', 'clean_requirements_on_remove=True'
)
Add-Overlay 'etc/aliases' @('V-281270') @('postmaster: root')
Add-Overlay 'etc/bashrc' @('V-281080') @('umask 077')
Add-Overlay 'etc/chrony.conf' @('V-280960','V-280961','V-281336') @('port 0','cmdport 0')
Add-Overlay 'etc/csh.cshrc' @('V-281081') @('umask 077')
Add-Overlay 'etc/issue' @('V-281224','V-281227') $bannerIssue
Add-Overlay 'etc/libuser.conf' @('V-281223') @('[defaults]','crypt_style = sha512')
Add-Overlay 'etc/login.defs' @('V-281082','V-281169','V-281171','V-281179','V-281180','V-281222') @(
  'UMASK 077','PASS_MAX_DAYS 60','CREATE_HOME yes','FAIL_DELAY 4','PASS_MIN_DAYS 1','ENCRYPT_METHOD SHA512'
)
Add-Overlay 'etc/profile' @('V-281083') @('umask 077')
Add-Overlay 'etc/rsyslog.conf' @('V-280985','V-280986','V-280990','V-280991') @(
  'auth.*;authpriv.*;daemon.* /var/log/secure',
  'cron.* /var/log/cron'
)
Add-Overlay 'etc/sudoers' @('V-281208','V-281209','V-281210','V-281211') @(
  'Defaults timestamp_timeout=0','Defaults !targetpw','Defaults !rootpw','Defaults !runaspw'
)

Add-Overlay 'dconf/db/local.d/00-screensaver' @('V-281278','V-281280') @(
  '[org/gnome/desktop/screensaver]','lock-enabled=true','lock-delay=uint32 5','',
  '[org/gnome/desktop/session]','idle-delay=uint32 600'
)
Add-Overlay 'dconf/db/local.d/00-security-settings' @('V-281282','V-281291','V-281292') @(
  '[org/gnome/desktop/screensaver]',"picture-uri=''",'',
  '[org/gnome/desktop/media-handling]','automount-open=false','autorun-never=true'
)
Add-Overlay 'dconf/db/local.d/00-media-keys' @('V-281286') @(
  '[org/gnome/settings-daemon/plugins/media-keys]','logout=@as []'
)
Add-Overlay 'dconf/db/local.d/01-banner-message' @('V-281225') $bannerDconf
Add-Overlay 'dconf/db/local.d/02-login-screen' @('V-281287') @(
  '[org/gnome/login-screen]','disable-user-list=true'
)
Add-Overlay 'dconf/db/local.d/locks/00-security-settings-lock' @('V-281273','V-281274','V-281276','V-281282') @(
  '/org/gnome/desktop/media-handling/automount-open',
  '/org/gnome/desktop/media-handling/autorun-never',
  '/org/gnome/settings-daemon/peripherals/smartcard/removal-action',
  '/org/gnome/desktop/screensaver/picture-uri'
)
Add-Overlay 'dconf/db/local.d/locks/session' @('V-281226','V-281277','V-281279','V-281281','V-281284','V-281285') @(
  '/org/gnome/login-screen/banner-message-enable',
  '/org/gnome/desktop/screensaver/lock-enabled',
  '/org/gnome/desktop/session/idle-delay',
  '/org/gnome/desktop/screensaver/lock-delay',
  '/org/gnome/login-screen/disable-restart-buttons',
  '/org/gnome/settings-daemon/plugins/media-keys/logout'
)

Add-Overlay 'firewalld/firewalld.conf' @('V-281361') @('FirewallBackend=nftables')
Add-Overlay 'gdm/custom.conf' @('V-281275') @('[daemon]','AutomaticLoginEnable=false')
Add-Overlay 'NetworkManager/NetworkManager.conf' @('V-281362') @('[main]','dns=none')
foreach ($module in @('bluetooth','can','sctp','tipc','usb-storage')) {
  $controlId = @{
    bluetooth='V-281289'; can='V-281312'; sctp='V-281313'; tipc='V-281314'; 'usb-storage'='V-281288'
  }[$module]
  Add-Overlay "modprobe.d/$module.conf" @($controlId) @("install $module /bin/false", "blacklist $module")
}
Add-Overlay 'profile.d/tmout.sh' @('V-281295') @('#!/bin/bash','','declare -xr TMOUT=600')

Add-Overlay 'security/faillock.conf' @('V-281100','V-281194','V-281195','V-281196','V-281197','V-281198') @(
  'audit','deny = 3','even_deny_root','fail_interval = 900','unlock_time = 0','dir = /var/log/faillock'
)
Add-Overlay 'security/limits.conf' @('V-281203','V-281319') @('* hard maxlogins 10','* hard core 0')
Add-Overlay 'security/pwquality.conf' @(
  'V-281181','V-281182','V-281183','V-281184','V-281185','V-281187','V-281188',
  'V-281189','V-281190','V-281191','V-281193','V-281204'
) @(
  'minlen = 15','ocredit = -1','lcredit = -1','ucredit = -1','difok = 8',
  'maxclassrepeat = 4','maxrepeat = 3','minclass = 4','dcredit = -1','dictcheck = 1',
  'enforce_for_root','retry = 3'
)
Add-Overlay 'selinux/config' @('V-281249','V-281251') @('SELINUXTYPE=targeted','SELINUX=enforcing')

Add-Overlay 'ssh/sshd_config' @(
  'V-281115','V-281216','V-281224','V-281254','V-281255','V-281256','V-281257',
  'V-281258','V-281259','V-281260','V-281261','V-281263','V-281264','V-281265',
  'V-281266','V-281267','V-281268','V-281269','V-281296'
) @(
  'LogLevel VERBOSE','UsePAM yes','Banner /etc/issue','GSSAPIAuthentication no',
  'KerberosAuthentication no','IgnoreRhosts yes','IgnoreUserKnownHosts yes','X11Forwarding no',
  'StrictModes yes','PrintLastLog yes','X11UseLocalhost yes','PubkeyAuthentication yes',
  'PermitEmptyPasswords no','PermitRootLogin no','HostbasedAuthentication no',
  'PermitUserEnvironment no','RekeyLimit 1G 1h','ClientAliveCountMax 1','ClientAliveInterval 600'
)
Add-Overlay 'sssd/conf.d/certificate_verification.conf' @('V-281325') @(
  '[sssd]','certificate_verification = ocsp_dgst=sha512'
)
Add-Overlay 'sssd/sssd.conf' @('V-281324','V-281331') @(
  '[pam]','pam_cert_auth=True','offline_credentials_expiration=1'
)

$sysctl = [ordered]@{
  '99-dmesg_restrict.conf'                    = @('V-281305','kernel.dmesg_restrict = 1')
  '99-kernel_perf_event_paranoid.conf'        = @('V-281306','kernel.perf_event_paranoid = 2')
  '99-kernel_kexec_load_disabled.conf'        = @('V-281307','kernel.kexec_load_disabled = 1')
  '99-kernel_kptr_restrict.conf'               = @('V-281308','kernel.kptr_restrict = 1')
  '99-fs_protected_hardlinks.conf'             = @('V-281309','fs.protected_hardlinks = 1')
  '99-fs_protected_symlinks.conf'              = @('V-281310','fs.protected_symlinks = 1')
  '99-kernel_core_pattern.conf'                = @('V-281311','kernel.core_pattern = |/bin/false')
  '99-kernel_randomize_va_space.conf'          = @('V-281315','kernel.randomize_va_space = 2')
  '99-kernel_yama.ptrace_scope.conf'           = @('V-281316','kernel.yama.ptrace_scope = 1')
  '99-kernel_unprivileged_bpf_disabled.conf'   = @('V-281335','kernel.unprivileged_bpf_disabled = 1')
  '99-net_core-bpf_jit_harden.conf'            = @('V-281337','net.core.bpf_jit_harden = 2')
  '99-ipv4_tcp_syncookies.conf'                = @('V-281340','net.ipv4.tcp_syncookies = 1')
  '99-ipv4_accept_redirects.conf'              = @('V-281341','net.ipv4.conf.all.accept_redirects = 0','V-281346','net.ipv4.conf.default.accept_redirects = 0')
  '99-ipv4_accept_source.conf'                 = @('V-281342','net.ipv4.conf.all.accept_source_route = 0')
  '99-ipv4_log_martians.conf'                  = @('V-281343','net.ipv4.conf.all.log_martians = 1','V-281344','net.ipv4.conf.default.log_martians = 1')
  '99-ipv4_rp_filter.conf'                     = @('V-281345','net.ipv4.conf.all.rp_filter = 1')
  '99-ipv4_accept_source_route.conf'           = @('V-281347','net.ipv4.conf.default.accept_source_route = 0')
  'ipv4_rp_filter.conf'                        = @('V-281348','net.ipv4.conf.default.rp_filter = 1')
  'ipv4_icmp_echo_ignore_broadcasts.conf'      = @('V-281349','net.ipv4.icmp_echo_ignore_broadcasts = 1')
  'ipv4_icmp_ignore_bogus_error_responses.conf'= @('V-281350','net.ipv4.icmp_ignore_bogus_error_responses = 1')
  'ipv4_send_redirects.conf'                   = @('V-281351','net.ipv4.conf.all.send_redirects = 0','V-281352','net.ipv4.conf.default.send_redirects = 0')
  'ipv4_forwarding.conf'                       = @('V-281353','net.ipv4.conf.all.forwarding = 0')
  'ipv4_accept_ra.conf'                        = @('V-281354','net.ipv6.conf.all.accept_ra = 0')
  'ipv6_accept_redirects.conf'                 = @('V-281355','net.ipv6.conf.all.accept_redirects = 0','V-281359','net.ipv6.conf.default.accept_redirects = 0')
  'ipv6_accept_source_route.conf'              = @('V-281356','net.ipv6.conf.all.accept_source_route = 0','V-281360','net.ipv6.conf.default.accept_source_route = 0')
  'ipv6_forwarding.conf'                       = @('V-281357','net.ipv6.conf.all.forwarding = 0')
  'ipv6_accept_ra.conf'                        = @('V-281358','net.ipv6.conf.default.accept_ra = 0')
}
foreach ($entry in $sysctl.GetEnumerator()) {
  $ids = [Collections.Generic.List[string]]::new()
  $lines = [Collections.Generic.List[string]]::new()
  for ($i = 0; $i -lt $entry.Value.Count; $i += 2) {
    $ids.Add($entry.Value[$i]); $lines.Add($entry.Value[$i + 1])
  }
  Add-Overlay "sysctl.d/$($entry.Key)" $ids.ToArray() $lines.ToArray()
}

Add-Overlay 'systemd/coredump.conf' @('V-281317','V-281318') @(
  '[Coredump]','ProcessSizeMax=0','Storage=none'
)
Add-Overlay 'systemd/system.conf.d/55-CtrlAltDel-BurstAction.conf' @('V-281298') @(
  '[Manager]','CtrlAltDelBurstAction=none'
)
Add-Overlay 'usr/lib/systemd/system/emergency.service' @('V-281327') @(
  '[Service]','ExecStart=-/usr/lib/systemd/systemd-sulogin-shell emergency'
)
Add-Overlay 'usr/lib/systemd/system/rescue.service' @('V-281328') @(
  '[Service]','ExecStart=-/usr/lib/systemd/systemd-sulogin-shell rescue'
)
Add-Overlay 'usbguard/usbguard-daemon.conf' @('V-280965') @('AuditBackend=LinuxAudit')

New-Item -ItemType Directory -Force $resolvedOutput | Out-Null
[IO.File]::WriteAllText(
  (Join-Path $resolvedOutput 'rhel10-v1r2-file-controls.json'),
  (($report | ConvertTo-Json -Depth 5) + "`n"),
  $utf8NoBom
)
Write-Host "Generated $($report.Count) RHEL 10 V1R2 file overlays from $($auditRuleIds.Count + 1) audited rule groups and explicit static controls."

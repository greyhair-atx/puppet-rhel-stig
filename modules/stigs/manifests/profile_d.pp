# DISA STIG vulnerability IDs implemented by this class:
# RHEL 8:
#   V-279929
# RHEL 9: none directly
# RHEL 10:
#   V-281295
class stigs::profile_d {
  file { 'stig directory /etc/profile.d':
    ensure => directory,
    path   => '/etc/profile.d',
  }
  if $facts['os']['release']['major'] =~ /^(8|10)$/ {
      file { 'stig /etc/profile.d/tmout.sh':
        ensure       => file,
        path         => '/etc/profile.d/tmout.sh',
        owner        => 'root',
        group        => 'root',
        mode         => '0644',
        source       => stigs::source_candidates('puppet:///modules/stigs/profile.d/tmout.sh'),
        sourceselect => 'first',
      }
  }
}

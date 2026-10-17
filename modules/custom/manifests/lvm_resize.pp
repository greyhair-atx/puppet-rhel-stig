# @summary
#   Grows configured LVM-backed filesystems to their desired sizes.
#
# @param partitions
#   Mount points and target sizes. Sizes are whole gibibytes such as 24G.
class custom::lvm_resize (
  Array[Struct[{
    'mount' => Pattern[/^\/[A-Za-z0-9._\/-]*$/],
    'size'  => Pattern[/^[1-9][0-9]*[Gg]$/],
  }], 1] $partitions = [
    {
      'mount' => '/',
      'size'  => '24G',
    },
    {
      'mount' => '/var',
      'size'  => '24G',
    },
  ],
) {
  if $facts['os']['family'] != 'RedHat' {
    fail('custom::lvm_resize supports only Red Hat family operating systems')
  }

  case $facts['os']['release']['major'] {
    '8', '9', '10': { }
    default: {
      fail('custom::lvm_resize supports RHEL major versions 8, 9, and 10 only')
    }
  }

  $partitions.each |Struct $partition| {
    $mount = $partition['mount']
    if !($mount in $facts['mountpoints']) {
      fail("custom::lvm_resize cannot find mount point '${mount}' in the mountpoints fact")
    }
  }

  file { 'custom LVM resize check script':
    ensure       => file,
    path         => '/usr/local/sbin/check_lvm_resize.sh',
    owner        => 'root',
    group        => 'root',
    mode         => '0750',
    source       => custom::source_candidates('puppet:///modules/custom/lvm_resize/check_lvm_resize.sh'),
    sourceselect => 'first',
  }

  file { 'custom LVM resize script':
    ensure       => file,
    path         => '/usr/local/sbin/resize_lvm.sh',
    owner        => 'root',
    group        => 'root',
    mode         => '0750',
    source       => custom::source_candidates('puppet:///modules/custom/lvm_resize/resize_lvm.sh'),
    sourceselect => 'first',
  }

  $partitions_needing_resize = $partitions.filter |Struct $partition| {
    $mount = $partition['mount']
    $target_gib = Integer(regsubst($partition['size'], '[Gg]$', ''))
    $target_bytes = $target_gib * 1024 * 1024 * 1024
    $facts['mountpoints'][$mount]['size_bytes'] < $target_bytes
  }

  $partition_arguments = $partitions.map |Struct $partition| {
    "${partition['mount']} ${partition['size']}"
  }.join(' ')

  if !empty($partitions_needing_resize) {
    exec { 'resize custom LVM partitions':
      command   => "/usr/local/sbin/resize_lvm.sh ${partition_arguments}",
      onlyif    => "/usr/local/sbin/check_lvm_resize.sh ${partition_arguments}",
      path      => ['/usr/bin', '/usr/sbin', '/bin', '/sbin'],
      timeout   => 0,
      logoutput => true,
      require   => [
        File['custom LVM resize check script'],
        File['custom LVM resize script'],
      ],
    }
  }
}

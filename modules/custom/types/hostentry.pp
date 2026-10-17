# @summary
#   A managed /etc/hosts entry with an optional alias.
type Custom::HostEntry = Struct[{
  'ip'              => Pattern[/\A[^\s#]+\z/],
  'fqdn'            => Pattern[/\A[^\s#]+\z/],
  'hostname'        => Pattern[/\A[^\s#]+\z/],
  Optional['alias'] => Pattern[/\A[^\s#]+\z/],
}]

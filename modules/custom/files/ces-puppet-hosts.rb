#!/opt/puppetlabs/puppet/bin/ruby
# frozen_string_literal: true

BANNER = [
  '# Managed by CES Puppet.',
  '# Manual changes will be replaced.'
].freeze

def read_records(path)
  records = File.readlines(path, chomp: true).reject(&:empty?).map do |line|
    fields = line.split("\t", -1)
    valid_fields = fields.length == 4 && fields.take(3).all? { |field| !field.empty? }
    abort("Invalid record in #{path}: expected IP, FQDN, hostname, and optional alias") unless valid_fields

    fields.reject(&:empty?)
  end

  abort("Invalid record file #{path}: expected at least two records") unless records.length >= 2

  hostnames = records.map { |record| record[2].downcase }
  unless hostnames.uniq.length == hostnames.length
    abort("Invalid record file #{path}: managed hostnames must be unique")
  end

  records
end

def managed_content(current, records)
  managed_hostnames = records.map { |record| record[2].downcase }
  lines = current.lines(chomp: true)

  # Remove a previous copy of the managed banner wherever it occurs.
  lines.reject! { |line| BANNER.include?(line) }

  # Replace a hosts entry when one of its names matches a managed hostname.
  # Comments, blank lines, and every unrelated hosts entry remain untouched.
  lines.reject! do |line|
    entry = line.sub(/\s+#.*\z/, '').strip
    next false if entry.empty? || entry.start_with?('#')

    old_names = entry.split(/\s+/).drop(1).map(&:downcase)
    (old_names & managed_hostnames).any?
  end

  body = lines.join("\n")
  body += "\n" unless body.empty? || body.end_with?("\n")

  managed = records.map { |record| record.join("\t") }
  (BANNER + managed).join("\n") + "\n" + body
end

unless ARGV.length == 3 && %w[--check --apply].include?(ARGV[0])
  abort("Usage: #{File.basename($PROGRAM_NAME)} (--check|--apply) HOSTS_FILE RECORDS_FILE")
end

mode, hosts_path, records_path = ARGV
records = read_records(records_path)

if mode == '--check'
  File.open(hosts_path, 'rb') do |file|
    file.flock(File::LOCK_SH)
    current = file.read
    exit(current == managed_content(current, records) ? 0 : 1)
  end
else
  # Lock and write through the existing inode so concurrent changes cannot
  # race this update and ownership, mode, ACLs, and SELinux context are kept.
  File.open(hosts_path, 'r+b') do |file|
    file.flock(File::LOCK_EX)
    current = file.read
    desired = managed_content(current, records)
    next if current == desired

    file.rewind
    file.write(desired)
    file.truncate(file.pos)
    file.flush
    file.fsync
  end
end

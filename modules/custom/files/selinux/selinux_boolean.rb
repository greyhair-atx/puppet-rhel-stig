#!/opt/puppetlabs/puppet/bin/ruby
# frozen_string_literal: true

require 'open3'

# semanage reports (active, saved) values. Checking getsebool alone would miss
# a matching active value that will revert after reboot.
class CesSelinuxBoolean
  def initialize(runner = nil)
    @runner = runner || lambda do |*argv|
      stdout, stderr, status = Open3.capture3({ 'LC_ALL' => 'C' }, *argv)
      raise "#{argv.first} failed: #{stderr.strip}" unless status.success?

      stdout
    end
  end

  def validate(name, value)
    raise 'Invalid SELinux boolean name' unless name.is_a?(String) && name.match?(/\A[a-zA-Z][a-zA-Z0-9_]*\z/)
    raise "SELinux boolean value must be 'on' or 'off'" unless %w[on off].include?(value)
  end

  def matches?(name, value)
    validate(name, value)
    @runner.call('/usr/sbin/selinuxenabled')
    output = @runner.call('/usr/sbin/semanage', 'boolean', '--list', '--noheading')
    pattern = /\A#{Regexp.escape(name)}\s+\(\s*(on|off)\s*,\s*(on|off)\s*\)/
    match = output.each_line.filter_map { |line| pattern.match(line) }.first
    raise "SELinux boolean #{name} was not found in the installed policy" unless match

    match[1] == value && match[2] == value
  end

  def apply(name, value)
    return if matches?(name, value)

    @runner.call('/usr/sbin/setsebool', '-P', name, value)
    raise "SELinux boolean #{name} did not converge" unless matches?(name, value)
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    mode, name, value = ARGV
    unless ARGV.length == 3 && %w[--check --apply].include?(mode)
      raise 'Usage: ces-selinux-boolean --check|--apply BOOLEAN on|off'
    end

    manager = CesSelinuxBoolean.new
    if mode == '--check'
      exit(manager.matches?(name, value) ? 0 : 1)
    end
    manager.apply(name, value)
  rescue StandardError => e
    warn "SELinux boolean: #{e.message}"
    exit 2
  end
end

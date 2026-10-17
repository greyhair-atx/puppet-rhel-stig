require 'puppet'
require 'tmpdir'
require 'fileutils'
require 'yaml'
require_relative '../modules/custom/files/selinux/selinux_boolean'
root = File.expand_path('..', __dir__).tr('\\', '/')

def assert(condition, message)
  raise message unless condition
end

# Exercise drift in both active and persisted values without modifying this host.
%w[on off].each do |wanted|
  %w[on off].product(%w[on off]).each do |active, saved|
    state = [active, saved]
    calls = []
    runner = lambda do |*argv|
      calls << argv
      case argv.first
      when '/usr/sbin/selinuxenabled' then ''
      when '/usr/sbin/semanage' then "example_boolean    (#{state[0]}   ,   #{state[1]}) A description\n"
      when '/usr/sbin/setsebool'
        assert(argv == ['/usr/sbin/setsebool', '-P', 'example_boolean', wanted], 'Incorrect persistent command')
        state = [wanted, wanted]
        ''
      else raise "Unexpected command #{argv}"
      end
    end
    manager = CesSelinuxBoolean.new(runner)
    expected = active == wanted && saved == wanted
    assert(manager.matches?('example_boolean', wanted) == expected, 'Incorrect state check')
    manager.apply('example_boolean', wanted)
    assert(calls.count { |a| a.first.end_with?('/setsebool') } == (expected ? 0 : 1), 'Incorrect change count')
    manager.apply('example_boolean', wanted)
    assert(calls.count { |a| a.first.end_with?('/setsebool') } == (expected ? 0 : 1), 'Not idempotent')
    puts "PASS helper #{active}/#{saved} -> #{wanted}"
  end
end
{
  'missing boolean' => ->(*_args) { '' },
  'disabled SELinux' => ->(*_args) { raise 'SELinux disabled' },
  'read failure' => ->(*args) { raise 'read failure' if args.first.end_with?('/semanage'); '' },
  'write failure' => ->(*args) { raise 'write failure' if args.first.end_with?('/setsebool'); "example_boolean (off, off)\n" },
  'failure to converge' => ->(*_args) { "example_boolean (off, off)\n" },
}.each do |name, runner|
  failed = false
  begin
    CesSelinuxBoolean.new(runner).apply('example_boolean', 'on')
  rescue StandardError
    failed = true
  end
  assert(failed, "Did not reject #{name}")
  puts "PASS helper #{name}"
end

Dir.mktmpdir('selinux-booleans-') do |scratch|
  Puppet.initialize_settings(['--confdir', scratch, '--vardir', "#{scratch}/var", '--logdir', "#{scratch}/log"])
  mapping = {'8'=>{'example_boolean'=>'on','other_boolean'=>'off'}, '9'=>{'example_boolean'=>'off','new_boolean'=>'on'}, '10'=>{'rhel10_boolean'=>'on'}}
  cases = [
    ['rhel8', '8', mapping, nil], ['rhel9', '9', mapping, nil], ['rhel10', '10', mapping, nil],
    ['missing_os', '9', {'8'=>mapping['8']}, nil], ['empty', '8', {}, nil],
    ['invalid_value', '8', {'8'=>{'example_boolean'=>'yes'}}, 'set_booleans'],
    ['unquoted_value', '8', {'8'=>{'example_boolean'=>true}}, 'set_booleans'],
    ['invalid_name', '8', {'8'=>{'bad;name'=>'on'}}, 'set_booleans'],
    ['unsupported_os', '7', mapping, 'supports only'],
    ['invalid_os_key', '8', {'7'=>{'example_boolean'=>'on'}}, 'set_booleans'],
    ['merge', '8', mapping, nil], ['package_reuse', '8', mapping, nil],
    ['package_conflict', '8', mapping, 'cannot be in'],
  ]
  cases.each do |name, version, values, error|
    dir = "#{scratch}/#{name}"
    FileUtils.mkdir_p("#{dir}/data/node")
    FileUtils.cp("#{root}/hiera.yaml", "#{dir}/hiera.yaml")
    manifest = "#{dir}/site.pp"
    File.write(manifest, 'include custom::selinux_boolean')
    common = {'custom::selinux_boolean::set_booleans'=>values}
    packages = %w[libselinux-utils policycoreutils policycoreutils-python-utils]
    common['custom::rpm_install::rpms'] = packages if name == 'package_reuse'
    common['custom::rpm_install::xrpms'] = ['policycoreutils'] if name == 'package_conflict'
    File.write("#{dir}/data/common.yaml", common.to_yaml)
    if name == 'merge'
      File.write("#{dir}/data/node/node.example.test.yaml", {'custom::selinux_boolean::set_booleans'=>{'8'=>{'example_boolean'=>'off','node_boolean'=>'on'}}}.to_yaml)
    end
    environment = Puppet::Node::Environment.create(name.to_sym, ["#{root}/modules"], manifest)
    loader = Puppet::Environments::StaticDirectory.new(name, dir, environment)
    Puppet.override(environments: loader) do
      facts = Puppet::Node::Facts.new('node.example.test', {'os'=>{'family'=>'RedHat','release'=>{'major'=>version}}})
      node = Puppet::Node.new('node.example.test', facts: facts, environment: environment)
      node.trusted_data = {'authenticated'=>'remote','certname'=>'node.example.test','extensions'=>{}}
      begin
        catalog = Puppet::Parser::Compiler.compile(node)
        raise 'Expected compilation failure' if error
        expected = (values[version] || {}).dup
        expected.merge!({'example_boolean'=>'off','node_boolean'=>'on'}) if name == 'merge'
        resources = catalog.resources.select { |r| r.type == 'Exec' }
        assert(resources.size == expected.size, "#{name}: wrong boolean count")
        expected.each do |key, value|
          resource = catalog.resource('Exec', "custom SELinux boolean #{key}")
          assert(resource[:command].end_with?("--apply #{key} #{value}"), 'Wrong apply command')
          assert(resource[:unless].end_with?("--check #{key} #{value}"), 'Wrong check command')
          requirements = Array(resource[:require]).flatten.map(&:to_s)
          packages.each { |pkg| assert(requirements.include?("Package[#{pkg}]"), "Missing dependency #{pkg}") }
        end
        actual_packages = catalog.resources.select { |r| r.type == 'Package' }.map(&:title).sort
        assert(actual_packages == (expected.empty? ? [] : packages.sort), 'Wrong package declarations')
      rescue StandardError => e
        raise unless error && e.message.include?(error)
      end
    end
    puts "PASS catalog #{name}"
  end
end

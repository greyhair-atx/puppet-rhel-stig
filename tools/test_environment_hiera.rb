require 'puppet'
require 'tmpdir'
require 'fileutils'
require 'yaml'
root = File.expand_path('..', __dir__).tr('\\', '/')
Dir.mktmpdir('environment-hiera-') do |scratch|
  Puppet.initialize_settings(['--confdir', scratch, '--vardir', "#{scratch}/var", '--logdir', "#{scratch}/log"])
  cases = {
    'combined' => {node: true, project: true, expected_classes: %w[custom::rpm_install custom::logrotate stigs::selinux], packages: %w[base-package project-package node-package], scalar: 'node'},
    'project_only' => {project: true, expected_classes: %w[custom::rpm_install stigs::selinux], packages: %w[base-package project-package], scalar: 'project'},
    'common_only' => {expected_classes: %w[custom::rpm_install], packages: %w[base-package], scalar: 'common'},
    'network_project' => {project: true, network_project: true, expected_classes: %w[custom::rpm_install stigs::selinux], packages: %w[base-package project-package network-package], scalar: 'network-project'},
    'other_network' => {project: true, network_project: true, network: 'B2', expected_classes: %w[custom::rpm_install stigs::selinux], packages: %w[base-package project-package], scalar: 'project'},
    'common_stig' => {common_stig: true, expected_classes: %w[custom::rpm_install stigs::selinux], packages: %w[base-package], scalar: 'common'},
    'region_zone_role' => {geography: true, expected_classes: %w[custom::rpm_install], packages: %w[base-package], scalar: 'role'},
    'no_classes' => {empty: true, expected_classes: [], packages: []},
    'missing_classes_key' => {empty: true, no_key: true, expected_classes: [], packages: []},
  }
  cases.each do |name, config|
    dir = "#{scratch}/#{name}"
    FileUtils.mkdir_p(dir)
    %w[hiera.yaml environment.conf manifests data].each do |entry|
      FileUtils.cp_r("#{root}/#{entry}", dir)
    end
    %w[node project role region zone network].each { |folder| FileUtils.mkdir_p("#{dir}/data/#{folder}") }
    write = ->(path, data) { File.write("#{dir}/data/#{path}", data.to_yaml) }
    write.call('common.yaml', {}) if config[:no_key]
    unless config[:empty]
      classes = ['custom::rpm_install']
      classes << 'stigs::selinux' if config[:common_stig]
      write.call('common.yaml', {'classes'=>classes, 'custom::rpm_install::rpms'=>['base-package'], 'test_scalar'=>'common', 'lookup_options'=>{'test_hash'=>{'merge'=>'deep'}}, 'test_hash'=>{'common'=>true,'winner'=>'common'}})
      write.call('project/alpha.yaml', {'classes'=>['stigs::selinux','custom::rpm_install'], 'custom::rpm_install::rpms'=>['project-package'], 'test_scalar'=>'project', 'test_hash'=>{'project'=>true,'winner'=>'project'}}) if config[:project]
      write.call('project/A1.alpha.yaml', {'custom::rpm_install::rpms'=>['network-package'], 'test_scalar'=>'network-project'}) if config[:network_project]
      write.call('node/pc01.example.test.yaml', {'classes'=>['custom::logrotate'], 'custom::rpm_install::rpms'=>['node-package'], 'test_scalar'=>'node', 'test_hash'=>{'node'=>true,'winner'=>'node'}}) if config[:node]
      if config[:geography]
        %w[network zone region role].each { |level| write.call("#{level}/#{ {'network'=>'A1','zone'=>'east','region'=>'us','role'=>'workstation'}[level] }.yaml", {'test_scalar'=>level}) }
      end
      File.open("#{dir}/manifests/site.pp", 'a') { |f| f.puts "\nnotify { 'scalar': message => lookup('test_scalar') }\n$merged = lookup('test_hash')\nnotify { 'hash': message => $merged['winner'] }\n$merged.each |$key, $value| { notify { \"merged ${key}\": message => String($value) } }" }
    end
    environment = Puppet::Node::Environment.create(name.to_sym, ["#{root}/modules"], "#{dir}/manifests/site.pp")
    loader = Puppet::Environments::StaticDirectory.new(name, dir, environment)
    Puppet.override(environments: loader) do
      facts = Puppet::Node::Facts.new('pc01.example.test', {'os'=>{'family'=>'RedHat','release'=>{'major'=>'9'}}})
      node = Puppet::Node.new('pc01.example.test', facts: facts, environment: environment)
      node.trusted_data = {'authenticated'=>'remote','certname'=>'pc01.example.test','extensions'=>{'pp_network'=>config.fetch(:network,'A1'),'pp_project'=>'alpha','pp_role'=>'workstation','pp_region'=>'us','pp_zone'=>'east'}}
      catalog = Puppet::Parser::Compiler.compile(node)
      %w[custom::rpm_install custom::logrotate stigs::selinux].each do |klass|
        present = catalog.classes.map(&:downcase).include?(klass)
        raise "#{name}: wrong class #{klass}" unless present == config[:expected_classes].include?(klass)
      end
      packages = catalog.resources.select { |r| r.type == 'Package' }.map(&:title).sort
      raise "#{name}: wrong packages #{packages}" unless packages == config[:packages].sort
      unless config[:empty]
        raise "#{name}: wrong scalar" unless catalog.resource('Notify', 'scalar')[:message] == config[:scalar]
        expected_winner = config[:node] ? 'node' : (config[:project] ? 'project' : 'common')
        raise "#{name}: wrong deep merge" unless catalog.resource('Notify', 'hash')[:message] == expected_winner
        expected_keys = ['common', 'winner']
        expected_keys << 'project' if config[:project]
        expected_keys << 'node' if config[:node]
        actual_keys = catalog.resources.select { |r| r.type == 'Notify' && r.title.start_with?('merged ') }.map { |r| r.title.delete_prefix('merged ') }
        raise "#{name}: lost merged hash keys" unless actual_keys.sort == expected_keys.sort
      end
    end
    puts "PASS environment #{name}"
  end
end

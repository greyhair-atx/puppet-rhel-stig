# Verify real environment discovery and modulepath, not an injected module path.
require 'puppet'
require 'tmpdir'
require 'fileutils'
require 'yaml'
root = File.expand_path('..', __dir__).tr('\\', '/')
Dir.mktmpdir('puppet-layout-') do |scratch|
  Puppet.initialize_settings(['--confdir', "#{scratch}/config", '--vardir', "#{scratch}/var", '--logdir', "#{scratch}/log", '--environmentpath', scratch])
  %w[production corp test].each do |name|
    dir = "#{scratch}/#{name}"
    FileUtils.mkdir_p(dir)
    %w[hiera.yaml environment.conf manifests data modules].each { |entry| FileUtils.cp_r("#{root}/#{entry}", dir) }
    File.write("#{dir}/data/common.yaml", {'classes'=>['custom::rpm_install'], 'custom::rpm_install::rpms'=>['common-package']}.to_yaml)
    # Every checkout contains all three data files: the server chooses one.
    %w[production corp test].each do |data_env|
      File.write("#{dir}/data/environment/#{data_env}.yaml", {'custom::rpm_install::rpms'=>["#{data_env}-package"]}.to_yaml)
    end
  end
  loader = Puppet::Environments::Directories.new(scratch, [])
  Puppet.override(environments: loader) do
    %w[production corp test].each do |name|
      environment = loader.get(name)
      expected_modulepath = File.expand_path("#{scratch}/#{name}/modules").tr('\\', '/')
      raise "#{name}: modulepath not local" unless environment.full_modulepath.map { |p| p.tr('\\', '/') }.include?(expected_modulepath)
      facts = Puppet::Node::Facts.new('layout.example.test', {'os'=>{'family'=>'RedHat','release'=>{'major'=>'9'}}})
      node = Puppet::Node.new('layout.example.test', facts: facts, environment: environment)
      # Puppet Server's catalog entry point supplies these before compiling.
      node.add_server_facts({})
      node.trusted_data = {'authenticated'=>'remote','certname'=>'layout.example.test','extensions'=>{}}
      catalog = Puppet::Parser::Compiler.compile(node)
      packages = catalog.resources.select { |r| r.type == 'Package' }.map(&:title).sort
      raise "#{name}: wrong defaults #{packages.inspect}" unless packages == ['common-package', "#{name}-package"].sort
      puts "PASS deployed layout #{name}"
    end
  end
end

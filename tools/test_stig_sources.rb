require 'puppet'
require 'tmpdir'
root = File.expand_path('..', __dir__).tr(92.chr, '/')
result = {}
Dir.mktmpdir do |scratch|
  Puppet.initialize_settings(['--confdir',scratch,'--vardir',"#{scratch}/var",'--logdir',"#{scratch}/log"])
  File.write("#{scratch}/site.pp", "include stigs::main\n")
  %w[8 9 10].each do |version|
    env = Puppet::Node::Environment.create("rhel#{version}".to_sym,["#{root}/modules"],"#{scratch}/site.pp")
    facts = Puppet::Node::Facts.new('test', {'os'=>{'family'=>'RedHat','name'=>'RedHat','release'=>{'major'=>version}}, 'networking'=>{'hostname'=>'test'}, 'processors'=>{'count'=>2}})
    node = Puppet::Node.new('test',facts: facts,environment: env)
    node.trusted_data = {'authenticated'=>'remote','certname'=>'test','extensions'=>{}}
    catalog = Puppet::Parser::Compiler.compile(node)
    result[version] = {}
    catalog.resources.select { |r| r.type == 'File' && r[:source] }.each do |r|
      paths = Array(r[:source]).map { |s| s.sub('puppet:///modules/','modules/').sub(%r{\Amodules/([^/]+)/}, 'modules/\1/files/') }
      selected = paths.find { |p| File.file?("#{root}/#{p}") }
      raise "No source #{version} #{r.title}: #{paths}" unless selected
      result[version][r.title] = selected
    end
    puts "PASS RHEL #{version}: #{result[version].length} shipped file sources"
  end
end

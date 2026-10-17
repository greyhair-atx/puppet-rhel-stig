require 'puppet'
require 'tmpdir'
root = File.expand_path('..', __dir__).tr('\\', '/')
Dir.mktmpdir('network-selection-') do |scratch|
  Puppet.initialize_settings(['--confdir', scratch, '--vardir', "#{scratch}/var", '--logdir', "#{scratch}/log"])
  cases = [
    ['full', {'pp_network'=>'A1','pp_project'=>'alpha','pp_role'=>'workstation'}, 'pc01.example.test', ['.pc01.example.test', '.alpha', '.workstation', '']],
    ['other-network', {'pp_network'=>'B2','pp_project'=>'alpha','pp_role'=>'workstation'}, 'pc01.example.test', ['.pc01.example.test', '.alpha', '.workstation', '']],
    ['missing-network', {'pp_project'=>'alpha','pp_role'=>'workstation'}, 'pc01.example.test', []],
    ['empty-network', {'pp_network'=>''}, 'pc01.example.test', []],
    ['network-only', {'pp_network'=>'A1'}, '', ['']],
    ['missing-project-role', {'pp_network'=>'A1'}, 'pc01.example.test', ['.pc01.example.test', '']],
    ['empty-project-role', {'pp_network'=>'A1','pp_project'=>'','pp_role'=>''}, 'pc01.example.test', ['.pc01.example.test', '']],
    ['invalid-network', {'pp_network'=>'../B2'}, 'pc01.example.test', nil],
    ['invalid-project', {'pp_network'=>'A1','pp_project'=>'../alpha'}, 'pc01.example.test', nil],
    ['invalid-role', {'pp_network'=>'A1','pp_role'=>'a/b'}, 'pc01.example.test', nil],
    ['invalid-node', {'pp_network'=>'A1'}, '../pc01', nil],
  ]
  ['8', '9', '10', nil, ''].each do |version|
    cases.each do |name, extensions, certname, tiers|
      manifest = "#{scratch}/#{name}.pp"
      File.write(manifest, %w[custom stigs].map { |mod| "file { '#{mod} probe': path => '/tmp/#{mod}-probe', source => #{mod}::source_candidates('puppet:///modules/#{mod}/audit/auditd.conf'), sourceselect => 'first' }" }.join("\n") + (version && !version.empty? ? "\ninclude custom::dnsmasq\n" : ""))
      environment = Puppet::Node::Environment.create(name.to_sym, ["#{root}/modules"], manifest)
      facts = Puppet::Node::Facts.new('test', {'os'=>{'family'=>'RedHat','release'=>{'major'=>version}}, 'networking'=>{'hostname'=>'WRONG-HOSTNAME'}})
      node = Puppet::Node.new('test', facts: facts, environment: environment)
      node.trusted_data = {'authenticated'=>'remote','certname'=>certname,'extensions'=>extensions}
      begin
        catalog = Puppet::Parser::Compiler.compile(node)
        raise 'Expected validation failure' unless tiers
        {'custom probe'=>['custom','audit/auditd.conf'], 'stigs probe'=>['stigs','audit/auditd.conf'], 'custom /etc/dnsmasq.conf'=>['custom','dnsmasq/dnsmasq.conf'], 'custom /etc/dnsmasq.d/custom.conf'=>['custom','dnsmasq/dnsmasq.d/custom.conf']}.each do |title, (mod, path)|
          next if title.start_with?('custom /') && (version.nil? || version.empty?)
          expected = tiers.map { |tier| "puppet:///modules/#{mod}/#{path}.#{extensions['pp_network']}#{tier}" } + ["puppet:///modules/#{mod}/#{path}"]
          expected = expected.flat_map do |source|
            base = "puppet:///modules/#{mod}/#{path}"
            version.nil? || version.empty? ? [source] : [source.sub(base, "#{base}.#{version}"), source]
          end
          resource = catalog.resource('File', title)
          actual = Array(resource[:source])
          raise "#{name} #{title}: #{actual.inspect} != #{expected.inspect}" unless actual == expected
          raise 'Wrong sourceselect' unless resource[:sourceselect] == 'first'
        end
      rescue => e
        raise unless tiers.nil? && e.message.include?('identities must start')
      end
      puts "PASS #{version.inspect} #{name}"
    end
  end
  # Validate each function independently so one error cannot mask the other.
  %w[custom stigs].each do |mod|
    ['../9', '9/other', '9.1', 9].each do |version|
      manifest = "#{scratch}/invalid-os.pp"
      File.write(manifest, "notify { 'probe': message => #{mod}::source_candidates('puppet:///modules/#{mod}/test.conf').join(',') }")
      environment = Puppet::Node::Environment.create("invalid_#{mod}".to_sym, ["#{root}/modules"], manifest)
      node = Puppet::Node.new('test', facts: Puppet::Node::Facts.new('test', {'os'=>{'release'=>{'major'=>version}}}), environment: environment)
      node.trusted_data = {'authenticated'=>'remote','certname'=>'test','extensions'=>{}}
      begin
        Puppet::Parser::Compiler.compile(node)
        raise 'Expected invalid OS failure'
      rescue => e
        raise unless e.message.include?('OS major version must contain only digits')
      end
      puts "PASS #{mod} invalid OS #{version.inspect}"
    end
  end
end

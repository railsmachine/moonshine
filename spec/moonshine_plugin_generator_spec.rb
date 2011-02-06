require 'spec_helper'

describe "MoonshinePluginGenerator" do

  before do
    FileUtils.mkdir_p(generator_rails_root)
    Rails::Generator::Scripts::Generate.new.run(["moonshine_plugin","iptables"], :destination => generator_rails_root)
  end

  after do
    FileUtils.rm_r(generator_rails_root)
  end

  it "generates correct files" do
    readme_path.should exist
    init_path.should exist
    module_path.should exist
    spec_path.should exist
  end

  it "generates a plugin module" do 
    module_path.read.should match(/module Iptables/)
  end
  
  it "generates an init.rb that includes the plugin module" do
    init_path.read.should match(/require ".*iptables\.rb"/)
    init_path.read.should match(/include Iptables/)
  end

  private

    def plugin_path
      generator_rails_root + 'vendor/plugins/moonshine_iptables'
    end

    def module_path
      plugin_path + 'lib/iptables.rb'
    end

    def init_path
      plugin_path + 'moonshine/init.rb'
    end

    def readme_path
      plugin_path + 'README.rdoc'
    end

    def spec_path
      plugin_path + 'spec/iptables_spec.rb'
    end

    def spec_helper_path
      plugin_path + 'spec/spec_helper.rb'
    end

end

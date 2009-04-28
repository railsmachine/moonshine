require File.join(File.dirname(__FILE__), 'spec_helper.rb')

class <%= module_name %>Manifest < Moonshine::Manifest
  plugin :<%= name %>
end

describe <%= module_name %> do
  
  before do
    @manifest = <%= module_name %>Manifest.new
  end
  
  
  it "should be executable" do
    @manifest.should be_executable
  end
    
end
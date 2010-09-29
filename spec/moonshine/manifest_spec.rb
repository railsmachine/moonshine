require 'spec_helper'

module Moonshine::Iptables
end

describe Moonshine::Manifest do

  after do
    if @manifest && application_template && application_template.exist?
      application_template.delete
    end
  end

  def application_template
    @application_template ||= @manifest.rails_root.join('app', 'manifests', 'templates', 'passenger.conf.erb')
  end

  it 'should load configuration' do
    Moonshine::Manifest.configuration.should_not == nil
    Moonshine::Manifest.configuration[:application].should_not == nil
  end

  it 'should load environment specific configuration' do
    Moonshine::Manifest.configuration[:test_yaml].should == 'what what what'
  end

  context 'templates' do
    it 'should use moonshine templates by default' do
      @manifest = Moonshine::Manifest::Rails.new
      @manifest.configure(:application => 'bar')

      moonshine_template = Pathname.new(__FILE__).dirname.join('..', '..', 'lib', 'moonshine', 'manifest', 'rails', 'templates', 'passenger.vhost.erb')
      template_contents = 'moonshine template: <%= configuration[:application] %>'
      @manifest.stub!(:local_template).and_return(application_template)

      @manifest.template(moonshine_template).should match('ServerName yourapp.com')
    end


    it 'should allow overriding by user provided templates in app/manifests/templates' do
      @manifest = Moonshine::Manifest.new
      @manifest.configure(:application => 'bar')

      FileUtils.mkdir_p application_template.dirname
      application_template.open('w') {|f| f.write "application template: <%= configuration[:application] %>" }

      moonshine_template = Pathname.new(__FILE__).dirname.join('..', '..', 'lib', 'moonshine', 'manifest', 'rails', 'templates', 'passenger.conf.erb')
      application_template = @manifest.rails_root.join('app', 'manifests', 'templates', 'passenger.conf.erb')
      application_template.should exist
      moonshine_template.should exist

      # should return the output from that existing thing
      @manifest.template(moonshine_template).should match('application template: bar')
    end
  end

  it 'should load plugins' do
    @manifest = Moonshine::Manifest.new
    # eval is configured in test/rails_root/vendor/plugins/moonshine_eval_test/moonshine/init.rb
    Moonshine::Manifest.configuration[:eval].should be
    @manifest = Moonshine::Manifest.new
    @manifest.should respond_to(:foo)
    @manifest.class.recipes.map(&:first).should include(:foo)
  end

  it 'should load database.yml into configuration[:database]' do
    Moonshine::Manifest.configuration[:database].should_not == nil
    Moonshine::Manifest.configuration[:database][:production].should == 'production'
  end

  describe '#on_stage' do
    before { @manifest = Moonshine::Manifest.new }
    context 'on a class level' do
      it 'should not error when we call on_stage' do
        lambda {
          Moonshine::Manifest.on_stage
        }.should_not raise_error(NoMethodError)
      end
    end
    
    context 'using a string' do
      it 'should run on_stage block when stage matches the given string' do
        Moonshine::Manifest.should_receive(:deploy_stage).and_return("my_stage")

        @manifest.on_stage("my_stage") { "on my_stage" }.should == 'on my_stage'
      end

      it "should not call block when it doesn't match" do
        Moonshine::Manifest.stub!(:deploy_stage).and_return("not_my_stage")

        @manifest.on_stage("my_stage") { "on my_stage" }.should == nil
      end
    end

    context 'using a symbol' do
      it 'should call block when it matches' do
        Moonshine::Manifest.should_receive(:deploy_stage).and_return("my_stage")

        @manifest.on_stage(:my_stage) { "on my_stage" }.should == 'on my_stage'
      end

      it "should not cal block when it doesn't match" do
        Moonshine::Manifest.stub!(:deploy_stage).and_return("not_my_stage")

        @manifest.on_stage(:my_stage) { "on my_stage" }.should == nil
      end
    end

    context 'using an array of strings' do
      it 'should call block when it matches ' do
        Moonshine::Manifest.stub!(:deploy_stage).and_return("my_stage")
        @manifest.on_stage("my_stage", "my_other_stage") { "on one of my stages" }.should == 'on one of my stages'

        Moonshine::Manifest.should_receive(:deploy_stage).and_return("my_other_stage")
        @manifest.on_stage("my_stage", "my_other_stage") { "on one of my stages" }.should == 'on one of my stages'
      end

      it "should not call block when it doesn't match" do
        Moonshine::Manifest.stub!(:deploy_stage).and_return("not_my_stage")

        @manifest.on_stage("my_stage", "my_other_stage") { "on one of my stages" }.should == nil
      end
    end

    context 'using an array of symbols' do
      it 'should call the block it matches' do
        Moonshine::Manifest.stub!(:deploy_stage).and_return("my_stage")

        @manifest.on_stage(:my_stage, :my_other_stage) { "on one of my stages" }.should == 'on one of my stages'

        Moonshine::Manifest.should_receive(:deploy_stage).and_return("my_other_stage")
        @manifest.on_stage(:my_stage, :my_other_stage) { "on one of my stages" }.should == 'on one of my stages'
      end

      it "should not the call block when it doesn't match" do
        Moonshine::Manifest.stub!(:deploy_stage).and_return("not_my_stage")

        @manifest.on_stage(:my_stage, :my_other_stage) { "on one of my stages" }.should == nil
      end
    end

    context 'using :unless with a string' do
      it 'should not call block when it matches' do
        Moonshine::Manifest.stub!(:deploy_stage).and_return("my_stage")

        @manifest.on_stage(:unless => "my_stage") { "not on one of my stages" }.should == nil
      end

      it 'should call block when it does not match' do
        Moonshine::Manifest.stub!(:deploy_stage).and_return("my_stage")

        @manifest.on_stage(:unless => "not_my_stage") { "not on one of my stages" }.should == 'not on one of my stages'
      end
    end

    context 'using :unless with a symbol' do
      it 'should not call block when it matches' do
        Moonshine::Manifest.stub!(:deploy_stage).and_return("my_stage")

        @manifest.on_stage(:unless => :my_stage) { "not on one of my stages" }.should == nil
      end

      it 'should call block when it does not match' do
        Moonshine::Manifest.stub!(:deploy_stage).and_return("my_stage")

        @manifest.on_stage(:unless => :not_my_stage) { "not on one of my stages" }.should == 'not on one of my stages'
      end

    end

    context 'using :unless with an array of strings' do
      it 'should not call block when it matches' do
        Moonshine::Manifest.stub!(:deploy_stage).and_return("my_stage")
        @manifest.on_stage(:unless => ["my_stage", "my_other_stage"]) { "not on one of my stages" }.should == nil
      end

      it 'should call block when it does not match' do
        Moonshine::Manifest.stub!(:deploy_stage).and_return("not_my_stage")
        @manifest.on_stage(:unless => ["my_stage", "my_other_stage"]) { "not on one of my stages" }.should == 'not on one of my stages'
      end
    end

    context 'using :unless with an array of symbols' do
      it 'should not call block when it matches' do
        Moonshine::Manifest.stub!(:deploy_stage).and_return("my_stage")
        @manifest.on_stage(:unless => [:my_stage, :my_other_stage]) { "not on one of my stages" }.should == nil
      end

      it 'should call block when it does not match' do
        Moonshine::Manifest.stub!(:deploy_stage).and_return("not_my_stage")
        @manifest.on_stage(:unless => [:my_stage, :my_other_stage]) { "not on one of my stages" }.should == "not on one of my stages"
      end
    end

  end

end

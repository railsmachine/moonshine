require 'rbconfig'
require File.join(File.dirname(__FILE__), '..', '..', 'lib', 'generators', 'moonshine_helper')

class MoonshineGenerator < Rails::Generator::Base
  include MoonshineGeneratorHelpers

  attr_reader :file_name, :klass_name

  default_options :user => 'rails',
                  :domain => 'yourapp.com',
                  :ruby => default_ruby,
                  :multistage => false

  def initialize(runtime_args, runtime_options = {})
    name = if runtime_args.first && runtime_args.first !~ /^--/
             runtime_args.shift
           else
             'application'
           end
    @file_name = name.downcase.underscore + "_manifest"
    @klass_name = @file_name.classify
    super
  end

  def gems
    gem_array = returning Array.new do |hash|
      Rails.configuration.gems.map do |gem|
        hash = { :name => gem.name }
        hash.merge!(:source => gem.source) if gem.source
        hash.merge!(:version => gem.requirement.to_s) if gem.requirement
        hash
      end if Rails.respond_to?( 'configuration' )
    end
    if (RAILS_GEM_VERSION rescue false)
      gem_array << {:name => 'rails', :version => RAILS_GEM_VERSION }
    else
      gem_array << {:name => 'rails'}
    end
    gem_array
  end

  def manifest
    recorded_session = record do |m|
      m.template  'Capfile', 'Capfile'
      m.directory 'app/manifests'
      m.template  'moonshine.rb', "app/manifests/#{file_name}.rb"
      m.directory 'app/manifests/templates'
      m.template  'readme.templates', 'app/manifests/templates/README'

      m.directory 'config'
      m.template  'moonshine.yml', 'config/moonshine.yml'
      m.template  'gems.yml', 'config/gems.yml', :assigns => { :gems => gems }

      m.template  'deploy.rb', 'config/deploy.rb'

      production_env_path = Pathname.new("#{rails_root_path}/config/environments/production.rb")
      if production_env_path.exist?
        production_env = production_env_path.read
        unless production_env.include?('ActionMailer::Base.delivery_method')
          m.gsub_file 'config/environments/production.rb', /\z/, "\n# Use postfix for mail delivery \nActionMailer::Base.delivery_method = :sendmail "
        end
      end

      if options[:multistage]
        m.directory 'config/deploy'
        m.template 'staging-deploy.rb', 'config/deploy/staging.rb'
        m.template 'production-deploy.rb', 'config/deploy/production.rb'

        m.directory 'config/moonshine'
        m.template 'staging-moonshine.yml', 'config/moonshine/staging.yml'
        m.template 'production-moonshine.yml', 'config/moonshine/production.yml'

        m.directory 'config/environments/'
        m.template 'staging-environment.rb', 'config/environments/staging.rb'
      end
    end
    
    intro = <<-INTRO
    
After the Moonshine generator finishes don't forget to:

- Edit config/moonshine.yml
Use this file to manage configuration related to deploying and running the app: 
domain name, git repos, package dependencies for gems, and more.

- Edit app/manifests/#{file_name}.rb
Use this to manage the configuration of everything else on the server:
define the server 'stack', cron jobs, mail aliases, configuration files 

    INTRO
    puts intro if File.basename($0) == 'generate'
    
    recorded_session
  end

  def application
    File.basename(rails_root_path)
  end

  def repository
    options[:repository] ||= begin
                               detected_repo = `git config remote.origin.url`.chomp
                               !detected_repo.blank? ? detected_repo : 'git@github.com:username/your_app_name.git'
                             end
  end

  def user
    options[:user]
  end

  def domain
    options[:domain]
  end

  def staging_domain
    "staging.#{options[:domain]}"
  end

  def server
    options[:server] || options[:domain]
  end

  def staging_server
    "staging.#{server}"
  end

  protected

    def add_options!(opt)
      opt.separator ''
      opt.separator 'Options:'
      opt.on("--user USER",
             "User to use on remote server") { |user| options[:user] = user }
      opt.on("--domain DOMAIN",
             "Domain name of your application") { |domain| options[:domain] = domain }
      opt.on("--repository REPOSITORY",
             "git or subversion repository to deploy from") { |repository| options[:repository] = repository }
      opt.on('--server SERVER',
              "server") { |server| options[:server] = server }
      opt.on('--multistage',
              "setup multistage deployment environment") { options[:multistage] = true }
      opt.on("--ruby RUBY",
             "Ruby version to install. Currently supports: mri, ree, ree187 (default), src187") { |ruby| options[:ruby] = ruby }
      
    end
  
    def ruby
      options[:ruby]
    end
  
end

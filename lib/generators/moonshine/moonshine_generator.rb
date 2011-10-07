class MoonshineGenerator < Rails::Generators::Base
  desc Pathname.new(__FILE__).dirname.join('..', '..', '..', 'generators', 'moonshine', 'USAGE').read
  argument :name, :optional => true, :default => 'application'
 
  class_option :application, :default => Rails.root.basename.to_s, :desc => 'name of your application'
  class_option :user, :default => 'rails', :desc => 'User to use on remote server', :type => :string
  class_option :domain, :default => 'yourapp.com', :desc => 'Domain name of your application', :type => :string
  class_option :repository, :default => 'git@github.com:username/your_app_name.git', :desc => 'git or subversion repository to deploy from', :type => :string
  class_option :ruby, :default => 'ree187', :desc => 'Ruby version to install. Currently supports: mri, ree, ree187, src187', :type => :string
  class_option :multistage, :default => false, :desc => 'setup multistage deployment environment', :type => :boolean

  def self.source_root
    @_moonshine_source_root ||= Pathname.new(__FILE__).dirname.join('..', '..', '..', 'generators', 'moonshine', 'templates')
  end
  
  def manifest
    template "Capfile", "Capfile"
    template "readme.templates", "app/manifests/templates/README"
    template "moonshine.rb", "app/manifests/#{file_name}.rb"
    template "moonshine.yml", "config/moonshine.yml"
    template "deploy.rb", "config/deploy.rb"

    if ActiveSupport::VERSION::MAJOR == 3 && ActiveSupport::VERSION::MINOR >= 1
      app_manifests_load_prevention_string = "config.paths['app/manifests'].skip_eager_load!"
    else 
      app_manifests_load_prevention_string = "config.paths.app.manifests 'app/manifests', :eager_load => false"
    end

    environment app_manifests_load_prevention_string, :verbose => true

    if options[:multistage]
      template 'staging-deploy.rb', 'config/deploy/staging.rb'
      template 'production-deploy.rb', 'config/deploy/production.rb'

      template 'staging-moonshine.yml', 'config/moonshine/staging.yml'
      template 'production-moonshine.yml', 'config/moonshine/production.yml'

      template 'staging-environment.rb', 'config/environments/staging.rb'
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
  end
 
protected
  def file_name
    @manifest_name ||= name.downcase.underscore + "_manifest"
  end
 
  def klass_name
    @klass_name ||= file_name.classify
  end

  def ruby
    options[:ruby] ||= "ree187"
  end

  def user
    options[:user]
  end

  def domain
    options[:domain]
  end

  def repository
    options[:repository] ||= begin
                               detected_repo = `git config remote.origin.url`.chomp
                               detected_repo.present? ? detected_repo : 'git@github.com:username/your_app_name.git'
                             end
  end

  def application
    @application ||= File.basename(RAILS_ROOT)
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
  
end

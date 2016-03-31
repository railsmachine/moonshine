require 'rbconfig'
require File.join(File.dirname(__FILE__), '..', '..', 'lib', 'generators', 'moonshine_helper')

if Rails.version.split(".").first.to_i > 2
  cls = Rails::Generators::Base
else
  cls = Rails::Generator::Base
end

class MoonshineGenerator < cls
  include MoonshineGeneratorHelpers

  source_root(File.join(File.dirname(__FILE__), 'templates'))

  attr_reader :file_name, :klass_name

  default_options :user => 'rails',
                  :domain => 'yourapp.com',
                  :ruby => default_ruby,
                  :multistage => false

  def initialize(runtime_args, runtime_options = {}, config = {})
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
    gem_array = []

    Gem.loaded_specs.each do |name,spec|
      gem_array << { :name => name, :version => spec.version, :source => spec.source }
    end

    if (RAILS_GEM_VERSION rescue false)
      gem_array << {:name => 'rails', :version => RAILS_GEM_VERSION }
    else
      gem_array << {:name => 'rails'}
    end

    gem_array
  end

  def manifest
  #  recorded_session = record do |m|
      template  'Capfile', 'Capfile'
      empty_directory 'app/manifests'
      template  'moonshine.rb', "app/manifests/#{file_name}.rb"
      empty_directory 'app/manifests/templates'
      template  'readme.templates', 'app/manifests/templates/README'

      inside 'config' do

      end
      template  'moonshine.yml', 'config/moonshine.yml'
      template  'gems.yml', 'config/gems.yml', :assigns => { :gems => gems }

      template  'deploy.rb', 'config/deploy.rb'

      production_env_path = Pathname.new("#{rails_root_path}/config/environments/production.rb")
      if production_env_path.exist?
        production_env = production_env_path.read
        unless production_env.include?('ActionMailer::Base.delivery_method')
          gsub_file 'config/environments/production.rb', /\z/, "\n# Use postfix for mail delivery \nActionMailer::Base.delivery_method = :sendmail "
        end
      end

      if options[:multistage]
        empty_directory 'config/deploy'
        template 'staging-deploy.rb', 'config/deploy/staging.rb'
        template 'production-deploy.rb', 'config/deploy/production.rb'

        empty_directory 'config/moonshine'
        template 'staging-moonshine.yml', 'config/moonshine/staging.yml'
        template 'production-moonshine.yml', 'config/moonshine/production.yml'

        directory 'config/environments/'
        template 'staging-environment.rb', 'config/environments/staging.rb'
      end
  #  end

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

   # recorded_session
  end

  def application
    File.basename(rails_root_path)
  end

  def repository
    'git@github.com:username/your_app_name.git'
    # options[:repository] ||= begin
    #                            detected_repo = `git config remote.origin.url`.chomp
    #                            !detected_repo.blank? ? detected_repo : 'git@github.com:username/your_app_name.git'
    #                          end
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
             "Ruby version to install. Currently supports: src193, src200, src21, src22, src23, brightbox21, brightbox22") { |ruby| options[:ruby] = ruby }

    end

    def ruby
      options[:ruby]
    end

end

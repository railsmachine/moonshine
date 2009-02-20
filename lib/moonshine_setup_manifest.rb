# Run by moonshine to install dependencies and setup directories. Requires
# these three variables in a YAML file in <tt>/tmp/moonshine.yml</tt>:
#
#   application: your_app_name
#   user: rails
#   deploy_to: /srv/your_app_name
#
# Calling <tt>cap deploy:setup</tt> or <tt>cap moonshine:bootstrap</tt>
# in <tt>RAILS_ROOT</tt> performs this step for you.
class MoonshineSetupManifest < ShadowPuppet::Manifest
  configure(YAML.load_file('/tmp/moonshine.yml'))

  recipe :gems, :directories

  # Installs the gem dependencies of the Moonshine::Manifest::Rails
  def gems
    package 'shadow_puppet', :provider => :gem, :ensure => '0.1.6'
    package 'shadow_facter', :provider => :gem, :ensure => '0.1.2'
    package 'capistrano', :provider => :gem, :ensure => '2.5.4'
    package 'rails', :provider => :gem, :ensure => :latest
  end

  #Essentially replicates the deploy:setup command from capistrano, but sets
  #up permissions correctly
  def directories
    deploy_to_array = configuration[:deploy_to].split('/').split('/')
    deploy_to_array.each_with_index do |dir, index|
      next if index == 0 || index >= (deploy_to_array.size-1)
      file '/'+deploy_to_array[1..index].join('/'), :ensure => :directory
    end
    dirs = [
      "#{configuration[:deploy_to]}",
      "#{configuration[:deploy_to]}/shared",
      "#{configuration[:deploy_to]}/releases"
    ]
    dirs.each do |dir|
      file dir, :ensure => :directory, :owner => configuration[:user], :group => configuration[:user]
    end
  end
end
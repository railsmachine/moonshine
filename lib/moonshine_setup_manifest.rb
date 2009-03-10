# Run by moonshine to install dependencies and setup directories. Requires
# these three variables in a YAML <tt>config/moonshine.yml</tt>:
#
#   application: your_app_name
#   user: rails
#   deploy_to: /srv/your_app_name
#
# Running <tt>cap deploy:setup</tt> or <tt>cap moonshine:bootstrap</tt>
# in uploads your <p>config/moonshine.yml</p> to <tt>/tmp/moonshine.yml</tt>
# on your server and applies this manifest.
class MoonshineSetupManifest < ShadowPuppet::Manifest
  configure(YAML.load_file('/tmp/moonshine.yml'))

  recipe :gems, :directories

  #TODO: replicate bin/bootstrap.sh here for 100% idempotency

  # Installs the gem dependencies of the Moonshine::Manifest::Rails
  def gems
    package 'shadow_puppet', :provider => :gem, :ensure => :latest
    package 'shadow_facter', :provider => :gem, :ensure => :latest
    package 'passenger', :provider => :gem, :ensure => :latest
  end

  #Essentially replicates the deploy:setup command from capistrano, but sets
  #up permissions correctly
  def directories
    deploy_to_array = configatron.deploy_to.split('/')
    deploy_to_array.each_with_index do |dir, index|
      next if index == 0 || index >= (deploy_to_array.size-1)
      file '/'+deploy_to_array[1..index].join('/'), :ensure => :directory
    end
    dirs = [
      "#{configatron.deploy_to}",
      "#{configatron.deploy_to}/shared",
      "#{configatron.deploy_to}/releases"
    ]
    dirs.each do |dir|
      file dir,
      :ensure => :directory,
      :owner => configatron.user,
      :group => configatron.retrieve('group', configatron.user),
      :mode => '775'
    end
  end
end
# The MoonshineSetupManifest is applied to the server during `cap deploy:setup`.
# It's responsible for preparing the server to being released to.
# Specifically, it sets up directories that capistrano will use during `cap deploy`.
#
class MoonshineSetupManifest < ShadowPuppet::Manifest

  # Before applying this manifest, `cap deploy:setup` handles uploading the `config/moonshine.yml` so we can load it here.
  configure(YAML.load_file('/tmp/moonshine.yml'))

  # If a stage-specific moonshine.yml (ie config/moonshine/staging.yml) is available, it will also be uploaded and loaded here.
  deploy_stage = ENV['DEPLOY_STAGE'] || 'undefined'
  if File.exist? "/tmp/moonshine/#{deploy_stage}.yml"
    configure(YAML.load_file("/tmp/moonshine/#{deploy_stage}.yml"))
  end

  ## Prerequites
  # 
  # The following configuration is required, either in `config/moonshine.yml` or `config/moonshine/<stage>.yml`:
  #
  #     :user: rails
  #     :deploy_to: /srv/your_app_name

  ## Recipes
  #
  ### Directories
  #
  # Essentially replicates the deploy:setup command from capistrano, but sets up permissions correctly
  def directories
    # First, the `deploy_to` directory is created, along with its parents
    deploy_to_array = configuration[:deploy_to].split('/')
    deploy_to_array.each_with_index do |dir, index|
      next if index == 0 || index >= (deploy_to_array.size-1)
      file '/'+deploy_to_array[1..index].join('/'), :ensure => :directory
    end

    dirs = [
      "#{configuration[:deploy_to]}",
      "#{configuration[:deploy_to]}/shared",
      "#{configuration[:deploy_to]}/shared/config",
      "#{configuration[:deploy_to]}/releases"
    ]

    # Then each of the required directories is created so the `user` can successfully `cap deploy`
    dirs.each do |dir|
      file dir,
      :ensure => :directory,
      :owner => configuration[:user],
      :group => configuration[:group] || configuration[:user],
      :mode => '775'
    end
  end
  recipe :directories
end

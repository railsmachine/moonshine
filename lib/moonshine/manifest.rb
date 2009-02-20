class Moonshine::Manifest < ShadowPuppet::Manifest
  def self.path_to_config
    File.join(working_directory, 'config', 'moonshine.yml')
  end

  def self.working_directory
    working_directory = ENV["RAILS_ROOT"] || Dir.getwd
  end

  configure(YAML.load_file(self.path_to_config))
end
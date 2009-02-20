class Moonshine::Manifest < ShadowPuppet::Manifest
  configure(YAML.load_file(ENV['RAILS_ROOT']+'/config/moonshine.yml'))
end
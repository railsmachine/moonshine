class Moonshine::Manifest < ShadowPuppet::Manifest
  def self.path_to_config
    File.join(working_directory, 'config', 'moonshine.yml')
  end

  def self.working_directory
    @working_directory ||= File.expand_path(ENV["RAILS_ROOT"] || Dir.getwd)
  end

  #TODO support templates in working_directory/app/manifest/templates/
  #TODO support templates in working_directory/vendor/plugins/**templates
  def template(template, b = nil)
    b ||= self.send(:binding)
    template_contents = File.read(File.expand_path(File.join(File.dirname(__FILE__), '..', 'templates', template)))
    ERB.new(template_contents).result(b)
  end

  configure(YAML.load_file(self.path_to_config))
end
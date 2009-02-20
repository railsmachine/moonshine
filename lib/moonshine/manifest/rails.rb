class Moonshine::Manifest::Rails < Moonshine::Manifest
  configure(:database => YAML.load_file(ENV['RAILS_ROOT']+'/config/database.yml'))
  cap = Capistrano::Configuration.new
  cap.load(:string => """
load 'deploy' if respond_to?(:namespace) # cap2 differentiator
Dir['#{ENV['RAILS_ROOT']}/vendor/plugins/*/recipes/*.rb'].each { |plugin| load(plugin) }
load '#{ENV['RAILS_ROOT']}/config/deploy'
""")
  configure(:capistrano => cap)
  recipe :test
  def test
    exec 'test', :command => 'true'
  end
end
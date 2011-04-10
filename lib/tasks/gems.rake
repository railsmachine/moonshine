namespace :moonshine do
  desc "Update config/moonshine.yml with a list of the required gems"
  task :gems => 'gems:base' do
    gemfile_path = File.join(Dir.pwd, 'Gemfile')
    if File.exist?(gemfile_path)
      puts "You don't need to run this task if you're using Bundler!"
    end
    gem_array = Rails.configuration.gems.reject{|g| g.frozen? && !g.framework_gem?}.map do |gem|
      hash = { :name => gem.name }
      hash.merge!(:source => gem.source) if gem.source
      hash.merge!(:version => gem.requirement.to_s) if gem.requirement
      hash
    end
    if (RAILS_GEM_VERSION rescue false)
      gem_array << {:name => 'rails', :version => RAILS_GEM_VERSION }
    else
      gem_array << {:name => 'rails'}
    end
    config_path = File.join(Dir.pwd, 'config', 'gems.yml')
    File.open( config_path, 'w' ) do |out|
      YAML.dump(gem_array, out )
    end
    puts "config/gems.yml has been updated with your application's gem"
    puts "dependencies. Please commit these changes to your SCM or upload"
    puts "them to your server with the cap local_config:upload command."
  end
end

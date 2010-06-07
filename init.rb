if Rails::VERSION::MAJOR > 2
  # Make app/manifests NOT be eagerly loaded
  Rails.configuration.paths.app.manifests 'app/manifests', :eager_load => false
end

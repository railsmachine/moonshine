module MoonshineGeneratorHelpers
  def rails_root_path
    RAILS_ROOT rescue Rails.root
  end
end
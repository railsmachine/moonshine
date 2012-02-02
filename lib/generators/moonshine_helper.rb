module MoonshineGeneratorHelpers

  def self.included(base)
    base.class_eval do
      extend ClassMethods
    end
  end

  def rails_root_path
    RAILS_ROOT rescue Rails.root
  end

  module ClassMethods
    def ruby_version
      RUBY_VERSION
    end

    def default_ruby
      case ruby_version
      when /^1\.8/
        'ree187'
      when "1.9.2"
        'src192'
      when "1.9.3"
        'src193'
      else
      end
    end
  end

end

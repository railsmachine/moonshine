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

    def options
      @@options ||= {}
    end

    def default_options(opts={})
      opts.each do |k,v|
        options[k] = v
      end
    end

    def default_ruby
      case ruby_version
      when "1.9.3"
        'src193'
      when "2.0.0"
        'src200'
      when /^2.1/
        'src21'
      when /^2.2/
        'src22'
      when /^2.3/
        'src23'
      else
      end
    end
  end

end

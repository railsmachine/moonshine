require 'pathname'
$here = Pathname.new(__FILE__).dirname.dirname

module MoonshineHelpers
  def fake_rails_root
    self.class.fake_rails_root
  end

  def generator_rails_root
    self.class.generator_rails_root
  end

  module ClassMethods
    def fake_rails_root
      $here.join('rails_root')
    end

    def generator_rails_root
      @generator_rails_root ||= Pathname.new "#{Dir.tmpdir}/moonshine-generator-rails-root-#{Time.now.strftime('%Y%m%d%H%M%S')}" 
    end
  end

end

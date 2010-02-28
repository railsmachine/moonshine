require 'pathname'
$here = Pathname.new(__FILE__).dirname.dirname

module MoonshineHelpers
  def fake_rails_root
    self.class.fake_rails_root
  end

  def generator_rails_root
    self.class.generator_rails_root
  end

  def in_apache_if_module(contents, some_module)
    contents.should =~ /<IfModule #{some_module}>(.*)<\/IfModule>/m

    contents.match(/<IfModule #{some_module}>(.*)<\/IfModule>/m)
    yield $1 if block_given?
  end

  module ClassMethods
    def fake_rails_root
      $here.join('rails_root')
    end


    def generator_rails_root
      $here.join('generator_rails_root')
    end
  end

end

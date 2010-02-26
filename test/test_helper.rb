require 'rubygems'
require 'test/unit'
require 'ginger'

require 'pathname'
$here = Pathname.new(__FILE__).dirname

# rails version specific kludge to get generator tests working
require 'rails/version'
if Rails::VERSION::MAJOR == 2
  require 'support/rails_2_generator_kludge'
end

require 'moonshine'
require 'shadow_puppet/test'
require 'mocha'


Test::Unit::TestCase.class_eval do
  def fake_rails_root
    self.class.fake_rails_root
  end

  def self.fake_rails_root
    $here.join('rails_root')
  end

  def generator_rails_root
    self.class.generator_rails_root
  end

  def self.generator_rails_root
    breakpoint
    $here.join('generator_rails_root')
  end

  def assert_manifest_file_exists(manifest, path)
    message = "manifest (#{manifest.files.keys.join(', ')}) files does not contain #{path}"
    assert_block message do
      manifest.files.has_key?(path.to_s)
    end
  end

  def assert_apache_directive(contents, directive, value)
    # Make sure directive is there first
    assert_match directive, contents
    assert_block "Wasn't able to find a value for <#{directive}>" do
      if contents =~ /^\s*#{directive}\s+(\w+)[^#\n]*/
        assert_block "Expected <#{value}> for <#{directive}>, but got <#{$1}>" do
          $1 == value.to_s
        end
        true
      else
        false
      end
    end
  end

  def in_apache_if_module(contents, some_module)
    assert_block "Doesn't contain <IfModule #{some_module}>" do
      if contents =~ /<IfModule #{some_module}>(.*)<\/IfModule>/m
        yield $1 if block_given?
        true
      else
        false
      end
    end
    
  end

end

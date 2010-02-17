require 'test_helper'

class TestPathname < Test::Unit::TestCase
  def test_match
    assert Pathname.new('/etc') =~ /#{File::SEPARATOR}/
  end

  def test_gsub
    assert_equal '/tmp',  Pathname.new('/etc').gsub('etc', 'tmp')
  end
end

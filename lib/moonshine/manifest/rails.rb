class Moonshine::Manifest::Rails < Moonshine::Manifest
  recipe :test
  def test
    exec 'test', :command => 'true'
  end
end
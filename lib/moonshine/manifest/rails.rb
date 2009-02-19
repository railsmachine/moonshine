class Moonshine::Manifest::Rails < ShadowPuppet::Manifest
  recipe :test
  def test
    exec 'test', :command => 'true'
  end
end
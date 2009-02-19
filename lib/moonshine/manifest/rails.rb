class Moonshine::Manifest::Rails < ShadowPuppet::Manifest
  recpie :test
  def test
    exec 'test', :command => 'true'
  end
end
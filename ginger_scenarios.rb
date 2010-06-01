require 'ginger'

def create_scenario(version)
  scenario = Ginger::Scenario.new("Rails #{version}")
  scenario[/^activesupport$/] = version
  scenario[/^activerecord$/] = version
  scenario[/^actionpack$/] = version
  scenario[/^actioncontroller$/] = version
  scenario
end

Ginger.configure do |config|
  config.aliases["rails"] = "rails"
  
  rails_2_3_5 = create_scenario('2.3.5')
  rails_2_3_8 = create_scenario('2.3.8')

  rails_3_0_0_beta = create_scenario('3.0.0.beta')
  rails_3_0_0_beta3 = create_scenario('3.0.0.beta3')
  
  config.scenarios << rails_2_3_5 << rails_2_3_8 << rails_3_0_0_beta << rails_3_0_0_beta3
end


module Moonshine::Recipes
end
Dir["#{File.dirname(__FILE__)}/recipes/*"].each do |recipe|
  require recipe
end
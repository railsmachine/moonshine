require 'rubygems'

spec = Gem::Specification.new do |s|
  s.name = 'moonshine_generator'
  s.version = '0.0.1'
  s.summary = ''
  s.description = ''
  s.files = [
    'moonshine_generator.rb',
    'templates/moonshine.rb'
  ]
  s.require_path = 'templates'
  s.authors = ["Jesse Newland"]
  s.email = ["jesse@railsmachine.com"]
end
require 'rake'
require 'rake/testtask'
begin
  require 'rubygems'
  require 'hanna/rdoctask'
rescue LoadError
  require 'rake/rdoctask'
end

task :rcov do
  system "rcov --exclude /Library/Ruby/ --exclude ~/ -Itest `find test/ | grep _test`"
end

desc 'Default: run unit tests.'
task :default => :test

desc 'Test the moonshine plugin.'
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.libs << 'test'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end

desc 'Generate documentation for the moonshine plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'doc'
  rdoc.title    = 'Moonshine'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README.rdoc')
  rdoc.rdoc_files.include('lib/**/*.rb')
  rdoc.main = "README.rdoc"
  rdoc.options << '--webcvs=http://github.com/railsmachine/moonshine/tree/master/'
end

task :build => :cleanup do
  system "gem build *.gemspec"
end

task :install => :build do
  system "sudo gem install *.gem"
end

task :uninstall do
  system "sudo gem uninstall *.gem"
end

task :cleanup do
  system "rm *.gem"
end

task :pull do
  system "git pull origin master"
  system "git pull github master"
end

task :_push do
  system "git push origin master"
  system "git push github master"
end

task :push => [:redoc, :pull, :test, :_push]

task :redoc do
  #clean
  system "git checkout gh-pages && git pull origin gh-pages && git pull github gh-pages"
  system "rm -rf doc"
  system "git checkout master"
  system "rm -rf doc"

  #doc
  Rake::Task['rdoc'].invoke

  #switch branch
  system "git checkout gh-pages"

  #move it all to the root
  system "cp -r doc/* . && rm -rf doc"

  #commit and push
  system "git commit -am 'regenerate rdocs' && git push origin gh-pages && git push github gh-pages"
  system "git checkout master"
end

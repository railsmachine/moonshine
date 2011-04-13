# Creates a new task
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..'))
require 'moonshine/tasks'
Moonshine::Rake::UpdateTask.new()
Moonshine::Rake::DocTask.new()

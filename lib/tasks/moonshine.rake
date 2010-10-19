namespace :moonshine do

  desc "Update Moonshine"
  task :update do
    
    if File.exist?("#{RAILS_ROOT}/.svn")
      puts "Updating Moonshine plugin"
      if `cd #{RAILS_ROOT} && svn stat -q --ignore-externals`.empty?
        command = ["svn up",
                   "cd #{RAILS_ROOT}",
                   "svn rm vendor/plugins/moonshine",
                   "svn commit -m 'cleaning moonshine before update'",
                   "ruby script/plugin install git://github.com/railsmachine/moonshine.git",
                   "svn add vendor/plugins/moonshine",
                   "svn commit -m 'updated moonshine'"]
      else
        puts "You have changes in your project directory. Please commit before updating Moonshine."
      end
      
    elsif File.exist?("#{RAILS_ROOT}/.gitmodules") && 
          File.open("#{RAILS_ROOT}/.gitmodules"){|f| f.grep /moonshine\.git/} &&
          File.exist?("#{RAILS_ROOT}/vendor/plugins/moonshine/.git")

      puts "Updating Moonshine submodule"
      command = ["cd #{RAILS_ROOT}/vendor/plugins/moonshine",
                  "git pull origin master"]

    else
      
      puts "Updating Moonshine plugin"
      command = ["cd #{RAILS_ROOT}",
                 "ruby script/plugin install --force git://github.com/railsmachine/moonshine.git"]
    
    end
    
    unless command.nil?
      puts `#{command.join(' && ')}`
    end
  end

end

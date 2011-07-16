require 'rake/tasklib'
module Moonshine
  module Rake

    class DocTask < ::Rake::TaskLib
      def initialize(options = {})
        @options    = options
        @moonshine_files = []
        setup_moonshine_files
        define
      end

      private

      def setup_moonshine_files
        ['app/manifests/*.rb', 'config/moonshine.yml', 'config/moonshine/*.yml'].each do |path|
          Dir.glob(path).each do |f|
            @moonshine_files << f
          end
        end
      end

      def define
        namespace :moonshine do
          task :doc => :"doc:default"

          namespace :doc do
            task :default do
              begin
                require 'rocco'
              rescue
                puts 'Exiting: you need to install the `rocco` gem.'
                exit(1)
              end
              @moonshine_files.each do |file|
                puts "Rocco'ing #{file}..."
                system "rocco -o doc/ #{file} > /dev/null 2>&1"
              end
            end
          end
        end
      end
    end


    class UpdateTask < ::Rake::TaskLib
      def initialize(options = {})
        @options    = options
        @remote     = (@options[:remote] || 'railsmachine')
        @repo       = "moonshine#{ '_' + @options[:plugin] if @options[:plugin]}"
        @plugin_cmd = "ruby script/#{File.exist?('script/plugin') ? 'plugin' : 'rails plugin'}"
        define
      end

      private
      def pretty_repo(r)
        r.split('_').map { |s| s.capitalize }.join(' ')
      end

      def define
        namespace :moonshine do
          task :update => :"update:default"

          namespace :update do
            desc "Update #{@remote}'s #{pretty_repo @repo} plugin"
            task (@options[:plugin] ? @options[:plugin].to_sym : :default) do
              update_moonshine
            end
          end
        end
      end

      def update_moonshine
        if File.exist?("#{RAILS_ROOT}/.svn")
          puts "Updating #{@remote}'s #{pretty_repo @repo} plugin"
          if `cd #{RAILS_ROOT} && svn stat -q --ignore-externals`.empty?
            command = [
              "svn up",
              "cd #{RAILS_ROOT}",
              "svn rm vendor/plugins/#{@repo}",
              "svn commit -m 'cleaning #{@repo} before update'",
              "#{@plugin_cmd} install git://github.com/#{@remote}/#{@repo}.git",
              "svn add vendor/plugins/#{@repo}",
              "svn commit -m 'updated #{@repo}'"
            ]
          else
            puts "You have changes in your project directory. Please commit before updating #{@repo}."
          end

        elsif File.exist?("#{RAILS_ROOT}/.gitmodules") && 
          File.open("#{RAILS_ROOT}/.gitmodules") {|f| f.grep /#{@repo}\.git/}.any? &&
          File.exist?("#{RAILS_ROOT}/vendor/plugins/#{@repo}/.git")

          puts "Updating #{@remote}'s #{pretty_repo @repo} submodule"
          command = [
            "cd #{RAILS_ROOT}/vendor/plugins/#{@repo}",
            "git pull origin master"
          ]

        else

          puts "Updating #{@remote}'s #{pretty_repo @repo} plugin"
          command = [
            "cd #{RAILS_ROOT}",
            "#{@plugin_cmd} install --force git://github.com/#{@remote}/#{@repo}.git"
          ]
        end

        unless command.nil?
          puts `#{command.join(' && ')}`
        end
      end

    end
  end
end

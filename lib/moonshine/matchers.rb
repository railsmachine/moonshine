module Moonshine
  module Matchers
    extend Spec::Matchers::DSL

    define :have_apache_directive do |directive, value|
      match do |actual|
        if actual.respond_to?(:content)
          actual = actual.content
        end

        if actual =~ /^\s*#{directive}\s+(.+)[^#\n]*/
          @found_value = $1
          value.to_s == @found_value
        else
          false
        end
      end

      failure_message_for_should do |actual|
        if @found_value
          "expected to <#{value}> for <#{directive}>, but got #{@found_value}"
        else
          "expected to find a value for <#{directive}>"
        end
      end

      description do
        "should have Apache #{directive} with value of #{value}"
      end
    end

    define :use_recipe do |expected|
      match do |manifest|
        recipes = manifest.recipes.map(&:first)
        recipes.include?(expected)
      end

      description do
        "should use #{expected} recipe"
      end
    end

    define :require_resource do |expected|
      expected = Array(expected)
      resource_string = expected.map { |r| "#{r.type.downcase}('#{r.title}')"}.join(',')
      actual_string = ''

      match do |resource|
        resources = Array(resource.require)
        actual_string = resources.flatten.map { |r| "#{r.type.downcase}('#{r.title}')"}.join(',')

        if expected.length > resources.length
          false
        else
          expected.each do |expected_resource|
            result &&= resources.flatten.detect do |actual_resource|
              actual_resource.type == expected_resource.type &&
              actual_resource.title == expected_resource.title
            end
          end
        end
      end

      description do
        "should require all of #{resource_string}"
      end

      failure_message_for_should do |actual|
        "expected resource to require all of #{resource_string}, but required #{actual_string}"
      end

      failure_message_for_should_not do |actual|
        "expected resource not to require #{resource_string}, but required #{actual_string}"
      end
    end

    define :have_package do |expected|
      match do |manifest|
        package = manifest.packages[expected]
        result = !package.nil?
        if @version
          result &&= package.ensure == @version
        end
        if @provider
          @actual_provider = package.provider
          result &&= @actual_provider == @provider.to_sym
        end

        result
      end

      def version(version)
        @version = version
        self
      end

      def from_provider(provider)
        @provider = provider
        self
      end

      failure_message_for_should do |actual|
        if @provider
          "expected manifest to have package #{expected} using #{@provider}, was using #{@actual_provider}"
        else
          "expected manifest to have package #{expected}, but did not"
        end
      end

      failure_message_for_should_not do |actual|
        "expected manifest to not have package #{expected}, but did"
      end

    end

    define :have_service do |expected|
      match do |manifest|
        !manifest.services[expected].nil?
      end

      failure_message_for_should do |actual|
        "expected manifest to have #{expected}, but did not"
      end

      failure_message_for_should_not do |actual|
        "expected manifest to not have #{expected}, but did"
      end
    end

    define :have_file do |expected|
      match do |manifest|
        @file = manifest.files[expected]
        result = !@file.nil?
        if @str_or_regex
          @str_or_regex_matched = @file.content.match(@str_or_regex)
          result &&= @file.content && @str_or_regex_matched
        elsif @symlink_target
          @symlinked_to_target = @file.ensure == @symlink_target
          result &&= @symlinked_to_target
          end
        result
      end

      def with_content(str_or_regex)
        @str_or_regex = str_or_regex
        self
      end

      def symlinked_to(file)
        @symlink_target = file
        self
      end

      failure_message_for_should do |actual|
        if @str_or_regex
          if !@str_or_regex_matched
            "expected to #{expected} to match #{@str_or_regex.inspect}, but it did not match. Contains:\n#{@file.content}"
          else
            "expected to #{expected} to match #{@str_or_regex.inspect}, but it didn't exist"
          end
        elsif @symlink_target
          if !@symlinked_to_target
            "expected to #{expected} to be symlinked to #{@symlink_target}, but was not"
          else
            "expected to #{expected} to be symlinked to #{@symlink_target}, but it didn't exist"
          end
        else
          "expected to #{expected} to match #{@str_or_regex.inspect}, but it didn't exist"
        end
      end
    end

    define :exec_command do |command|
      match do |manifest|
        manifest.execs.find do |name, exec|
          exec.command == command
        end
      end
    end


    def in_apache_if_module(contents, some_module)
      contents.should =~ /<IfModule #{some_module}>(.*)<\/IfModule>/m

      contents.match(/<IfModule #{some_module}>(.*)<\/IfModule>/m)
      yield $1 if block_given?
    end
  end
end

module Capistrano
  module Helpers
    def find_callback(configuration, on, task)
      if task.kind_of?(String)
        task = configuration.find_task(task)
      end

      callbacks = configuration.callbacks[on]

      callbacks && callbacks.select do |task_callback|
        task_callback.applies_to?(task) || task_callback.source == task.fully_qualified_name
      end
    end

  end

  module Matchers
    extend Spec::Matchers::DSL

    define :callback do |task_name|
      extend Helpers

      match do |configuration|
        @task = configuration.find_task(task_name)
        callbacks = find_callback(configuration, @on, @task)

        if callbacks
          @callback = callbacks.first

          if @callback && @after_task_name
            @after_task = configuration.find_task(@after_task_name)
            @callback.applies_to?(@after_task)
          elsif @callback && @before_task_name
            @before_task = configuration.find_task(@before_task_name)
            @callback.applies_to?(@before_task)
          else
            ! @callback.nil?
          end
        else
          false
        end
      end

      def on(on)
        @on = on
        self
      end

      def before(before_task_name)
        @on = :before
        @before_task_name = before_task_name
        self
      end

      def after(after_task_name)
        @on = :after
        @after_task_name = after_task_name
        self
      end

      failure_message_for_should do |actual|
        if @after_task_name
          "expected configuration to callback #{task_name.inspect} #{@on} #{@after_task_name.inspect}, but did not"
        elsif @before_task_name
          "expected configuration to callback #{task_name.inspect} #{@on} #{@before_task_name.inspect}, but did not"
        else
          "expected configuration to callback #{task_name.inspect} on #{@on}, but did not"
        end
      end
      
    end

  end
end

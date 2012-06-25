Puppet::Provider::Package::Gem.class_eval do

  def execute_with_clean_env(*args)
    Bundler.with_clean_env do
      execute_without_clean_env *args
    end
  end

  alias_method_chain :execute, :clean_env
end

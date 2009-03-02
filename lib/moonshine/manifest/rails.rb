module Moonshine  #:nodoc:
  module Manifest   #:nodoc:
    class Rails < Moonshine::Manifest::Base
      plugin File.join(File.dirname(__FILE__), '..', 'plugin', 'passenger.rb')
      plugin File.join(File.dirname(__FILE__), '..', 'plugin', 'mysql.rb')
      plugin File.join(File.dirname(__FILE__), '..', 'plugin', 'apache.rb')
      plugin File.join(File.dirname(__FILE__), '..', 'plugin', 'rails.rb')
      plugin File.join(File.dirname(__FILE__), '..', 'plugin', 'mail.rb')
      plugin File.join(File.dirname(__FILE__), '..', 'plugin', 'time.rb')
    end
  end
end
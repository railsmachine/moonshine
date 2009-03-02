module Moonshine::Plugin::Mail
  def mail_postfix
    package 'postfix', :ensure => :latest
  end
end

include Moonshine::Plugin::Mail
recipe :mail_postfix
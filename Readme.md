# Moonshine

Moonshine is Rails deployment and configuration management done right.

By leveraging capistrano and puppet, moonshine allows you have a working application server in 15 minutes, and be able to sanely manage it's configuration from the comfort of your version control of choice.

To get started, check out our [tutorial](https://github.com/railsmachine/moonshine/wiki/Tutorial). It covers configuring and deploying your application for the first time with Moonshine.

Once you're a bit more comfortable with Moonshine, you'll find our documentation on [the wiki](https://github.com/railsmachine/moonshine/wiki) to be helpful!

## Requirements

* A server running Ubuntu 8.10, 10.04 LTS or 12.04 LTS (Want to see your favorite platform supported?  Fork Moonshine on GitHub!)
* A Rails 2.3 or Rails 3 app. Rails 4 is supported with the [plugger](http://github.com/railsmachine/plugger) gem.
* A user on this server that can:
  * Execute commands via sudo
  * Access your application's source code repository

## Installation

It's also pretty simple!

### Rails 2

    $ script/plugin install git://github.com/railsmachine/moonshine.git
    $ script/generate moonshine
  
### Rails 3

    $ script/rails plugin install git://github.com/railsmachine/moonshine.git
    $ script/rails generate moonshine
  
### Rails 4

Add <code>gem 'plugger'</code> to your Gemfile and bundle install, then:

    $ plugger install git://github.com/railsmachine/moonshine.git
    $ script/rails generate moonshine

If you get errors about not being able to find shadow_puppet during deploys, you'll also need to add the following to your Gemfile:

    gem 'shadow_puppet', :require => false

## Running Tests

It's easy enough:

    $ gem install shadow_puppet isolate-scenarios
    $ rake spec

[isolate-scenarios](http://github.com/technicalpickles/isolate-scenarios) is used to test against multiple versions of Rails. To run all scenarios at once:

   $ isolate-scenarios rake spec

## Getting Help

You can find more examples in the [documentation](http://railsmachine.github.com/moonshine) and on the [Wiki](https://github.com/railsmachine/moonshine/wiki).

For help or general discussion, visit the [Moonshine newsgroup](http://groups.google.com/group/railsmachine-moonshine).

## Passenger Enterprise Support

We've added support for Passenger Enterprise Edition!  In order to install it, you need to make a few changes to moonshine.yml.  Since you have to download the gem from Phusion, you now need to tell us where it is.  You also need to put your license file in app/manifests/templates and call it <code>passenger-enterprise-license</code> so we can put it in the right place during install.

This is what a passenger enterprise block in moonshine.yml should look like (in addition to your usual Passenger settings):

    :passenger:
      :version: 4.0.10
      :enterprise: true
      :gemfile: vendor/gems/passenger-enterprise-server-4.0.10.gem
      :rolling_restarts: true
    
## A Word on Rails 4

We've been torturing ourselves trying to turn Moonshine into a gem ever since it was announced that Rails 4 was dropping support for plugins.  Moonshine is... different... and we think it actually makes sense as a plugin.  So, instead of turning Moonshine, and the dozens of Moonshine plugins we've written, into a gem, we decided to add plugin support back to Rails 4!  That's where [plugger](http://github.com/railsmachine/plugger) comes in. Just add it to your Gemfile and <code>bundle install</code> and voila, plugins are *back*!


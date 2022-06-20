# Moonshine

Moonshine is Rails deployment and configuration management done right.

By leveraging capistrano and puppet, moonshine allows you have a working application server in 15 minutes, and be able to sanely manage it's configuration from the comfort of your version control of choice.

To get started, check out our [tutorial](https://github.com/railsmachine/moonshine/wiki/Tutorial). It covers configuring and deploying your application for the first time with Moonshine.

Once you're a bit more comfortable with Moonshine, you'll find our documentation on [the wiki](https://github.com/railsmachine/moonshine/wiki) to be helpful!

## Requirements

* A server running Ubuntu 12.04 or 14.04 LTS (Want to see your favorite platform supported?  Fork Moonshine on GitHub!)
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

We've added support for Passenger Enterprise Edition!  In order to install it, you need to make a few changes to moonshine.yml.  Phusion now provides a gem server for Passenger Enterprise. You will need to put your license file in app/manifests/templates and call it <code>passenger-enterprise-license</code> so we can put it in the right place during install.

This is what a passenger enterprise block in moonshine.yml should look like (in addition to your usual Passenger settings):

```yaml
:passenger:
  :version: 4.0.10
  :enterprise: true
  :download_token: YOUR-PASSENGER-ENTERPRISE-DOWNLOAD-TOKEN
  :rolling_restarts: true
```

## Brightbox Ruby

Compiling ruby from source is time and CPU consuming.  In an attempt to speed up ruby upgrades and make it easier to roll back to the previous version, we've added support for [Brightbox's Ruby packages](http://brightbox.com/docs/ruby/ubuntu/). Setting it up is easy, just set the ruby line in config/moonshine.yml to <code>brightbox193</code> or <code>brightbox21</code>.

### Limitations

* **Ubuntu 10.04**: Brightbox doesn't provide packages for Ruby 2.1.x.  If you want it, you'll need to upgrade to at least 12.04.
  
## A Word on Rails 4

We've been torturing ourselves trying to turn Moonshine into a gem ever since it was announced that Rails 4 was dropping support for plugins.  Moonshine is... different... and we think it actually makes sense as a plugin.  So, instead of turning Moonshine, and the dozens of Moonshine plugins we've written, into a gem, we decided to add plugin support back to Rails 4!  That's where [plugger](http://github.com/railsmachine/plugger) comes in. Just add it to your Gemfile and <code>bundle install</code> and voila, plugins are *back*!

### Keeping Your App From Loading Manifests

By default, everything within the app directory is eager-loaded by the app at startup in production mode (and staging).  That's not good.  So, to keep that from happening, add this to config/application.rb inside the Application class:

```ruby
path_rejector = lambda { |s| s.include?("app/manifests") }
config.eager_load_paths = config.eager_load_paths.reject(&path_rejector)
ActiveSupport::Dependencies.autoload_paths.reject!(&path_rejector)
```

That'll keep the manifests from loading when the app starts up!

### Getting rid of that annoying message when you run rails console

With Rails 4, it doesn't want you to use the <code>--binstubs</code> argument for bundler, so it's now optional.  If you're using Moonshine and Rails 4, add this to config/moonshine.yml, and you'll be all set:

```yaml
:bundler:
  :disable_binstubs: true
```
  
After your next deploy, you should be able to run rails console without that annoying error message.

All content copyright &copy; 2014, [Rails Machine LLC](http://railsmachine.com)

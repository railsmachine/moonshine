# Moonshine::<%= module_name %>

## ATTENTION FUTURE MOONSHINE <%= module_name.upcase %> MAINTAINER!

Welcome to you who has generated this Moonshine::<%= module_name %> plugin.

Here's what you have:

 * README.markdown: this file
 * LICENSE: the MIT license
 * lib/moonshine/<%= name %>.rb: where the plugin code actually lives
 * moonshine/init.rb: required glue to let moonshine know about this plugin
 * spec/moonshine/<%= name %>_spec.rb: example specs
 * spec/spec_helper.rb: helper for specs

This README is all just an example, but it should give you a This should be enough to get you started, but just wanted to give you a templated to get started documenting and developing.

This file should focus on:

 * explanation of what it's all about
 * a quick start guide
 * configuration options

The rest of this file is filled with idyllic and fictional information. Remember to review everything here, fix links, remove junk, etc.

PS: You might want to delete this section :)

## Introduction

Welcome to Moonshine::<%= module_name %>, a [Moonshine](http://github.com/railsmachine/moonshine) plugin for installing and managing [<%= name %>](http://www.google.com/search?q=<%= name %>)

Here's some quick links:

 * [Homepage](http://github.com/ACCOUNT/moonshine_<%= name %>)
 * [Issues](http://github.com/ACCOUNT/moonshine_<%= name %>/issues) 
 * [Wiki](http://github.com/ACCOUNT/moonshine_<%= name %>/wiki) 
 * [Mailing List](http://groups.google.com)
 * Resources for using <%= module_name %>:
   * [<%= module_name %> Homepage](http://www.google.com/search?q=<%= name %>)

## Quick Start

Moonshine::<%= module_name %> is installed as a Rails plugin:

    # Rails 2.x.x
    script/plugin install git://github.com/ACCOUNT/moonshine_<%= name %>.git
    # Rails 3.x.x
    script/rails plugin install git://github.com/ACCOUNT/moonshine_<%= name %>.git

Once it's installed, you can include it in your manifest:

    # app/manifests/application_manifest.rb
    class ApplicationManifest < Moonshine::Manifest:Rails

       # other recipes and configuration omitted

       # tell ApplicationManifest to use the <%= name %> recipe
       recipe :<%= name %>
    end

Ideally, things should work out of the box. If not, be sure to make the code detects missing configuration and fails with instructions. Also, include details about any required settings here.

## Configuration Options

Here's some other <%= name %> configuration options you may be interested in.

 * `:degrees`: an integer representing the degree of <%= name %>

These are namespaced under `:<%= name %>`. They can be configured a few ways:

    # in global config/moonshine.yml
    :<%= name %>:
      :degrees: 10000

    # in stage-specific moonshine.yml,
    # config/moonshine/staging.yml and config/moonshine/production.yml
    :<%= name %>:
      :degrees: 10000

    # `configure` call in app/manifests/application_manifest.rb
    configure :<%= name %> => { :degrees => 10000 }

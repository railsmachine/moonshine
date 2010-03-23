<%- if options[:multistage] %>
require 'capistrano/ext/multistage'
<%- else %>
server '<%= domain %>', :app, :web, :db, :primary => true
<%- end %>

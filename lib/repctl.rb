# The compiled-in default is not generally very useful.
config_dir = ENV["REPCTL_CONFIG_DIR"] ||
  File.expand_path('../../config', __FILE__)
  
require File.join(config_dir, 'config')

require "repctl/version"
require "repctl/servers"
require "repctl/mysql_admin"
require "repctl/color"

module Repctl
  # Your code goes here...
end

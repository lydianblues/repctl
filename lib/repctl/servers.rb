require 'yaml'

module Repctl

  module Servers
    
    include Config

    def all_servers
      @servers ||= File.open(SERVER_CONFIG) { |yf| YAML::load( yf ) }
    end
    
    def all_instances
      instances = []
      all_servers.each do |s|
        instances << s["instance"]
      end
      instances
    end
    
    def server_for_instance(instance)
      all_servers.select {|s| s["instance"] == Integer(instance)}.shift
    end

    def all_live_servers
      all_servers.select {|s| get_mysqld_pid(s["instance"]) }
    end

    def all_live_instances
      all_live_servers.map {|s| s["instance"]}
    end

    def live?(instance)
      get_mysqld_pid(instance)
    end

    def instance_for(host, port)
      @servers.each do |s|
        if s["hostname"] == host && s["port"].to_i == port.to_i
          return s["instance"].to_i
        end
      end
      return nil
    end

    private

    # Return the process ID (pid) for an instance. 
    def get_mysqld_pid(instance)
      server = server_for_instance(instance)
      pidfile = server['pid-file']
      return nil unless File.exist?(pidfile)
      Integer(File.open(pidfile, &:readline).strip)
    end

 end
end

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
      s = all_servers.select do |s|
        if pid = get_mysqld_pid(s["instance"])
          mysqld_running?(pid)
        else
          false
        end
      end
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

    # See if a MySQL server with the given pid is running.
    def mysqld_running?(pid)
      pids = %x{ ps -e | grep mysqld}.split("\n").map { |row| row =~ /\s*(\d+)\s+/; $1.to_i}
      pids.include?(pid)
    end

    # Return the process ID (pid) for an instance.  This only consults the PID file.
    def get_mysqld_pid(instance)
      server = server_for_instance(instance)
      pidfile = server['pid-file']
      return nil unless File.exist?(pidfile)
      Integer(File.open(pidfile, &:readline).strip)
    end

 end
end

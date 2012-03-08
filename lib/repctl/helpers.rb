module Repctl
  module Helpers

    include Commands
    include Servers
    include Config

    def do_stop(instance)
      do_admin(instance, "shutdown")
    end

    def do_reset(instance)
      do_stop(instance)
      do_config(instance)
      do_start(instance)
      do_secure_accounts(instance)
    end

    def do_start_slave(instance)
      run_mysql_query(instance, "START SLAVE")
    end

    def do_stop_slave(instance)
      run_mysql_query(instance, "STOP SLAVE")
    end

    def do_restart(instance)
      do_admin(instance, "shutown")
      do_start(instance)
    end

    # Generate an array of hashes, one hash per fabric-wide instance.
    def repl_status(options = {})
      todos = options[:servers] || all_live_instances
      return [] unless todos.any?
      status_array = []
      todos.each do |i|
        coordinates = get_coordinates(i)
        next unless coordinates
        master_file = coordinates[:file]
        master_pos =  coordinates[:position]

        fields = {}
        fields[:instance] = i.to_s
        fields[:server] = "#{server_for_instance(i)['hostname']}:#{i}"
        fields[:generated_binlog] = "#{master_file}:#{master_pos}"
        if is_slave?(i)
          slave_status = get_slave_status(i)
          recv_file = slave_status["Master_Log_File"]
          recv_pos = slave_status["Read_Master_Log_Pos"]
          apply_file = slave_status["Relay_Master_Log_File"]
          apply_pos = slave_status["Exec_Master_Log_Pos"]
          lag = slave_status["Seconds_Behind_Master"]
          master_host = slave_status["Master_Host"]
          master_port = slave_status["Master_Port"]
          master_instance = instance_for(master_host, master_port)

          fields[:applied_binlog] = "#{apply_file}:#{apply_pos}"
          fields[:received_binlog] = "#{recv_file}:#{recv_pos}"
          fields[:master] = "#{master_host}:#{master_instance}"
          fields[:lag] = lag
        end
        status_array << fields
      end
      status_array
    end

    def formatted_status(options = {})
      output = []
      header = sprintf("%-5s%-27s%-27s%-27s%-8s",
        "inst", "master", "received", "applied", "lag")
      output << header.colorize(:green)
      todos = repl_status(options)
      todos.each do |server|
        instance = server[:instance]
        gen_binlog = server[:generated_binlog]
        if server[:master]
          server[:master].match(/.*:(\d*)$/)
          master_instance = $1
          recv_binlog = server[:received_binlog]
          app_binlog = server[:applied_binlog]
          lag = server[:lag]
          if lag == nil
            lag = "-"
          else
            lag = lag.to_s
          end
          format = "%1d%-4s%-27s%-27s%-27s%-8s"
          str = sprintf(format, instance, "(#{master_instance})",
            gen_binlog, recv_binlog, app_binlog, lag)
        else
          format = "%-5d%-26s"
          str = sprintf(format, instance, gen_binlog)
        end
        output << str.colorize(:yellow)
      end
      output
    end

    def do_add_slave(master, slave, dumpfile = DEFAULT_DUMPFILE)
      do_reset(slave)
      coordinates = do_dump(master, dumpfile)
      do_restore(slave, dumpfile)
      do_change_master(master, slave, coordinates)
      do_start_slave(slave)
      do_cluster_user(slave)
      do_repl_user(slave)
    end

    def do_repl_pair(master, slave)
      do_reset(master)
      do_reset(slave)
      do_cluster_user(master)
      do_repl_user(master)
      coordinates = get_coordinates(master)
      file = coordinates[:file]
      position = coordinates[:position]
      do_change_master(master, slave, :file => file, :position => position)
      do_start_slave(slave)
    end

    def do_repl_trio(master, slave1, slave2, options = {})
      if options[:reset]
        do_reset(master)
        do_reset(slave1)
        do_reset(slave2)
      else
        do_restart(master)
        do_restart(slave1)
        do_restart(slave2)
      end
      # Set up the replication accounts for all servers, in case we
      # decide to switch masters later.
      [master, slave1, slave2].each do |s|
        do_cluster_user(s)
        do_repl_user(s)
      end
      coordinates = get_coordinates(master)
      file = coordinates[:file]
      position = coordinates[:position]
      do_change_master(master, slave1, :file => file, :position => position)
      do_start_slave(slave1)
      do_change_master(master, slave2, :file => file, :position => position)
      do_start_slave(slave2)
    end
  end
end

require 'mysql2'
require 'fileutils'
require 'delegate'
require 'open3'

module Repctl

  class Client < DelegateClass(Mysql2::Client)
    include Servers

    @@clients = {}
    
    def initialize(instance, opts)
      @instance = instance
      server = server_for_instance(@instance)
      options = {
        :host => server['hostname'],
        :username => "root",
        :port => server['port'],
        :password => Config::ROOT_PASSWORD
      }
      options.delete(:password) if opts[:no_password]
      @client = Mysql2::Client.new(options)
      super(@client)
    end
    
    def self.open(instance, opts = {})
      timeout = opts[:timeout] || 10
      opts.delete(:timeout)
      begin
        instance = Integer(instance)
      rescue Mysql2::Error => e 
        puts "Instance value <#{instance}> is invalid."
      else
        timeout = Integer(timeout)
        while timeout >= 0
          begin
            @@clients[instance] ||= Client.new(instance, opts)
            # puts "Connected to instance #{instance}."
            break
          rescue Mysql2::Error => e
            puts "#{e.message}, retrying connection to instance #{instance}..."
            # puts e.backtrace
            sleep 1
            timeout -= 1
          end
        end    
      end
      @@clients[instance]
    end    
    
    def close
      @@clients[@instance] = nil
      @client.close
    end
    
    def reset
      @client.close
      @@clients[@instance] = nil
      Client.open(@instance)
    end
    
  end

  module Commands
    
    include FileUtils
    include Repctl::Config
    include Servers
        
    #
    # Public methods are:
    #
    #   do_secure_accounts
    #   do_start
    #   do_admin
    #   do_config
    #   do_crash
    #   do_change_master
    #   do_dump
    #   do_restore
    #   do_repl_user
    #   do_cluster_user
    #   do_create_widgets
    #   do_switch_master
    #   do_stop_slave
    #   get_coordinates
    #   get_mysqld_pid
    #   get_slave_status
    #   run_mysql_query
    #

    def do_secure_accounts(instance)
      client = Client.open(instance, :no_password => true)
      q1 = "UPDATE mysql.user SET Password = PASSWORD(\'#{ROOT_PASSWORD}\') where User = \'root\'"
      q2 = "UPDATE mysql.user SET Password = PASSWORD(\'#{ROOT_PASSWORD}\') where User = \'\'"
      # q3 = "CREATE USER \'root\'@\'%.#{REPLICATION_DOMAIN}\' IDENTIFIED BY \'#{ROOT_PASSWORD}\'"
      # For testing with clients whose DHCP assigned IP address is not in DNS.
      q3 = "CREATE USER \'root\'@\'%' IDENTIFIED BY \'#{ROOT_PASSWORD}\'"
      q4 = "GRANT ALL PRIVILEGES ON *.* to \'root\'@\'%\' WITH GRANT OPTION"
      q5 = "FLUSH PRIVILEGES"
      if client
        [q1, q2, q3, q4, q5].each do |query|
          puts query
          client.query(query)
        end
      end
    rescue Mysql2::Error => e
      puts e.message
    ensure
      client.close if client
    end

    def do_start(instance)
      pid = get_mysqld_pid(instance)
      if pid
        puts "Instance #{instance} with PID #{pid} is already running."
      else 
        pid = fork
        unless pid
          # We're in the child.
          puts "Starting instance #{instance} with PID #{Process.pid}."
          server = server_for_instance(instance)

          exec(["#{MYSQL_HOME}/bin/mysqld", "mysqld"], 
            "--defaults-file=#{server['defaults-file']}",
            "--datadir=#{server['datadir']}",
            "--port=#{server['port']}",
            "--server-id=#{server['server-id']}",
            "--innodb_data_home_dir=#{server['innodb_data_home_dir']}",
            "--innodb_log_group_home_dir=#{server['innodb_log_group_home_dir']}",
            "--relay-log=#{Socket.gethostname}-relay-bin",
            "--socket=#{server['socket']}",
            "--user=mysql")
        end
      end
    end
    
    def do_admin(instance, operation)
      server = server_for_instance(instance)

      cmd = "#{MYSQL_HOME}/bin/mysqladmin " +
        "--defaults-file=#{server['defaults-file']} " +
        "--user=root " +
        "--host=#{server['hostname']} " +
        "--port=#{server['port']} " +
        "--password=#{ROOT_PASSWORD} " +
        operation 
      
      pid = get_mysqld_pid(instance)
      if pid
        puts "Running #{operation} on instance #{instance} with pid #{pid}."
        run_cmd(cmd, false)
      else
        puts "Instance #{instance} is not running." 
      end
    end

    def do_config(instance)
      server = server_for_instance(instance)
      FileUtils.rm_rf(server['datadir'])
      cmd = "./scripts/mysql_install_db " +
        "--defaults-file=#{server['defaults-file']} " +
        "--datadir=#{server['datadir']} " +
        "--server-id=#{server['server-id']} " +
        "--innodb_data_home_dir=#{server['innodb_data_home_dir']} " +
        "--innodb_log_group_home_dir=#{server['innodb_log_group_home_dir']} " +
        "--relay-log=#{Socket.gethostname}-relay-bin" 
     %x( cd #{MYSQL_HOME} && #{cmd} )
    end

    #
    # Treat the instance as a slave and
    # process the output of "SHOW SLAVE STATUS".
    #
    def get_slave_status(instance)
      keys = [
        "Instance",
        "Error",
        "Slave_IO_State",
        "Slave_IO_Running",
        "Slave_SQL_Running",
        "Last_IO_Error",
        "Last_SQL_Error",
        "Seconds_Behind_Master",
        "Master_Log_File",
        "Read_Master_Log_Pos",
        "Relay_Master_Log_File",
        "Exec_Master_Log_Pos",
        "Relay_Log_File",
        "Relay_Log_Pos",
        "Master_Host",
        "Master_Port"
      ]
      results = {}
      status = do_slave_status(instance)
      keys.each do |k|
        results.merge!(k => status[k]) if (status[k] and status[k] != "")
      end
      results
    end

    def do_crash(instance) 
      pid = get_mysqld_pid(instance)
      puts "pid is #{pid}"
      if pid
        puts "Killing mysqld instance #{instance} with PID #{pid}"
        Process.kill("KILL", pid.to_i)
        while get_mysqld_pid(instance)
          puts "in looop"
          sleep 1
        end
        puts "MySQL server instance #{instance.to_i} has been killed."
      else
        puts "MySQL server instance #{instance.to_i} is not running."
      end
    end
       
    #
    # From http://dev.mysql.com/doc/refman/5.0/en/lock-tables.html:
    #  
    # For a filesystem snapshot of innodb, we find that setting
    # innodb_max_dirty_pages_pct to zero; doing a 'flush tables with
    # readlock'; and then waiting for the innodb state to reach 'Main thread
    # process no. \d+, id \d+, state: waiting for server activity' is
    # sufficient to quiesce innodb.
    #
    # You will also need to issue a slave stop if you're backing up a slave
    # whose relay logs are being written to its data directory.
    # 
    #
    # select @@innodb_max_dirty_pages_pct;
    # flush tables with read lock;
    # show master status; 
    # ...freeze filesystem; do backup...
    # set global innodb_max_dirty_pages_pct = 75;
    # 
    
    def do_change_master(master, slave, coordinates, opts = {})
      master_server = server_for_instance(master)
      raise "master_server is nil" unless master_server
          
      begin
        slave_connection = Client.open(slave)
        if slave_connection
          
          # Replication on the slave can't be running if we want to
          # execute CHANGE MASTER TO.  
          slave_connection.query("STOP SLAVE") rescue Mysql2::Error
          
          cmd = <<-EOT
CHANGE MASTER TO
  MASTER_HOST = \'#{master_server['hostname']}\',
  MASTER_PORT = #{master_server['port']},
  MASTER_USER = \'#{REPLICATION_USER}\',
  MASTER_PASSWORD = \'#{REPLICATION_PASSWORD}\',
  MASTER_LOG_FILE = \'#{coordinates[:file]}\',
  MASTER_LOG_POS = #{coordinates[:position]}
EOT
          puts "Executing: #{cmd}"
          slave_connection.query(cmd)
        else
          puts "do_change_master: Could not connnect to MySQL server."
        end
      rescue Mysql2::Error => e
          puts e.message
      ensure
        if slave_connection
          slave_connection.query("START SLAVE") if opts[:restart]
          slave_connection.close 
        end
      end
    end
        
    def do_dump(instance, dumpfile)
      server = server_for_instance(instance)
      coordinates = get_coordinates(instance) do
        cmd = "#{MYSQL_HOME}/bin/mysqldump " +
          "--defaults-file=#{server['defaults-file']} " +
          "--user=root " +
          "--password=#{ROOT_PASSWORD} " +
          "--socket=#{server['socket']} " +
          "--all-databases --lock-all-tables > #{DUMP_DIR}/#{dumpfile}"
        run_cmd(cmd, true)
      end
      coordinates
    end
    
    def do_restore(instance, dumpfile)
      server = server_for_instance(instance)

      # Assumes that the instance is running, but is not acting as a slave.
      cmd = "#{MYSQL_HOME}/bin/mysql " +
        "--defaults-file=#{server['defaults-file']} " +
        "--user=root " +
        "--password=#{ROOT_PASSWORD} " +
        "--socket=#{server['socket']} " +
        "< #{DUMP_DIR}/#{dumpfile}"
      run_cmd(cmd, true)
    end
          
    # Get the master coordinates from a MySQL instance. Optionally,
    # run a block while holding the READ LOCK.
    def get_coordinates(instance)
      instance ||= DEFAULT_MASTER
      locked = false
      client = Client.open(instance)
      if client
        client.query("FLUSH TABLES WITH READ LOCK")
        locked = true
        results = client.query("SHOW MASTER STATUS")
        row = results.first
        coordinates = if row
          {:file => row["File"], :position => row["Position"]}
        else
          {}
        end
        yield coordinates if block_given?
        # You could copy data from the master to the slave at this point
      end
      coordinates
    rescue Mysql2::Error => e
      puts e.message
      # puts e.backtrace
    ensure
      if client
        client.query("UNLOCK TABLES") if locked
        client.close
      end
      # coordinates
    end

    def run_mysql_query(instance, cmd)
      client = Client.open(instance)
      if client 
        results = client.query(cmd)
      else
        puts "Could not open connection to MySQL instance."
      end
      results
    rescue Mysql2::Error => e
      puts e.message
      puts e.backtrace
    ensure
      client.close if client
    end

    def do_repl_user(instance)
      hostname = "127.0.0.1"
      client = Client.open(instance)
      cmd = "DROP USER \'#{REPLICATION_USER}\'@\'#{hostname}\'"
      client.query(cmd) rescue Mysql2::Error
      
      if client
        # "CREATE USER \'#{REPLICATION_USER\'@'%.thirdmode.com' IDENTIFIED BY \'#{REPLICATION_PASSWORD}\'"
        # "GRANT REPLICATION SLAVE ON *.* TO \'#{REPLICATON_USER}\'@\'%.#{REPLICATION_DOMAIN}\'"
        cmd = "CREATE USER \'#{REPLICATION_USER}\'@\'#{hostname}\' IDENTIFIED BY \'#{REPLICATION_PASSWORD}\'"
        puts cmd
        client.query(cmd)
        cmd = "GRANT REPLICATION SLAVE ON *.* TO \'#{REPLICATION_USER}\'@\'#{hostname}\'"
        puts cmd
        client.query(cmd)
        client.query("FLUSH PRIVILEGES")
      else
        puts "Could not open connection to MySQL instance #{instance}."
      end
    rescue Mysql2::Error => e
      puts e.message
      puts e.backtrace
    ensure
      client.close if client
    end
    
    def do_cluster_user(instance)
      client = Client.open(instance)
     
      cmd = "DROP USER \'cluster\'@\'localhost\'"
      client.query(cmd) rescue Mysql2::Error
 
      cmd = "DROP USER \'cluster\'@\'%\'"
      client.query(cmd) rescue Mysql2::Error
      
      if client
        cmd = "CREATE USER \'cluster\'@\'localhost\' IDENTIFIED BY \'secret\'"
        client.query(cmd)
        cmd = "GRANT ALL PRIVILEGES ON *.* TO \'cluster\'@'\localhost\'"
        client.query(cmd)
        cmd = "CREATE USER \'cluster\'@\'%\' IDENTIFIED BY \'secret\'"
        client.query(cmd)
        cmd = "GRANT ALL PRIVILEGES ON *.* TO \'cluster\'@\'%\'"
        client.query(cmd)
      else
        puts "Could not open connection to MySQL instance #{instance}."
      end
    rescue Mysql2::Error => e
      puts e.message
      puts e.backtrace
    ensure
      client.close if client
    end
    
    # Create the 'widgets' database.
    def do_create_widgets(instance)
       client = Client.open(instance)
       if client
         client.query("drop database if exists widgets")
         client.query("create database widgets")
       else
         puts "Could not open connection to MySQL instance #{instance}."
       end
     rescue Mysql2::Error => e
       puts e.message
       puts e.backtrace
     ensure
       client.close if client
     end
     
    # 'master' is currently a slave that is to be the new master.
    # 'slaves' contains the list of slaves, one of these may be the
    # current master.
    def do_switch_master(master, slaves)
      master = master.to_i
      slaves = slaves.map(&:to_i)

      # Step 1. Make sure all slaves have completely processed their
      # Relay Log.
      slaves.each do |s|
        # This will also stop the slave threads.
        drain_relay_log(s) if is_slave?(s)
      end
      
      # Step 2. For the slave being promoted to master, issue STOP SLAVE
      # and RESET MASTER.  Get the coordinates of its binlog.
      promote_slave_to_master(master)
      coordinates = get_coordinates(master)

      # Step 3.  Change the master for the other slaves.
      slaves.each do |s|
        do_change_master(master, s, coordinates, :restart => true)
      end
    end

    private
    
     # This is an example template to create commands to issue queries.
     def template(instance)
       client = Client.open(instance)
       if client
         client.query("some SQL statement")
       else
         puts "Could not open connection to MySQL instance #{instance}."
       end
     rescue Mysql2::Error => e
       puts e.message
       puts e.backtrace
     ensure
       client.close if client
     end

    
    def is_master?(instance)
      get_slave_coordinates(instance).empty?
    end

    def is_slave?(instance)
        get_slave_status(instance).has_key?("Slave_IO_State")
    end
    
    def find_masters()
      masters = []
      all_servers.each do |s|
        masters << s if is_master?(s)
      end
      masters
    end

    def run_cmd(cmd, verbose)
      puts cmd if verbose
      cmd += " > /dev/null 2>&1" unless verbose
      output = %x[#{cmd}]
      puts output if verbose
      exit_code = $?.exitstatus
      if exit_code == 0
        puts "OK"
      else 
        "FAIL: exit code is #{exit_code}"
      end
    end

    def stop_slave_io_thread(instance)
      client = Client.open(instance)
      if client 
        client.query("STOP SLAVE IO_THREAD")
      end
    ensure
      client.close if client
    end

    def promote_slave_to_master(instance)
      client = Client.open(instance)
      if client 
        client.query("STOP SLAVE")
        client.query("RESET MASTER")
      end
    ensure
      client.close if client
    end

    def get_slave_coordinates(instance)
      client = Client.open(instance)
      if client
        results = client.query("SHOW SLAVE STATUS")
        row = results.first
        if row
          {:file => row["Master_Log_File"], :position => row["Read_Master_Log_Pos"]}
        else
          {}
        end
      end
    ensure
      client.close if client
    end

    # unused
    def start_slave_io_thread(instance)
      client = Client.open(instance)
      if client 
        client.query("START SLAVE IO_THREAD")
      end
    ensure
      client.close if client
    end

    def drain_relay_log(instance)
      done = false
      stop_slave_io_thread(instance)
      client = Client.open(instance)
      if client
        
        # If the slave 'sql_thread' is not running, this will loop forever.
        while !done
          results = client.query("SHOW PROCESSLIST")
          results.each do |row| 
            if  row["State"] =~ /Slave has read all relay log/
              done = true
              puts "Slave has read all relay log."
              break
            end
          end
          puts "Waiting for slave to read relay log." unless done
        end
        client.query("STOP SLAVE")
      else
        puts "Could not open connection to instance #{instance}."
      end
    ensure
      client.close if client
    end

    #
    # Get the status of replication for the master and all slaves.
    # Return an array of hashes, each hash has the form:
    # {:instance => <instance id>, :error => <errrmsg>, 
    #  :master_file => <binlog-file-name>, :master_position => <binlog-position>,
    #  :slave_file => <binlog-file-name>, :slave_position => <binlog-position>}
    #
    def do_slave_status(instance)
      instance ||= DEFAULT_MASTER
      locked = false
      client = Client.open(instance, :timeout => 5)
      if client
        client.query("FLUSH TABLES WITH READ LOCK")
        locked = true
        results = client.query("SHOW SLAVE STATUS")
        if results.first
          results.first.merge("Instance" => instance, "Error" => "Success")
        else
          {"Instance" => instance, "Error" => "MySQL server is not a slave."}
        end
      else
        {"Instance" => instance, "Error" => "Could not connect to MySQL server."}
      end
    rescue Mysql2::Error => e
      {:instance => instance, "Error" => e.message}
    ensure
      if client
        client.query("UNLOCK TABLES") if locked
        client.close
      end
    end


    
  end
end

class RunExamples
  include Repctl::Commands
  
  def runtest
      
    switch_master_to(3)
=begin
    (1..4).each {|i| ensure_running(i)}
    puts get_master_coordinates(1)
    (2..4).each {|i| puts get_slave_coordinates(i)}
    (1..4).each {|i| puts is_master?(i) }
    puts "Master is #{find_master}"
    drain_relay_log(2)
    # sleep(10)
    # (1..4).each {|i| crash(i)}
=end
  end
end




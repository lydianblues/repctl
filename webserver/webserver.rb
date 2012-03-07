require 'sinatra'
require 'repctl'

module Repctl
  module Webserver
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
        puts server_for_instance(i)
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
  end
end

include Repctl::Config
include Repctl::Commands
include Repctl::Servers
include Repctl::Webserver

get '/' do
  erb :main
end

post '/switch_master' do 
  erb :switch_master, :layout => false
end

get '/status' do
  puts "status called"  
  @status_array = repl_status
  @timestamp = Time.now.strftime("%I:%M:%S %p")
  erb :status, :layout => false
end

__END__

@@ layout
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <title>MySQL Replication Manager</title>
  <script type="text/javascript" src="http://ajax.googleapis.com/ajax/libs/jquery/1.7.1/jquery.min.js">
  </script>

  <script type="text/javascript">
    /* Fix this.  It should not be in the global namespace. */
    function getUpdate() { 
      $('#status-table').load('/status');
      setTimeout(getUpdate, 3000);
    }
    $(document).ready(function() { 
       getUpdate();

       $('#switch-master').submit(function() { 
         $.post('/switch_master', $(this).serialize(), function(data) { 
           alert(data);
         });
         return false;
       });

    });
  </script>

  <style type="text/css">
    #banner { 
      text-align: center;
    }
    table.gridtable {
      font-family: verdana,arial,sans-serif;
      font-size:11px;
      color:#333333;
      border-width: 1px;
      border-color: #666666;
      border-collapse: collapse;
    }
    table.gridtable th {
      border-width: 1px;
      padding: 8px;
      border-style: solid;
      border-color: #666666;
      background-color: #dedede;
    }
    table.gridtable td {
      border-width: 1px;
      padding: 8px;
      border-style: solid;
      border-color: #666666;
      background-color: #ffffff;
    }
  </style>
</head>

<body>
  <%= yield %>
</body>
</html>

@@ main
  <header id="banner">
    <h1>MySQL Replication Manager</h1>
  </header>

  <section>
    <header>
      <h2>Status Summary</h2>
    </header>
    <div id="status-table">
    </div>
  </section>

  <section>
    <header><h2>Switch Master</h2></header>
      <form id="switch-master" action="/switch_master" method="post">
        <p>Master: <input type="text" name="post[master]" size="20"/></p>
        <p>Slaves: <input type="text" name="post[slaves]" size="20"/></p>
        <input type="submit" value="Switch Master">
      </form>
  </section>

@@ status
  <div>
     Status as of <%= @timestamp %>
  </div>
  <table class="gridtable">
    <tr>
      <th>instance</th>
      <th>master</th>
      <th>generated binlog</th>
      <th>received binlog</th>
      <th>applied binlog</th>
      <th>lag (secs)</th>
    </tr>
    <% @status_array.each do |s| %>
      <tr>
        <td><%= s[:server] %></td>
        <td><%= s[:master] %></td>
        <td><%= s[:generated_binlog] %></td>
        <td><%= s[:received_binlog] %></td>
        <td><%= s[:applied_binlog] %></td>
        <td><%= s[:lag] %></td>
      </tr>  
    <% end %>
  </table>

@@ switch_master
  <div>Hello from switch master</div>


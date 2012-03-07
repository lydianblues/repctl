require 'sinatra'
require 'repctl'

include Repctl::Config
include Repctl::Commands
include Repctl::Servers
include Repctl::Utils
include Repctl::Color

get '/' do
  erb :main
end

post '/switch_master' do 
  erb :switch_master, :layout => false
end

get '/status' do
  @status_array = repl_status
  @timestamp = Time.now.strftime("%I:%M:%S %p")
  if request.accept == ['text/plain']
    formatted_status.join("\n") + "\n"
  else
    erb :status , :layout => !request.xhr?
  end
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


require 'sinatra'
require 'repctl'

include Repctl::Config
include Repctl::Commands
include Repctl::Servers
include Repctl::Utils
include Repctl::Color

def time
  start = Time.now
  yield
  Time.now - start
end

helpers do
  def img(name)
    "<img src='images/#{ name}' alt='#{ name}' />"
  end

  def master_slave_params(params)
    param_error = false
    @error_message = nil
    if params.nil? || params["master"] == "" || params["master"].nil? ||
      params["slaves"] == nil || params["slaves"] == ""
      @error_message = "parameters missing"
    else
      begin
        master = params["master"].to_i
        slaves = params["slaves"].split("\s").map(&:to_i)
      rescue Exception => e
        @error_message = "invalid format for parameters"
      else
        if master == 0 || slaves.include?(0)
          @error_message = "0 can not be an instance"
        elsif slaves.include?(master)
          @error_message = "master can not also be a slave"
        elsif slaves.empty?
          @error_message = "no slaves are specified"
        end
      end
    end
    [@error_message, master, slaves]
  end
end
      
get '/' do
  erb :main
end

# curl deimos:9393/switch_master --header "Accept: text/plain" \
#   -d switch[slaves]="2 1 4" -d switch[master]=3
post '/switch_master' do
  @message, master, slaves = master_slave_params(params["switch"])
  if @message
    @success = false
  else
    secs = time do
      do_switch_master(master, slaves)
    end
    @message = "Switch master processed in #{secs} secs."
    @success = true
  end
  if request.accept == ['text/plain']
    if @success
      "#{@message}\n".colorize(:green)
    else
      "#{@message}\n".colorize(:red)
    end
  else
    erb :operation_complete, :layout => !request.xhr?
  end
end

post '/repl_trio' do
  @message, master, slaves = master_slave_params(params["repl_trio"])
  if @message
    @success = false
  else
    secs = time do
      sleep 1
    end
    @message = "Create replication trio with master #{master} and slaves #{slaves} in #{secs} secs."
    @success = true
  end
  if request.accept == ['text/plain']
    if @success
      "#{@message}\n".colorize(:green)
    else
      "#{@message}\n".colorize(:red)
    end
  else
    erb :operation_complete, :layout => !request.xhr?
  end
end

# curl deimos:9393/status --header "Accept: text/plain"
get '/status' do
  if request.accept == ['text/plain']
    formatted_status.join("\n") + "\n"
  else
    @timestamp = Time.now.strftime("%I:%M:%S %p")
    @status_array = repl_status
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
         $('.spinner').show();
         $.post('/switch_master', $(this).serialize(), function(data) { 
           $('.spinner').hide();
           $("#switch-master-result").html(data)
         });
         return false;
       });

       $('#repl-trio').submit(function() { 
         $('#repl-trio-spinner').show();
         $.post('/repl_trio', $(this).serialize(), function(data) { 
           $('#repl-trio-spinner').hide();
           $("#repl-trio-result").html(data)
         });
         return false;
       });

    });
  </script>

  <style type="text/css">
    #banner { 
      text-align: center;
    }
    .spinner { 
      display:none;
    }
    .success { 
      color: green;
    }
    .failure { 
      color: red;
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
        <p>Master: <input type="text" name="switch[master]" size="20"/></p>
        <p>Slaves: <input type="text" name="switch[slaves]" size="20"/></p>
        <input type="submit" value="Switch Master">
      </form>
      <div>
        <div style="float:left;" id="switch-master-result"></div>
        <img style="float:left;" class='spinner' id="switch-master-spinner" src='images/wait30.gif' alt='spinner'></img>
      </div>
  </section>

  <section>
    <header><h2>Set up Replication Trio from Scratch</h2></header>
      <form id="repl-trio" action="/repl_trio" method="post">
        <p>Master: <input type="text" name="repl_trio[master]" size="20"/></p>
        <p>Slaves: <input type="text" name="repl_trio[slaves]" size="20"/></p>
        <input type="submit" value="Create Repliction Trio">
      </form>
      <div>
        <div style="float:left;" id="repl-trio-result"></div>
        <img style="float:left;" class="spinner" id='repl-trio-spinner' src='images/wait30.gif' alt='spinner'></img>
      </div>
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

@@ operation_complete
  <% if @success %>
    <span class="success"><%= @message %></span>
  <% else %>
    <span class="failure"><%= @message %></span>
  <% end %>

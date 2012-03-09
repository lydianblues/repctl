/* Fix this.  It should not be in the global namespace. */
function getUpdate() { 
  $('#status-table').load('/status');
  setTimeout(getUpdate, 3000);
}

$(document).ready(function() { 
   getUpdate();

   $('#switch-master').submit(function() { 
     $('#switch-master-result').html("")
     $('.spinner').show();
     $.post('/switch_master', $(this).serialize(), function(data) { 
       $('.spinner').hide();
       $('#switch-master-result').html(data)
     });
     return false;
   });

   $('#repl-trio').submit(function() { 
     $('#repl-trio-result').html("")
     $('#repl-trio-spinner').show();
     $.post('/repl_trio', $(this).serialize(), function(data) { 
       $('#repl-trio-spinner').hide();
       $('#repl-trio-result').html(data)
     });
     return false;
   });

   $('#add-slave').submit(function() { 
     $('#add-slave-result').html("")
     $('#add-slave-spinner').show();
     $.post('/add_slave', $(this).serialize(), function(data) { 
       $('#add-slave-spinner').hide();
       $('#add-slave-result').html(data)
     });
     return false;
   });

   $('#remove-slave').submit(function() { 
     $('#remove-slave-result').html("")
     $('#remove-slave-spinner').show();
     $.post('/remove_slave', $(this).serialize(), function(data) { 
       $('#remove-slave-spinner').hide();
       $('#remove-slave-result').html(data)
     });
     return false;
   });

});


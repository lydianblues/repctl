# Repctl - Manage Replication among a set of SQL Servers 

 `repctl` is a utility to configure, reconfigure, start, stop, crash, generate
 workloads, dump, restore, benchmark, and monitor a set of SQL servers for
 development environments.  Replication relationships can be set up among server
 instances with a single command. While running a load generator or benchmark,
 the replication status, including current lag, can be seen in a continuously
 updated display. A slave can be added to an existing server that already has
 data.

The `repctl` gem includes a _Thor_ script that makes all the `repctl`
functionality available at the command line.

## Limitations

Currently only MySQL is supported but PostgresSQL will soon be added.  All the
server instances must run on a single host.  This restriction may be soon lifted
as well.

## Installation

You will need to have a local installation installation of MySQL.  You do not
need to do anything to configure the installation.  For example, if you compile
MySQL from source, then do `make install`, then you are done!  No MySQL
post-installation steps are necessary.  All post-install configuration is
handled by `repctl`.

You will need to set an environment variable `REPCTL_CONFIG_DIR` in your shell
so that `repctl` can find the configuration files it needs.  

The top

== Available Commands

    tethys:repctl mbs$ thor list
    mysql
    -----
    thor mysql:change_master MASTER SLAVE FILE POSITION  # Execute CHANGE MASTER TO on the SLAVE.
    thor mysql:cluster_user INSTANCE                     # Create the cluster user account on a MySQL instance.
    thor mysql:config INSTANCE                           # Initialize the data directory for a new instance.
    thor mysql:config_all                                # Initialize the data directories for all instances.           
    thor mysql:crash INSTANCE                            # Crash a running MySQL server.
    thor mysql:dump INSTANCE [DUMPFILE]                  # Dump all databases after FLUSH TABLES WITH READ LOCK             
    thor mysql:repl_user INSTANCE                        # Create the replication user account on a MySQL insta...
    thor mysql:reset INSTANCE                            # Remove database and restart MySQL server.
    thor mysql:reset_all                                 # Remove all databases and restart MySQL instances.          
    thor mysql:restore INSTANCE [DUMPFILE]               # Restore INSTANCE from a 'mysqldump' file DUMPFILE.
    thor mysql:start_slave SLAVE                         # Issue START SLAVE on the SLAVE MySQL instance.
    thor mysql:status                                    # Show the status of replication.
    thor mysql:stop INSTANCE                             # Stop a running MySQL server instance.
    thor mysql:stop_all                                  # Stop all the MySQL servers.

    setup
    -----
    thor setup:add_slave MASTER SLAVE  # Master has some data that is used to initialize the slave.
    thor setup:repl_pair MASTER SLAVE  # Set up a single master/slave replication pair from the very beginning.

    utils
    -----
    thor utils:bench [INSTANCE] [PROPS]                  # Run the Tungsten Bristlecone benchmarker. The INSTAN...
    thor utils:create_db [INSTANCE] [DBNAME]             #  "Create a database on a MySQL instance. INSTANCE de...
    thor utils:create_tbl [INSTANCE] [DBNAME] [TBLNAME]  #  Create a database table. INSTANCE defaults to DEFAU...
    thor utils:gen_rows [INSTANCE], [DBNAME], [TBLNAME]  #  Add rows to a table that was created by "utils:crea...

== Configuring Simple Repctl

This tool needs some configuration before you can use it.

You should have an valid MySQL installation and the Thor gem installed.  Your existing MySQL server will not be affected by the +repctl+ script.  However, binaries from this installation will be reused.  In the +config.rb+ file set the constants:

* MYSQL_HOME -- the location of the local MySQL installation
* DATA_HOME -- the location of the directory where per-MySQL server data directories are created.
* DUMP_DIR -- the location where you want dump files to be stored
* RELAY_LOG -- adjust this according to your hostname

Next, define the potential instances you want to create.  Edit the <tt>servers.yml</tt> file as appropriate.

Finally, edit the existing <tt>my*.cnf*</tt> files to at least have the correct <tt>datadir</tt> defined.

== Using Simple Repctl

You are now ready to rock.  Run <tt>thor mysql:start_all</tt> to start up all the servers listed in your +servers.yml+ file. Instead or subsequently, you can run <tt>thor setup:repl_pair 1 2</tt> to reset everything and create a master/slave replication pair. Start up some load to the MySQL master (at socket +/tmp/mysql1.sock+, by default), then watch the replication status change by running <tt>thor mysql:status -s 1 2 -c 5</tt> to see a continuous update of the status, updated every 5 seconds.  Add a new slave using instance +3+, which may or may not be running and may or may not have its data directory initialized, by running <tt>thor setup:add_slave 1 3</tt>.  This does a dump on the master and a restore on the slave and restarts replication using the proper replication coordinates.


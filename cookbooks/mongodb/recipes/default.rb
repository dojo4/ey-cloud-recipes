#
# Cookbook Name:: mongodb
# Recipe:: default
#

# NOTE: Be sure to edit files/default/mongodb-slave.conf
# If you plan on using replication with a database slave

if ['db_master','db_slave','solo'].include?(node[:instance_role])
  package "dev-db/mongodb-bin" do
    action :install
  end
  
  directory '/db/mongodb/master-data' do
    owner 'mongodb'
    group 'mongodb'
    mode  '0755'
    action :create
    recursive true
  end

  directory '/db/mongodb/slave-data' do
    owner 'mongodb'
    group 'mongodb'
    mode  '0755'
    action :create
    recursive true
  end
  
  directory '/var/log/mongodb' do
    owner 'mongodb'
    group 'mongodb'
    mode '0755'
    action :create
    recursive true
  end
  
  directory '/var/run/mongodb' do
    owner 'mongodb'
    group 'mongodb'
    mode '0755'
    action :create
    recursive true
  end  
  
  remote_file "/etc/logrotate.d/mongodb" do
    owner "root"
    group "root"
    mode 0755
    source "mongodb.logrotate"
    backup false
    action :create
  end
  
  remote_file "/etc/conf.d/mongodb" do
    owner "root"
    group "root"
    mode 0755
    source "mongodb-master.conf" if node[:instance_role] == 'db_master'
    source "mongodb-slave.conf" if node[:instance_role] == 'db_slave'    
    backup false
    action :create
  end  
  
  execute "enable-mongodb" do
    command "rc-update add mongodb default"
    action :run
  end  
  
  execute "start-mongodb" do
    command "/etc/init.d/mongodb restart"
    action :run
    not_if "/etc/init.d/mongodb status | grep started"
  end  
  
  node[:applications].each do |app_name,data|
    user = node[:users].first
    db_name = "#{app_name}_#{node[:environment][:framework_env]}"
    
    execute "create-mongodb-root-user" do
      command "/usr/bin/mongo admin --eval 'db.addUser(\"root\",\"#{user[:password]}\")'"
      action :run
      not_if "/usr/bin/mongo admin --eval 'db.auth(\"root\",\"#{user[:password]}\")' | grep ^1$"
    end    
    
    execute "create-mongodb-replication-user" do
      command "/usr/bin/mongo admin --eval 'db.auth(\"root\",\"#{user[:password]}\"); db.getMongo().getDB(\"local\").addUser(\"repl\",\"#{user[:password]}\")'"      
      action :run
      not_if "/usr/bin/mongo local --eval 'db.auth(\"repl\",\"#{user[:password]}\")' | grep ^1$"      
    end

    execute "create-mongodb-application-users" do
      command "/usr/bin/mongo admin --eval 'db.auth(\"root\",\"#{user[:password]}\"); db.getMongo().getDB(\"#{db_name}\").addUser(\"#{user[:username]}\",\"#{user[:password]}\")'"      
      action :run
      not_if "/usr/bin/mongo #{db_name} --eval 'db.auth(\"#{user[:username]}\",\"#{user[:password]}\")' | grep ^1$"
    end    
  end
end

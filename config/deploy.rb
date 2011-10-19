require 'rubygems'
require 'highline'

default_run_options[:pty] = true

set :application, "capibuntu"
set :repository,  "git@github.com:jalvarezsamayoa/capibuntu.git"

set :user, "ubuntu"
set :password, "ubuntu"

set :deploy_to, "/home/#{user}"

set :local_home, "/home/javier"
set :remote_home, "/home/#{user}"

set :scm, :git
# Or: `accurev`, `bzr`, `cvs`, `darcs`, `git`, `mercurial`, `perforce`, `subversion` or `none`

set :server_host, "168.168.2.6"

role :web, "bfvm1"                          # Your HTTP server, Apache/etc
role :app, server_host                          # This may be the same as your `Web` server
role :db,  server_host, :primary => true # This is where Rails migrations will run

namespace :capibuntu do

  task :uname, :roles =>:web do
    run "uname -a"
  end

  namespace :server do
    desc "Run system updates"
    task :update, :roles => :web, :except => { :no_release => true } do
      sudo "apt-get update"
      sudo "apt-get upgrade -y"
    end
  end
  
  namespace :setup do    

    desc "Configure ssh connection without login"
    task :ssh, :roles => :web, :except => { :no_release => true } do
      public_key = File.open("#{local_home}/.ssh/id_rsa.pub","r")     
      run "cd #{remote_home} && mkdir -p .ssh"
      put public_key.read, "#{remote_home}/.ssh/authorized_keys"
      put public_key.read, "#{remote_home}/.ssh/authorized_keys2"      
      run "chmod 700 #{remote_home}/.ssh"
      run "chmod 640 #{remote_home}/.ssh/authorized_keys2"      
    end
 
    
  end
end



# if you're still using the script/reaper helper you will need
# these http://github.com/rails/irs_process_scripts

# If you are using Passenger mod_rails uncomment this:
# namespace :deploy do
#   task :start do ; end
#   task :stop do ; end
#   task :restart, :roles => :app, :except => { :no_release => true } do
#     run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
#   end
# end

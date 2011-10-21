require 'rubygems'
require 'highline'

$:.unshift(File.expand_path('./lib', ENV['rvm_path']))
require 'rvm/capistrano'
set :rvm_ruby_string, '1.9.2'

set :rvm_bin_path, "/usr/local/rvm/bin"

default_run_options[:pty] = true

set :application, "capibuntu"
set :repository,  "git@github.com:jalvarezsamayoa/capibuntu.git"

set :user, "ubuntu"
set :password, "ubuntu"


set :deploy_to, "/home/#{user}"

set :local_home, "/home/javier"
set :remote_home, "/home/#{user}"

set :scm, :git

set :server_host, "192.168.2.9"

role :app, server_host                          # This may be the same as your `Web` server


# Forces a quiet install for particularly annoying packages requiring complex input
def apt_quiet_install(packages)
  apt_get = "DEBCONF_TERSE='yes' DEBIAN_PRIORITY='critical' DEBIAN_FRONTEND=noninteractive apt-get"
  sudo "#{apt_get} -qyu --force-yes install #{packages}"
end

namespace :capibuntu do

  task :uname, :roles =>:app do
    run "uname -a"
  end

  namespace :server do
    desc "Run system updates"
    task :update, :roles => :app, :except => { :no_release => true } do
      sudo "apt-get update"
      sudo "apt-get upgrade -y"
    end

    desc "Configure ssh connection without login"
    task :config_ssh, :roles => :app, :except => { :no_release => true } do
      private_key = File.open("#{local_home}/.ssh/id_rsa","r")
      public_key = File.open("#{local_home}/.ssh/id_rsa.pub","r")
      run "cd #{remote_home} && mkdir -p .ssh"
      put public_key.read, "#{remote_home}/.ssh/authorized_keys"
      put public_key.read, "#{remote_home}/.ssh/authorized_keys2"
      run "chmod 700 #{remote_home}/.ssh"
      run "chmod 640 #{remote_home}/.ssh/authorized_keys2"

      put private_key.read, "#{remote_home}/.ssh/id_rsa"
      put public_key.read, "#{remote_home}/.ssh/id_rsa.pub"

      sudo "chmod 600 ~/.ssh/id_rsa"
      sudo "chmod 600 ~/.ssh/id_rsa.pub"

    end

  end

  namespace :setup do


    task :apache2, :roles => :app, :except => { :no_release => true } do
      sudo "apt-get install apache2 apache2.2-common apache2-mpm-prefork apache2-utils libexpat1 ssl-cert -y"
    end

    task :php5, :roles => :app, :except => { :no_release => true } do
      sudo "apt-get install libapache2-mod-php5 php5 php5-common php5-curl php5-dev php5-gd php5-imagick php5-mcrypt php5-memcache php5-mhash php5-mysql php5-pspell php5-snmp php5-sqlite php5-xmlrpc php5-xsl -y"
      sudo "sudo /etc/init.d/apache2 reload"
    end

    task :ruby, :roles => :app, :except => { :no_release => true } do
      # install base ruby 1.8.7
      sudo "apt-get install ruby1.8-dev ruby1.8 ri1.8 rdoc1.8 irb1.8 libreadline-ruby1.8 libruby1.8 libopenssl-ruby sqlite3 libsqlite3-ruby1.8 -y"
      sudo "ln -sf /usr/bin/ruby1.8 /usr/bin/ruby"
      sudo "ln -sf /usr/bin/ri1.8 /usr/bin/ri"
      sudo "ln -sf /usr/bin/rdoc1.8 /usr/bin/rdoc"
      sudo "ln -sf /usr/bin/irb1.8 /usr/bin/irb"
    end

    task :emacs, :roles => :app, :except => { :no_release => true } do
      sudo "apt-get install emacs emacs-goodies-el -y"
    end

    task :rvm, :roles => :app, :except => { :no_release => true } do
      sudo "apt-get install curl git-core -y"
      sudo "apt-get install build-essential bison openssl libreadline6 libreadline6-dev curl git-core zlib1g zlib1g-dev libssl-dev libyaml-dev libsqlite3-0 libsqlite3-dev sqlite3 libxml2-dev libxslt-dev autoconf libc6-dev ncurses-dev -y"

      #install rvm
      put "#!/bin/bash\n bash < <(curl -s https://raw.github.com/wayneeseguin/rvm/master/binscripts/rvm-installer )", "#{remote_home}/rvm_install.sh"
      run "cd #{remote_home} && chmod +x rvm_install.sh"
      sudo "#{remote_home}/rvm_install.sh"

      #add default user to rvm group
      sudo "adduser #{user} rvm"
      sudo "adduser www-data rvm"
    end

    task :ruby192, :roles => :app, :except => { :no_release => true } do
      # requires rvm to be installed
      run "/usr/local/rvm/bin/rvm install 1.9.2"
    end

    task :ruby_config, :roles => :app, :excpet => { :no_release => true} do
      run "/usr/local/rvm/bin/rvm use 1.9.2- --default"
      run "/usr/local/rvm/bin/rvm wrapper ruby-1.9.2-p290"
    end

    desc "Install Passenger"
    task :passenger, :roles => :app, :except => { :no_release => true } do
      # requires apache2, rvm, ruby192 to be installed
      sudo "apt-get install libcurl4-openssl-dev apache2-prefork-dev libapr1-dev libaprutil1-dev -y"
      run "gem install bundler"
      run "gem install passenger"

      input = ''
      run "rvmsudo passenger-install-apache2-module" do |ch,stream,out|
        next if out.chomp == input.chomp || out.chomp == ''
        print out
        ch.send_data(input = $stdin.gets) if out =~ /(Enter|ENTER|password)/
      end
    end

    desc "Configure Passenger"
    task :config_passenger, :roles => :app do
      passenger_config =<<-EOF
   LoadModule passenger_module /usr/local/rvm/gems/ruby-1.9.2-p290/gems/passenger-3.0.9/ext/apache2/mod_passenger.so
   PassengerRoot /usr/local/rvm/gems/ruby-1.9.2-p290/gems/passenger-3.0.9
   PassengerRuby /usr/local/rvm/wrappers/ruby-1.9.2-p290/ruby
EOF
      put passenger_config, "/tmp/passenger"
      sudo "mv /tmp/passenger /etc/apache2/conf.d/passenger"
      sudo "service apache2 restart"
    end


    desc "Install ImageMagick"
    task :imagemagick, :roles => :app do
      sudo "apt-get install libxml2-dev libmagick9-dev imagemagick -y"
    end

    desc "Install MySQL"
    task :mysql, :roles => :app do
      apt_quiet_install('mysql-server mysql-client libmysql-ruby libmysql-ruby1.8 libmysqlclient15-dev')
    end

    desc "Install PostgreSQL"
    task :postgres, :roles => :app do
      sudo "apt-get install postgresql libpgsql-ruby -y"
    end

    desc "Install SQLite3"
    task :sqlite3, :roles => :app do
      sudo "apt-get install sqlite3 libsqlite3-ruby -y"
    end

    task :install, :roles => :app, :except => { :no_release => true } do
      apache2
      # php5
      ruby
      # emacs
      rvm
      ruby192
      ruby_config
      passenger
      config_passenger
      mysql
    end

  end


end

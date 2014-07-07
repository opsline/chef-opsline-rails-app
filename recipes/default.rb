class Chef::Recipe
  include Opsline::RailsApp::Helpers
end

# install daemontools
package 'daemontools' do
  action :install
end

# create owner if does not exist
user node['opsline-rails-app']['owner'] do
  action :create
  comment "Rails User"
  supports :manage_home => true
  home "/home/#{node['opsline-rails-app']['owner']}"
  shell '/bin/bash'
  not_if "id #{node['opsline-rails-app']['owner']} >/dev/null 2>&1"
end

if node['opsline-rails-app']['ruby']['provider'] == 'rbenv'
  include_recipe 'ruby_build'

  node.default['rbenv']['user_installs'] = [
    {'user' => node['opsline-rails-app']['owner']}
  ]
  include_recipe 'rbenv::user_install'

  rbenv_ruby "ruby for #{node['opsline-rails-app']['owner']}" do
    definition node['opsline-rails-app']['ruby']['version']
    user node['opsline-rails-app']['owner']
  end
  rbenv_global node['opsline-rails-app']['ruby']['version'] do
    rbenv_version node['opsline-rails-app']['ruby']['version']
    user node['opsline-rails-app']['owner']
  end
  node['opsline-rails-app']['ruby']['gems'].each do |gem_name|
    rbenv_gem "#{gem_name} for #{node['opsline-rails-app']['owner']}" do
      package_name gem_name
      rbenv_version node['opsline-rails-app']['ruby']['version']
      user node['opsline-rails-app']['owner']
    end
  end
end

directory node['opsline-rails-app']['apps_root'] do
  action :create
  owner node['opsline-rails-app']['owner']
  group node['opsline-rails-app']['owner']
  mode 0755
end

# install all configured rails apps
node['opsline-rails-app']['apps'].each do |app_id|

  app_data = data_bag_item(node['opsline-rails-app']['databag'], app_id)

  # get app name
  if app_data.has_key?('name')
    app_name = app_data['name']
  else
    app_name = app_id
  end

  # skip non-rails apps
  next unless app_data['type'] == 'rails'

  # set default parameters if not provided
  unless app_data.has_key?('deploy_to')
    app_data['deploy_to'] = "/#{node['opsline-rails-app']['apps_root']}/#{app_name}"
  end
  unless app_data.has_key?('artifact_location')
    app_data['artifact_location'] = "s3://s3.amazonaws.com/#{node['opsline-rails-app']['s3_bucket']}/#{app_name}"
  end
  unless app_data.has_key?('package_type')
    app_data['package_type'] = 'tar.gz'
  end
  unless app_data.has_key?('container')
    app_data['container'] = 'unicorn'
  end
  if app_data.has_key?('container_parameters')
    container_parameters = get_env_value(app_data['container_parameters'])
  else
    container_parameters = {}
  end
  artifact_version = get_env_value(app_data['version'])

  # create app directory
  directory app_data['deploy_to'] do
    action :create
    owner node['opsline-rails-app']['owner']
    group node['opsline-rails-app']['owner']
    mode 0755
  end

  # environment variables hash
  env_dict = {}
  env_dict['RACK_ENV'] = node.chef_environment
  env_dict['RAILS_ENV'] = node.chef_environment
  env_dict['HOME'] = "/home/#{node['opsline-rails-app']['owner']}"
  env_dict['PATH'] = "/home/#{node['opsline-rails-app']['owner']}/.rbenv/shims:/home/#{node['opsline-rails-app']['owner']}/.rbenv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

  # merge environment from data bag (if there)
  if app_data.has_key?('environment')
    env_dict.merge!(get_env_value(app_data['environment']))
  end

  # create environment variables and directory
  template "#{app_data['deploy_to']}/environment" do
    action :create
    source "environment.erb"
    owner node['opsline-rails-app']['owner']
    group node['opsline-rails-app']['owner']
    mode 0644
    variables({ :env => env_dict })
  end
  
  # install pre-requisite packages
  if app_data.has_key?('packages')
    app_data['packages'].each do |pkg_name|
      package pkg_name do
        action :install
      end
    end
  end



  # deploy artifact
  artifact_deploy app_name do
    version artifact_version
    artifact_location "#{app_data['artifact_location']}/#{app_name}-#{artifact_version}.#{app_data['package_type']}"
    deploy_to app_data['deploy_to']
    owner node['opsline-rails-app']['owner']
    group node['opsline-rails-app']['owner']
    environment env_dict
    shared_directories %w{ bundle config log pids sockets system }
    symlinks({
      'log' => 'log'
    })
    action :deploy
    keep 3
    force false
    
    # remove log directory before linking
    before_symlink Proc.new {
      directory "#{app_data['deploy_to']}/releases/#{artifact_version}/log" do
        action :delete
        recursive true
      end
    }
  
    # before deployment proc
    # before_deploy Proc.new {
      # service app_name do
        # provider Chef::Provider::Service::Upstart
        # action :stop
      # end
    # }
  
    # configure proc
    configure Proc.new {

      service app_name do
        provider Chef::Provider::Service::Upstart
        action :nothing
      end
      
      if app_data['container'] == 'unicorn'
        # get container parameters
        unless container_parameters.has_key?('timeout')
          container_parameters['timeout'] = node['opsline-rails-app']['unicorn']['timeout']
        end
        unless container_parameters.has_key?('worker_processes')
          container_parameters['worker_processes'] = node['opsline-rails-app']['unicorn']['worker_processes']
        end
        
        unicorn_config = "#{app_data['deploy_to']}/shared/config/unicorn.rb"
        template unicorn_config do
          source 'unicorn.rb.erb'
          cookbook 'opsline-rails-app'
          owner node['opsline-rails-app']['owner']
          group node['opsline-rails-app']['owner']
          mode 0444
          action :create
          notifies :restart, "service[#{app_name}]"
          variables({
            :app_name => app_name,
            :user => node['opsline-rails-app']['owner'],
            :deploy_to => app_data['deploy_to'],
            :environment => env_dict,
            :parameters => container_parameters
          })
        end

        template "/etc/init/#{app_name}.conf" do
          source 'upstart.conf.erb'
          cookbook 'opsline-rails-app'
          owner 'root'
          group 'root'
          mode 0444
          action :create
          notifies :restart, "service[#{app_name}]"
          variables({
            :app_name => app_name,
            :user => node['opsline-rails-app']['owner'],
            :group => node['opsline-rails-app']['owner'],
            :deploy_to => app_data['deploy_to'],
            :exec_command => "unicorn -c #{unicorn_config}"
          })
        end

        if File.directory?('/etc/nginx/sites-available')
          service 'nginx' do
            action :nothing
          end
          template "/etc/nginx/sites-available/#{app_name}" do
            source 'nginx.conf.erb'
            cookbook 'adaptly-app-rails'
            owner 'root'
            group 'root'
            mode 0644
            action :create
            notifies :restart, resources(:service => 'nginx'), :delayed
            variables({
              :app_name => app_name,
              :deploy_to => app_data['deploy_to'],
              :port => '8080',
              :server_name => "#{app_name}.#{node.domain}"
            })
          end
          link "#{app_name} nginx site" do
            target_file "/etc/nginx/sites-enabled/#{app_name}"
            to "/etc/nginx/sites-available/#{app_name}"
          end
        end

      elsif app_data['container'] == 'rack'
        template "/etc/init/#{app_name}.conf" do
          source 'upstart.conf.erb'
          cookbook 'opsline-rails-app'
          owner 'root'
          group 'root'
          mode 0444
          action :create
          notifies :restart, "service[#{app_name}]"
          variables({
            :app_name => app_name,
            :user => node['opsline-rails-app']['owner'],
            :group => node['opsline-rails-app']['owner'],
            :deploy_to => app_data['deploy_to'],
            :exec_command => "rails server -P #{app_data['deploy_to']}/shared/pids/server.pid"
          })
        end
        
      elsif app_data['container'] == 'passenger'

      end
    }
  
    # restart proc
    restart Proc.new {
      service app_name do
        provider Chef::Provider::Service::Upstart
        action :restart
      end
    }
    
  end
  
end

class Chef::Recipe
  include Opsline::RailsApp::Helpers
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
    app_data['deploy_to'] = "#{node['opsline-rails-app']['apps_root']}/#{app_name}"
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

  services_to_restart = []



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

    # migrate db
    migrate Proc.new {
      execute "bundle exec rake db:migrate" do
        cwd "#{app_data['deploy_to']}/releases/#{artifact_version}/"
        environment env_dict
        user node['opsline-rails-app']['owner']
        group node['opsline-rails-app']['owner']
      end
    }

    # configure proc
    configure Proc.new {

      if app_data['container'] == 'unicorn'
        # get container parameters
        unless container_parameters.has_key?('timeout')
          container_parameters['timeout'] = node['opsline-rails-app']['unicorn']['timeout']
        end
        unless container_parameters.has_key?('worker_processes')
          container_parameters['worker_processes'] = node['opsline-rails-app']['unicorn']['worker_processes']
        end
        unless container_parameters.has_key?('frontend')
          container_parameters['frontend'] = ''
        end
        unless container_parameters.has_key?('frontend_port')
          container_parameters['frontend_port'] = '8080'
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
        service app_name do
          provider Chef::Provider::Service::Upstart
          action :nothing
        end
        services_to_restart << [app_name, Chef::Provider::Service::Upstart]

        if container_parameters['frontend'] == 'nginx'
          service 'nginx' do
            action :nothing
          end
          services_to_restart << ['nginx', Chef::Provider::Service::Init]
          directory '/etc/nginx'
          directory '/etc/nginx/sites-available'
          directory '/etc/nginx/sites-enabled'
          template "/etc/nginx/sites-available/#{app_name}" do
            source 'nginx.unicorn.conf.erb'
            cookbook 'opsline-rails-app'
            owner 'root'
            group 'root'
            mode 0644
            action :create
            notifies :restart, resources(:service => 'nginx'), :delayed
            variables({
              :app_name => app_name,
              :deploy_to => app_data['deploy_to'],
              :port => container_parameters['frontend_port'],
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
        service app_name do
          provider Chef::Provider::Service::Upstart
          action :nothing
        end
        services_to_restart << [app_name, Chef::Provider::Service::Upstart]

      elsif app_data['container'] == 'passenger'
        unless container_parameters.has_key?('frontend')
          container_parameters['frontend'] = ''
        end
        unless container_parameters.has_key?('frontend_port')
          container_parameters['frontend_port'] = '8080'
        end

        if container_parameters['frontend'] == 'nginx'
          service 'nginx' do
            action :nothing
          end
          services_to_restart << ['nginx', Chef::Provider::Service::Init]
          directory '/etc/nginx'
          directory '/etc/nginx/sites-available'
          directory '/etc/nginx/sites-enabled'
          template "/etc/nginx/sites-available/#{app_name}" do
            source 'nginx.passenger.conf.erb'
            cookbook 'opsline-rails-app'
            owner 'root'
            group 'root'
            mode 0644
            action :create
            notifies :restart, resources(:service => 'nginx'), :delayed
            variables({
              :app_name => app_name,
              :deploy_to => app_data['deploy_to'],
              :port => container_parameters['frontend_port'],
              :server_name => "#{app_name}.#{node.domain}",
              :env => env_dict
            })
          end
          link "#{app_name} nginx site" do
            target_file "/etc/nginx/sites-enabled/#{app_name}"
            to "/etc/nginx/sites-available/#{app_name}"
          end
        end

      end
    }

    # restart proc
    restart Proc.new {
      services_to_restart.each do |service_to_restart|
        service service_to_restart[0] do
          provider service_to_restart[1]
          action :restart
        end
      end
    }

  end

end

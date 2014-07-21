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

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

if node['opsline-rails-app']['ruby']['provider'] == 'rvm'
  include_recipe 'ruby_build'

  node.default['rvm']['user_installs'] = [
    {'user' => node['opsline-rails-app']['owner']}
  ]
  include_recipe 'rvm::user_install'

  node['opsline-rails-app']['ruby']['versions'].each do |ruby_version|
    rvm_ruby "ruby #{ruby_version}" do
      ruby_string ruby_version
      user node['opsline-rails-app']['owner']
      action :install
    end
    node['opsline-rails-app']['ruby']['gems'].each do |gem_name, gem_info|
      rvm_gem "#{gem_name} for ruby #{ruby_version}" do
        package_name gem_name
        version gem_info['version']
        ruby_string ruby_version
        user node['opsline-rails-app']['owner']
        action gem_info['ruby_versions'].include?(ruby_version) ? :install : :remove
      end
    end
  end

elsif node['opsline-rails-app']['ruby']['provider'] == 'rbenv'
  include_recipe 'ruby_build'

  node.default['rbenv']['user_installs'] = [
    {'user' => node['opsline-rails-app']['owner']}
  ]
  include_recipe 'rbenv::user_install'

  node['opsline-rails-app']['ruby']['versions'].each do |ruby_version|
    rbenv_ruby "ruby #{ruby_version}" do
      definition ruby_version
      user node['opsline-rails-app']['owner']
      action :install
    end
    #rbenv_global node['opsline-rails-app']['ruby']['version'] do
    #  rbenv_version ruby_version
    #  user node['opsline-rails-app']['owner']
    #end
    node['opsline-rails-app']['ruby']['gems'].each do |gem_name, gem_info|
      rbenv_gem "#{gem_name} for ruby #{ruby_version}" do
        package_name gem_name
        version gem_info['version']
        rbenv_version ruby_version
        user node['opsline-rails-app']['owner']
        action gem_info['ruby_versions'].include?(ruby_version) ? :install : :remove
      end
    end
  end
end

directory node['opsline-rails-app']['apps_root'] do
  action :create
  owner node['opsline-rails-app']['owner']
  group node['opsline-rails-app']['owner']
  mode 0755
end

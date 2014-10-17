#
# Cookbook Name:: opsline-rails-app
# Recipe:: default
#
# Author:: Radek Wierzbicki
#
# Copyright 2014, OpsLine, LLC.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

class Chef::Recipe
  include Opsline::RailsApp::Helpers
end

# install required packages
package 'daemontools'
package 'inotify-tools'

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
  unless node['opsline-rails-app']['ruby']['versions'].empty?
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
  end

elsif node['opsline-rails-app']['ruby']['provider'] == 'rbenv'
  unless node['opsline-rails-app']['ruby']['versions'].empty?
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

end

directory node['opsline-rails-app']['apps_root'] do
  action :create
  owner node['opsline-rails-app']['owner']
  group node['opsline-rails-app']['owner']
  mode 0755
end

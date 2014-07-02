default['opsline-rails-app']['databag'] = 'apps'
default['opsline-rails-app']['apps'] = []
default['opsline-rails-app']['s3_bucket'] = 'applications'
default['opsline-rails-app']['owner'] = 'rails'
default['opsline-rails-app']['apps_root'] = '/var/rails'
default['opsline-rails-app']['unicorn']['timeout'] = '45'
default['opsline-rails-app']['unicorn']['worker_processes'] = '2'

default['opsline-rails-app']['rbenv']['use'] = true
default['opsline-rails-app']['rbenv']['ruby_version'] = '2.1.2'

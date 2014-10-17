# opsline-rails-app Cookbook
This cookbook has been created to install, configure, and manage rails applications.
Applications are installed from artifacts stored in S3. All configuration parameters
are stored in data bag items.


# Requirements
#### cookbooks
- `artifact` - Artifact Deploy LWRP
- `ruby_build`
- `rbenv`
- `rvm`
- `logrotate`


# Attributes
* `node['opsline-rails-app']['databag']` - data bag name to store app details
* `node['opsline-rails-app']['apps']` - list of apps to deploy
* `node['opsline-rails-app']['encrypted_databag']` - true to use encrypted data bags
* `node['opsline-rails-app']['s3_bucket']` - name of the S3 bucket that holds artifacts
* `node['opsline-rails-app']['owner']` - unix user used to own and run applications
* `node['opsline-rails-app']['apps_root']` - root directory for applications
* `node['opsline-rails-app']['unicorn']['timeout']` - unicorn timeout
* `node['opsline-rails-app']['unicorn']['worker_processes']` - number of unicorn workers
* `node['opsline-rails-app']['ruby']['provider']` - rvm or rbenv
* `node['opsline-rails-app']['ruby']['versions']` - ruby versions
* `node['opsline-rails-app']['ruby']['gems']` - ruby gems


#Usage
#### opsline-rails-app::default
Prepares for deployment:
* installs required packages
* configured ruby if configured

#### opsline-rails-app::deploy
Deployed rails applications.

Rails applications are defined as data bag items in a data bag defined in attributes.

Example of app definition:
```json
{
  "id": "testapp",
  "name": "testapp",
  "artifact_name": "testapp",
  "type": "rails",
  "container": "unicorn",
  "container_parameters": {
    "default": {
      "worker_processes": "4",
      "frontend": "nginx"
    }
  },
  "version": {
    "production": "1",
    "default": "2"
  },
  "environment": {
    "production": {
      "REDIS_URL": "redis://redis-prod.example.com:6379",
      "PGBACKUPS_URL": "https://user:pass@postgresql-prod.example.com/schema"
    },
    "default": {
      "REDIS_URL": "redis://redis-test.example.com:6379",
      "PGBACKUPS_URL": "https://user:pass@postgresql-test.example.com/schema"
    }
  },
  "packages": [
    "nodejs",
    "imagemagick",
    "openjdk-7-jre-headless"
  ]
}
```

Define a list of rails apps to deploy in attributes.
```ruby
name "rails-testapp"
description "rails test app"
run_list(
  "role[base]",
  "role[ruby]",
  "recipe[opsline-rails-app::default]",
  "role[nginx]",
  "recipe[opsline-rails-app::deploy]"
)
default_attributes(
  opsline-rails-app" => {
    "owner" => "rails",
    "s3_bucket" => "example.artifacts",
    "apps" => ["testapp"],
    "ruby" => {
      "provider" => "rvm"
    }
  }
)
```

Valid containers are:
* unicorn
* rack
* passenger
* worker


License and Authors
-------------------
* Author:: Radek Wierzbicki

```text
Copyright 2014, OpsLine, LLC.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```

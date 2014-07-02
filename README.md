# opsline-rails-app Cookbook
This cookbook configured rails application.


# Requirements
#### cookbooks
- `artifact` - Artifact Deploy LWRP


# Attributes
* `node['opsline-rails-app']['databag']` - data bag name to store app details
* `node['opsline-rails-app']['apps']` - list of apps to deploy


#Usage
#### opsline-rails-app::default

Rails applications are defined as data bag items in a data bag defined in attributes.

Example of app definition:
```json
{
  "id": "testapp",
  "type": "rails",
  "version": {
    "production": "1.2.3",
    "default": "master"
  },
  "artifact_location": "s3://s3.amazonaws.com/myapps/testapp",
  "packages": [
    "nodejs"
  ],
  "environment": {
    "default": {
      "DB": "DBURL"
    }
  },
  "container": "unicorn",
  "container_parameters": {
    "production": {
      "timeout": "45",
      "worker_processes": "8"
    },
    "default": {
      "timeout": "45",
      "worker_processes": "2"
    }
  }
}
```

Define a list of rails apps to deploy in attributes.
```ruby
name "rails-app-test"
description "rails app test"
run_list *%w[
  role[base]
  role[ruby-1_9_3]
  recipe[opsline-rails-app]
]
default_attributes(
  "opsline-rails-app" => {
    "apps" => ["testapp"]
  },
  "build_essential" => {
    "compiletime" => true
  }
)
```

Valid containers are:
* unicorn
* rack
* passenger

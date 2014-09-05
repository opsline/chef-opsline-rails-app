name             'opsline-rails-app'
maintainer       'Radek Wierzbicki'
maintainer_email 'radek@opsline.com'
license          'All rights reserved'
description      'Installs/Configures opsline-rails-app'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '0.6.0'

depends 'artifact'
depends 'ruby_build'
depends 'rbenv', '~> 0.7.2'
depends 'rvm', '~> 0.9.2'
depends 'logrotate'

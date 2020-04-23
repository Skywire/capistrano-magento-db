# Magento DB

- Gem for backing up the DB and rolling back to a previous db for rollback

## Add to your project:

Add the following to your project Gemfile

~~~
gem 'capistrano-magento-db', :git => 'git@github.com:Skywire/capistrano-magento-db.git', :branch => 'master'
~~~

Then run 

~~~
bundle install
~~~

Add the following to your project Capfile

~~~
require "capistrano/magento-db"
~~~

## Requirments

This gem expects `n98-magerun2` to be executable

## Configure

Add the following configuration for the backupath to each stage

~~~
set :db_backup_path, "/path/to/capistrano/backup"
~~~
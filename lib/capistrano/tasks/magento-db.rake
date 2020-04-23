require "i18n"

en = {
  keeping_backups: "Keeping %{keep_backups} of %{backups} deployed backups on %{host}"
}

I18n.backend.store_translations(:en, capistrano: en)

namespace :magentodb do
    namespace :prepare do
      desc "Backup DB in case rollback is required"
      task :backup_db do
        on release_roles :all do
          within release_path do
            if fetch(:db_backup_path)
              execute :mkdir, "-p", fetch(:db_backup_path)
              execute :n98, "db:dump --skip-core-commands -c gz #{fetch(:db_backup_path)}/#{release_timestamp}.sql.gz"
            end
          end
        end
      end
    end

    namespace :deploy do
        desc "Clean up old backups"
        task :cleanup do
            on release_roles :all do |host|
                if fetch(:db_backup_path)
                  backups = capture(:ls, "-x", fetch(:db_backup_path)).split
                  backup_path = Pathname.new(fetch(:db_backup_path))
                  valid, invalid = backups.partition { |e| /^\d{14}\.sql\.gz$/ =~ e }

                  warn t(:skip_cleanup, host: host.to_s) if invalid.any?

                  if valid.count >= fetch(:keep_releases)
                    info t(:keeping_backups, host: host.to_s, keep_backups: fetch(:keep_releases), backups: valid.count)
                    backup_files = (valid - valid.last(fetch(:keep_releases))).map do |release|
                      backup_path.join(release).to_s
                    end

                    if test("[ -d #{current_path} ]")
                      current_release = capture(:readlink, current_path).to_s
                      if backup_files.include?(current_release)
                        warn t(:wont_delete_current_release, host: host.to_s)
                        backup_files.delete(current_release)
                      end
                    else
                      debug t(:no_current_release, host: host.to_s)
                    end
                    if backup_files.any?
                      execute :rm, *backup_files
                    else
                      info t(:no_old_releases, host: host.to_s, keep_releases: fetch(:keep_releases))
                    end
                  end
                end
            end
        end
    end


    namespace :rollback do
        desc "Rollback DB to last release"
        task :rollback_db do
          on release_roles :all do
            within release_path do
              if fetch(:db_backup_path)
                execute :mkdir, "-p", fetch(:db_backup_path)
                execute :n98, "db:import --skip-core-commands -c gz #{fetch(:db_backup_path)}/#{fetch(:rollback_timestamp)}.sql.gz"
              end
            end
          end
        end
    end
end

before "magento:setup:db:schema:upgrade", "magentodb:prepare:backup_db"

namespace :deploy do
  task :reverted do
    if fetch(:db_backup_path)
      ask(:restore, "Do you want to roll back to DB  #{fetch(:db_backup_path)}/#{fetch(:rollback_timestamp)}.sql.gz? [y/n]")

      if fetch(:restore) == "y" || fetch(:restore) == "Y"
        invoke "magento:maintenance:enable" if fetch(:magento_deploy_maintenance)
        invoke "magentodb:rollback:rollback_db"
      end
    end
  end

  task :cleanup do
    if fetch(:db_backup_path)
        invoke "magentodb:deploy:cleanup"
    end
  end
end
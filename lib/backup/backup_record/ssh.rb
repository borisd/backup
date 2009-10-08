require 'net/ssh'

module Backup
  module BackupRecord
    class SSH < ActiveRecord::Base
        
      # Establishes a connection with the SQLite3
      # local database to avoid conflict with users
      # Production database.
      establish_connection(
        :adapter  => "sqlite3",
        :database => "db/backup.sqlite3",
        :pool     => 5,
        :timeout  => 5000 )
      
      # Scopes
      default_scope :order => 'created_at desc'
      
      # Callbacks
      after_save :destroy_old_backups
      
      # Attributes
      attr_accessor :options, :keep_backups, :ip, :user
      
      # Receives the options hash and stores it
      # Sets the S3 values
      def set_options(options)
        self.options      = options
        self.backup_file  = options[:backup_file]
        self.backup_path  = options[:ssh][:path]
        self.keep_backups = options[:keep_backups]
        self.adapter      = options[:adapter]
        self.ip           = options[:ssh][:ip]
        self.user         = options[:ssh][:user]
      end

      private
        
        # Destroys backups when the backup limit has been reached
        # This is determined by the "keep_backups:" parameter
        # First all backups will be fetched. 
        def destroy_old_backups
          if keep_backups.is_a?(Integer)
            backups = Backup::BackupRecord::SSH.all(:conditions => {:adapter => adapter})
            backups_to_destroy = Array.new
            backups.each_with_index do |backup, index|
              if index >= keep_backups then
                backups_to_destroy << backup
              end
            end
          
            if backups_to_destroy
              # Establish a connection with the remote server through SSH
              Net::SSH.start(ip, user) do |ssh|
                # Loop through all backups that should be destroyed and remove them from S3.
                backups_to_destroy.each do |backup|
                  puts "Destroying old backup: #{backup.backup_file}.."
                  ssh.exec("rm #{File.join(backup.backup_path, backup.backup_file)}")
                  backup.destroy
                end
              end
            end
          end
        end
        
    end
  end
end
require File.expand_path('../drive_client', __FILE__)

class TreePwner
  def initialize
    # for this to work twice the same execution run, the waiting
    # WEBrick server needs to be shutdown, not just stopped.
    #
    # google-api-client-0.7.1/lib/google/api_client/auth/installed_app.rb
    #
    # inside server.mount_proc '/'
    @source_client = DriveClient.new('source')
    @target_client = DriveClient.new('target')
  end

  # In the Web UI, Google Drive _will_ allow a non-owning editor
  # to trash a file, though it appears this file will be orphaned
  # at that point, appearing in neither user's Trash folder.
  #
  # In the API, Google Drive _will not_ allow a non-owning editor
  # to trash a file. So, we must copy it as the 'target' user
  # so they will own the new file, and then delete it as the
  # source user, so it will be allowed - and also appear in the
  # source user's Trash folder, should we need to recover anything.
  def copy_and_replace_all_files_owned_by_source(folder_title)
    folder = @source_client.find_folder_by_title folder_title
    raise "Multiple folders <#{folder.length}> with title #{folder_title} found." if folder.is_a? Array
    folders = [folder]
    while folder = folders.shift
      @source_client.children_in_folder(folder) do |file|
        # puts "#{file.title} => #{file.mimeType}: #{file.ownerNames.join.inspect}"
        next if file.labels.trashed
        if file.mimeType == 'application/vnd.google-apps.folder'
          folders << file
          next
        end
        # if we're not the owner, then don't worry about it
        next unless file.owners.first.isAuthenticatedUser
        print "Transferring by copy/remove original: #{file['title']} ... "
        copy_file_to_target_and_delete_original_in_source(file)
      end
    end
    nil
  end

  def copy_file_to_target_and_delete_original_in_source(origin_file)
    new_file = @target_client.copy_file(origin_file)
    if new_file.md5Checksum == origin_file.md5Checksum
      @source_client.trash_file(origin_file)
      puts 'done.'
    else
      puts 'copied file md5 does not match.'
    end
  end
end
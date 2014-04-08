require File.expand_path('../copy_replace_jaerb', __FILE__)
require File.expand_path('../drive_client', __FILE__)

class TreePwner
  attr_reader :source_client, :target_client

  def initialize
    # for this to work twice the same execution run, the waiting
    # WEBrick server needs to be shutdown, not just stopped.
    #
    # google-api-client-0.7.1/lib/google/api_client/auth/installed_app.rb
    #
    # inside server.mount_proc '/'
    @source_client = DriveClient.connect('source')
    @target_client = DriveClient.connect('target')

    log_fn = File.expand_path('../../tmp/tree-pwner.log', __FILE__)
    Celluloid.logger = ::Logger.new(log_fn)
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

    pool = CopyReplaceJaerb.pool(args: self)

    while folder = folders.shift
      puts "Searching #{folder.title}"
      q = [FileCriteria.is_not_a_folder, FileCriteria.i_own, FileCriteria.not_trashed].join(' and ')
      @source_client.children_in_folder(folder, q) do |file|
        pool.async.copy_file_to_target_and_delete_original_in_source(file)
      end

      q = [FileCriteria.is_a_folder, FileCriteria.not_trashed].join(' and ')
      @source_client.children_in_folder(folder, q) do |child_folder|
        folders << child_folder
      end
    end
    nil
  end
end
require_relative 'copy_replace_jaerb'
require_relative 'drive_client'

class TreePwner
  attr_reader :source_client, :target_client

  def initialize
    log_fn = File.expand_path('../tmp/tree-pwner.log', __dir__)
    Celluloid.logger = ::Logger.new(log_fn)
  end

  def connect_source(user_id)
    puts "Connecting to Google Drive source #{user_id}..."
    @source_client = DriveClient.connect('source', user_id)
  end

  def connect_target(user_id)
    puts "Connecting to Google Drive target #{user_id}..."
    @target_client = DriveClient.connect('target', user_id)
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
      puts "Searching #{folder.name}"
      q = DriveQuery.new(FileCriteria.is_not_a_folder).
        and(FileCriteria.i_own)
      @source_client.children_in_folder(folder, q) do |file|
        pool.async.copy_file_to_target_and_delete_original_in_source(file)
      end

      q = DriveQuery.new(FileCriteria.is_a_folder)
      @source_client.children_in_folder(folder, q) do |child_folder|
        folders << child_folder
      end
    end
    nil
  end

  # A Google::Apis::DriveV3::File instance with permissions included
  def transfer_ownership_to_target(file)
    @source_client.transfer_ownership_to(file, @target_client.email_address)
    @drive.update_permission(file.id, file.permissions)
  end
end

require_relative 'copy_replace_jaerb'
require_relative 'drive_client'
require_relative 'log_factory'

class TreePwner
  attr_reader :source_client, :target_client

  def initialize
    Celluloid.logger = LogFactory.make_log('tree-pwner')
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
  def copy_and_replace_all_files_owned_by_source(folder)
    # TODO: refactor to use traverse_folder
    folders = [folder]

    pool = CopyReplaceJaerb.pool(args: self)
    puts "Created Celluloid pool with #{pool.size} workers"
    def pool.queue_size
      @async_proxy.mailbox.size
    end

    while folder = folders.shift
      print "Searching #{folder.name} ... "
      q = DriveQuery.new(FileCriteria.is_not_a_folder).
        and(FileCriteria.i_own)

      # TODO: This process can hit the rate limit before the pool is even fully queued.
      children_files = @source_client.children_in_folder(folder, q) do |file|
        pool.async.copy_file_to_target_and_delete_original_in_source(file)
      end
      print "queued #{children_files.length} files. "

      puts "Total queued: #{pool.queue_size}"

      q = DriveQuery.new(FileCriteria.is_a_folder)
      @source_client.children_in_folder(folder, q) do |child_folder|
        folders << child_folder
      end
    end

    # block on this loop while we wait for all of the Celluloid jobs to finish
    while pool.queue_size > 0
      puts "** Total queued: #{pool.queue_size}"
      sleep 10
    end

    puts "All Done!"

    nil
  end

  def traverse_folder(root_folder)
    folders = [root_folder]
    while folder = folders.shift
      print "Searching #{folder.name} ... "
      q = DriveQuery.new(FileCriteria.is_not_a_folder).
        and(FileCriteria.i_own)

      @source_client.children_in_folder(folder, q) do |file|
        yield file
      end

      q = DriveQuery.new(FileCriteria.is_a_folder)
      @source_client.children_in_folder(folder, q) do |child_folder|
        folders << child_folder
      end
    end
  end

  def transfer_ownership_all_files(current_folder)
    logger = LogFactory.make_log('tree-pwner-transfer')
    puts 'Details logged to file.'
    traverse_folder(current_folder) do |file|
      msg = "Transferring ownership of #{file.name}"
      logger.info(msg)
      print '.'
      transfer_ownership_to_target(file)
    end
    puts
    puts 'All Done.'
  end

  # A Google::Apis::DriveV3::File instance with permissions included
  def transfer_ownership_to_target(file)
    @source_client.transfer_ownership_to(file, @target_client.email_address)
  end

  def source_and_target_are_same_domain
    @source_client.email_domain == @target_client.email_domain
  end
end

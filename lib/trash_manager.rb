# After doing an ownership transfer, we can verify the copy of the file
# still exists in the restore folder of the trashed file.
class TrashManager
  def initialize(source_client, target_client)
    @source_client = source_client
    @target_client = target_client
    log_fn = File.expand_path('../tmp/tree-pwner-verify.log', __dir__)
    @logger = ::Logger.new(log_fn)
    diagnostic
  end

  def diagnostic
    @source_client.get_file_by_id 'aaa'
    raise 'Diagnostic failure.'
  rescue Google::Apis::ClientError
    # we're good - roll-on.
    # Some important functionality depends on this raising on error below.
    # After deleting the trashed file in the source, we re-retrieve the
    # same file from the target. If it can't be found, it should raise and
    # we should stop because we did something wrong or behavior has changed.
  end

  def cleanup_trash_with_target_copy(safe_perma_delete: false)
    @source_client.files_in_query(DriveQuery.new(FileCriteria.trashed)) do |trashed|
      if trashed.parents.length > 1
        log_puts("more than one parent for file in trash <#{trashed.name}>", :warn)
      end
      parent_id = trashed.parents.first
      restore_folder = @target_client.get_folder_by_id(parent_id)
      q = DriveQuery.new(FileCriteria.has_parent(parent_id)).and(FileCriteria.name_is(trashed.name))
      found = @target_client.search(q, non_pagination_ack: true)
      if found.empty?
        log_puts("trashed file not found in original folder: <#{trashed.name}>", :error)
      elsif found.length > 1
        log_puts("multiple files of name <#{trashed.name}> found in original folder.", :warn)
      end

      all_found_match = found.map do |found_file|
        if trashed.md5_checksum.nil? || found_file.md5_checksum.nil?
          log_puts("One or other file has no MD5. <#{trashed.name}>", :error)
          false
        elsif trashed.md5_checksum != found_file.md5_checksum
          log_puts("Checksums don't match: <#{trashed.name}>", :error)
          false
        else
          true
        end
      end

      if all_found_match.uniq == [true]
        core_msg = "Checksums match: <#{trashed.name}> #{trashed.md5_checksum}. Folder containing target copy: #{restore_folder.web_view_link}"
        if safe_perma_delete
          log_puts("Deleting trashed file. #{core_msg}", :info)
          @source_client.permanently_delete_trashed_file(trashed)

          # Will raise if the id is missing.
          found.each { |found_file| @target_client.get_file_by_id(found_file.id) }
        else
          log_puts(core_msg)
        end
      end

    end
  end

  private

  def log_puts(msg, level = :info)
    @logger.send(level, msg)
    puts msg
  end
end
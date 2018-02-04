require_relative 'jaerb'

# After doing an ownership transfer, we can verify the copy of the file
# still exists in the restore folder of the trashed file.
class SafeTrashJaerb < Jaerb
  def initialize(source_client, target_client, safe_perma_delete)
    @source_client = source_client
    @target_client = target_client
    @safe_perma_delete = safe_perma_delete
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

  def trash_source_file_if_target_exists(trashed)
    FileDelorter.new(@source_client, @target_client, @safe_perma_delete, trashed)
      .safe_delort
  end

  class FileDelorter
    attr_reader :trashed

    def initialize(source_client, target_client, safe_perma_delete, trashed)
      @trashed = trashed
      @source_client = source_client
      @target_client = target_client
      @safe_perma_delete = safe_perma_delete
    end

    def safe_delort
      warn_if_multiple_parents

      parent_id = trashed.parents.first
      restore_folder = @target_client.get_folder_by_id(parent_id)

      found = find_transferred_file(parent_id, restore_folder)

      all_found_match = trashed_matches?(found)

      remove_trashed_file(found, restore_folder) if all_found_match.uniq == [true]
    end

    private

    def trashed_matches?(found)
      found.map do |found_file|
        if trashed.is_google_doc?
          raise "Cannot compare Google Docs"
        elsif trashed.md5_checksum.nil? || found_file.md5_checksum.nil?
          log_put("One or other file has no MD5. <#{trashed.name}>", :error)
          false
        elsif trashed.md5_checksum != found_file.md5_checksum
          log_put("Checksums don't match: <#{trashed.name}>", :error)
          false
        else
          true
        end
      end
    end

    def find_transferred_file(parent_id, restore_folder)
      q = DriveQuery.new(FileCriteria.has_parent(parent_id)).and(FileCriteria.name_is(trashed.name))
      found = @target_client.search(q, non_pagination_ack: true)
      if found.empty?
        log_put("Trashed file not found in original folder: <#{trashed.name}> in <#{restore_folder.name}>", :error)
      elsif found.length > 1
        log_put("Multiple files of name <#{trashed.name}> found in original folder.", :warn)
      end
      found
    end

    def warn_if_multiple_parents
      if trashed.parents.length > 1
        log_put("more than one parent for file in trash <#{trashed.name}>", :warn)
      end
    end

    def remove_trashed_file(found, restore_folder)
      core_msg = "Checksums match: <#{trashed.name}> #{trashed.md5_checksum}. Folder containing target copy: #{restore_folder.web_view_link}"
      if @safe_perma_delete
        log_put("Deleting trashed file. #{core_msg}", :info)
        @source_client.permanently_delete_trashed_file(trashed)

        # Will raise if the id is missing.
        found.each { |found_file| @target_client.get_file_by_id(found_file.id) }
      else
        log_put(core_msg)
      end
    end
  end
end

require_relative 'jaerb'

class CopyReplaceJaerb < Jaerb
  def copy_file_to_target_and_delete_original_in_source(origin_file)
    new_file = nil

    with_retries(retry_options) do |attempt_number|
      log_put("Re-try #{attempt_number}", :warn) if attempt_number > 1
      new_file = @pwner.target_client.copy_file(origin_file)
    end

    with_retries(retry_options) do |attempt_number|
      log_put("Re-try #{attempt_number}", :warn) if attempt_number > 1
      # We used to check md5_checksum here, but somewhere between the original coding
      # and later code, the md5_checksum was blank on both files! Then the md5_checksum
      # was ensured to be returned in the source file, but it's never in the copied file.
      # I don't want to take the time here to re-retrieve it considering I now have code
      # to confirm the file was copied properly when permanently deleting a file from trash.
      @pwner.source_client.trash_file(origin_file)
      log_put("#{origin_file.name} done.")
    end
  end

end

require_relative 'jaerb'

# We used to check md5_checksum here, but somewhere between the original coding
# and later code, the md5_checksum was blank on both files! Then the md5_checksum
# was ensured to be returned in the source file, but it's never in the copied file.
# I don't want to take the time here to re-retrieve it considering I now have code
# to confirm the file was copied properly when permanently deleting a file from trash.
#
# TODO: Rename
class CopyReplaceJaerb < Jaerb
  def transfer_file_to_target(source_file)
    if is_google_doc_in_same_domain?(source_file)
      transfer_ownership_to_target(source_file)
    else
      copy_file_to_target_and_delete_original_in_source(source_file)
    end
  end

  def copy_file_to_target_and_delete_original_in_source(source_file)
    if source_file.is_google_doc?
      new_file = @pwner.target_client.copy_file(source_file)
      @pwner.source_client.trash_file(source_file)
      @pwner.target_client.rename_file(new_file, new_file.name.sub(/^Copy of /, ''))
      log_put("#{source_file.name} copied.")
    else
      @pwner.target_client.copy_file(source_file)
      @pwner.source_client.trash_file(source_file)
      log_put("#{source_file.name} copied.")
    end
  rescue => e
    log_put("#{source_file.name}: #{e.message}")
  end

  def transfer_ownership_to_target(source_file)
    @pwner.source_client.transfer_ownership_to(source_file, @pwner.target_client.email_address)
    log_put("#{source_file.name} ownership transferred.")
  rescue => e
    log_put("#{source_file.name}: #{e.message}")
  end

  private

  def is_google_doc_in_same_domain?(source_file)
    source_file.is_google_doc? && can_transfer_ownership?
  end

  def can_transfer_ownership?
    @pwner.source_and_target_in_same_domain?
  end
end

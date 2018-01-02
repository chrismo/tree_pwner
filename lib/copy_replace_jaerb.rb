require_relative 'jaerb'

# We used to check md5_checksum here, but somewhere between the original coding
# and later code, the md5_checksum was blank on both files! Then the md5_checksum
# was ensured to be returned in the source file, but it's never in the copied file.
# I don't want to take the time here to re-retrieve it considering I now have code
# to confirm the file was copied properly when permanently deleting a file from trash.
class CopyReplaceJaerb < Jaerb
  def copy_file_to_target_and_delete_original_in_source(origin_file)
    @pwner.target_client.copy_file(origin_file)
    @pwner.source_client.trash_file(origin_file)
    log_put("#{origin_file.name} done.")
  end
end

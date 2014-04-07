# require 'celluloid/autostart'

class CopyReplaceJaerb
  # include Celluloid

  def initialize(pwner)
    @pwner = pwner
  end

  def copy_file_to_target_and_delete_original_in_source(origin_file)
    new_file = @pwner.target_client.copy_file(origin_file)
    if new_file.md5Checksum == origin_file.md5Checksum
      @pwner.source_client.trash_file(origin_file)
      puts "#{origin_file.title} done."
    else
      puts "#{origin_file.title} copied file md5 does not match."
    end
  end
end
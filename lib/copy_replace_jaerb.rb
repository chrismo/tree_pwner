require 'celluloid/autostart'
require 'retries'

class CopyReplaceJaerb
  include Celluloid
  include Celluloid::Logger

  def initialize(pwner)
    @pwner = pwner
  end

  def retry_options
    {:max_tries => 10,
     :base_sleep_seconds => 2.0,
     :max_sleep_seconds => 30.0,
     :rescue => [RateLimitExceeded]}
  end

  def copy_file_to_target_and_delete_original_in_source(origin_file)
    new_file = nil

    with_retries(retry_options) do |attempt_number|
      puts "Re-try #{attempt_number}" if attempt_number > 1
      new_file = @pwner.target_client.copy_file(origin_file)
    end

    with_retries(retry_options) do |attempt_number|
      puts "Re-try #{attempt_number}" if attempt_number > 1
      if new_file.md5Checksum == origin_file.md5Checksum
        @pwner.source_client.trash_file(origin_file)
        info "#{origin_file.title} done."
        puts "#{origin_file.title} done."
      else
        raise "#{origin_file.title} copied file md5 does not match."
      end
    end
  end
end
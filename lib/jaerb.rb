require 'celluloid/autostart'
require 'retries'

# http://www.hrwiki.org/wiki/A_Jorb_Well_Done
class Jaerb
  include Celluloid
  include Celluloid::Logger

  def initialize(pwner)
    @pwner = pwner
  end

  def log_put(msg, level = :info)
    self.send(level, msg)
    puts msg
  end
end
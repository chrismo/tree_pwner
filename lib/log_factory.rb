class LogFactory
  def self.make_log(name)
    log_fn = File.expand_path("../tmp/#{name}.log", __dir__)
    FileUtils.makedirs(File.dirname(log_fn))
    logger = ::Logger.new(log_fn, 10)
  end
end
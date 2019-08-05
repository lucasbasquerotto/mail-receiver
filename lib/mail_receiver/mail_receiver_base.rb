class MailReceiverBase
  class ReceiverException < StandardError; end;

  attr_reader :env

  def initialize(env_file)
    unless File.exists?(env_file)
      fatal "Config file %s does not exist. Aborting.", env_file
    end

    @env = JSON.parse(File.read(env_file))

    %w{SITE_API_KEY SITE_API_USERNAME}.each do |kw|
      fatal "env var %s is required", kw unless @env[kw]
    end

    if @env['SITE_MAIL_ENDPOINT'].nil? && @env['SITE_BASE_URL'].nil?
      fatal "SITE_MAIL_ENDPOINT and SITE_BASE_URL env var missing"
    end

    if @env['SITE_API_HANDLE_MAIL_URL'].nil?
      fatal "SITE_API_HANDLE_MAIL_URL env var missing"
    end

    if @env['SITE_API_SHOULD_REJECT_MAIL_URL'].nil?
      fatal "SITE_API_SHOULD_REJECT_MAIL_URL env var missing"
    end
  end

  def self.logger
    @logger ||= Syslog.open(File.basename($0), Syslog::LOG_PID, Syslog::LOG_MAIL)
  end

  def logger
    MailReceiverBase.logger
  end

  def key
    @env['SITE_API_KEY']
  end

  def username
    @env['SITE_API_USERNAME']
  end

  def fatal(*args)
    logger.crit(*args)
    raise ReceiverException.new(sprintf(*args))
  end
end

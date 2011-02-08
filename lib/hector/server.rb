module Hector
  class << self
    attr_accessor :server_name, :port, :ssl_port, :motd, :auto_join

    def start_server(address = "0.0.0.0", port = self.port, ssl_port = self.ssl_port)
      EventMachine.start_server(address, port, Connection)
      EventMachine.start_server(address, ssl_port, SSLConnection)
      logger.info("Hector running on #{address}:#{port}")
      logger.info("Secure Hector running on #{address}:#{ssl_port}")
    end
  end

  self.server_name = "hector.irc"
  self.port = 6767
  self.ssl_port = 6868
  self.auto_join = []
end

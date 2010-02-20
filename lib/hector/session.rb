module Hector
  class Session
    attr_reader :nickname, :connection, :identity

    class << self
      def nicknames
        sessions.keys
      end

      def find(nickname)
        sessions[normalize(nickname)]
      end

      def create(nickname, connection, identity)
        if find(nickname)
          raise NicknameInUse, nickname
        else
          new(nickname, connection, identity).tap do |session|
            sessions[normalize(nickname)] = session
          end
        end
      end

      def delete(nickname)
        sessions.delete(normalize(nickname))
      end

      def broadcast_to(sessions, command, *args)
        except = args.last.delete(:except) if args.last.is_a?(Hash)
        sessions.each do |session|
          session.respond_with(command, *args) unless session == except
        end
      end

      def normalize(nickname)
        if nickname =~ /^\w[\w-]{0,15}$/
          nickname.downcase
        else
          raise ErroneousNickname, nickname
        end
      end

      def reset!
        @sessions = nil
      end

      protected
        def sessions
          @sessions ||= {}
        end
    end

    def initialize(nickname, connection, identity)
      @nickname = nickname
      @connection = connection
      @identity = identity
    end

    def receive(request)
      @request = request
      if respond_to?(request.event_name)
        send(request.event_name)
      end
    ensure
      @request = nil
    end

    def welcome
      respond_with("001", nickname, :text => "Welcome to IRC")
      respond_with("422", :text => "MOTD File is missing")
    end

    def on_privmsg
      destination, text = request.args.first, request.text

      if channel?(destination)
        on_channel_privmsg(destination, text)
      else
        on_session_privmsg(destination, text)
      end
    end

    def on_channel_privmsg(channel_name, text)
      if channel = Channel.find(channel_name)
        if channel.has_session?(self)
          channel.broadcast(:privmsg, channel.name, :source => source, :text => text, :except => self)
        else
          raise CannotSendToChannel, channel_name
        end
      else
        raise NoSuchNickOrChannel, channel_name
      end
    end

    def on_session_privmsg(nickname, text)
      if session = Session.find(nickname)
        session.respond_with(:privmsg, nickname, :source => source, :text => text)
      else
        raise NoSuchNickOrChannel, nickname
      end
    end

    def on_join
      Channel.find_or_create(request.args.first).join(self)
    end

    def on_part
      Channel.find(request.args.first).part(self, request.text)
    end

    def on_names
      Channel.find(request.args.first).respond_to_names(self)
    end

    def on_topic
      channel = Channel.find(request.args.first)

      if request.args.length > 1
        channel.change_topic(self, request.text)
      else
        channel.respond_to_topic(self)
      end
    end

    def on_ping
      respond_with(:pong, "hector.irc", :source => "hector.irc", :text => request.text)
    end

    def on_quit
      @quit_message = "Quit: #{request.text}"
      connection.close_connection
    end

    def destroy
      deliver_quit_message
      leave_all_channels
      self.class.delete(nickname)
    end

    def respond_with(*args)
      connection.respond_with(*args)
    end

    def broadcast(command, *args)
      Session.broadcast_to(peer_sessions, command, *args)
    end

    def channels
      Channel.find_all_for_session(self)
    end

    def peer_sessions
      channels.map { |channel| channel.sessions }.flatten.uniq
    end

    def quit_message
      @quit_message || "Connection closed"
    end

    def source
      "#{nickname}!#{identity.username}@hector"
    end

    protected
      attr_reader :request

      def channel?(destination)
        destination =~ /^#/
      end

      def deliver_quit_message
        broadcast(:quit, :source => source, :text => quit_message, :except => self)
        respond_with(:error, :text => "Closing Link: #{nickname}[hector] (#{quit_message})")
      end

      def leave_all_channels
        channels.each do |channel|
          channel.remove(self)
        end
      end
  end
end

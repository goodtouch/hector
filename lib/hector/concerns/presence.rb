module Hector
  module Concerns
    module Presence
      def self.included(klass)
        klass.class_eval do
          attr_reader :created_at, :updated_at
        end
      end

      def channels
        Channel.find_all_for_session(self)
      end

      def initialize_presence
        @created_at = Time.now
        @updated_at = Time.now
        deliver_welcome_message
      end

      def destroy_presence
        deliver_quit_message
        leave_all_channels
      end

      def seconds_idle
        Time.now - updated_at
      end

      def peer_sessions
        [self, *channels.map { |channel| channel.sessions }.flatten].uniq
      end

      def touch_presence
        @updated_at = Time.now
      end

      protected
        def deliver_welcome_message
          respond_with("001", nickname, :text => "Welcome to IRC")
          if Hector.motd
            respond_with("375", nickname, :source => Hector.server_name, :text => "- #{Hector.server_name} Message of the day -")
            Hector.motd.split("\n").each do |line|
              respond_with("372", nickname, :source => Hector.server_name, :text => "- #{line}")
            end
            respond_with("376", nickname, :source => Hector.server_name, :text => "End of MOTD command")
          end
          Hector.auto_join.each do |channel|
            channel = Channel.find_or_create(channel)
            if channel.join(self)
              channel.broadcast(:join, :source => source, :text => channel.name)
              respond_to_topic(channel)
              respond_to_names(channel)
            end
          end
        end

        def deliver_quit_message
          broadcast(:quit, :source => source, :text => quit_message, :except => self)
          respond_with(:error, :text => "Closing Link: #{nickname}[hector] (#{quit_message})")
        end

        def leave_all_channels
          channels.each do |channel|
            channel.part(self)
          end
        end

        def quit_message
          @quit_message || "Connection closed"
        end
    end
  end
end

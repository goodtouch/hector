module Hector
  module Commands
    module Nick
      def on_nick
        old_nickname = nickname
        nickname = request.args.first
        if nickname != old_nickname
          rename(nickname)
          broadcast(:nick, nickname, :source => old_nickname)
        end
      end
    end
  end
end

module Hector
  class NoIdentityAdapter
    def authenticate(username, password)
      yield true
    end

    def normalize(username)
      username.strip.downcase
    end
  end
end

require "json"

module MailMate
  # Persists DeviseTokenAuth credentials between CLI invocations.
  # Stored at ~/.config/mailmate/credentials.json (chmod 600).
  struct Credentials
    include JSON::Serializable

    property access_token : String
    property client_id : String
    property uid : String
    property base_url : String = "https://app.mailmate.jp"

    def initialize(@access_token : String, @client_id : String, @uid : String, @base_url : String = "https://app.mailmate.jp")
    end

    def self.path : Path
      Path.home / ".config" / "mailmate" / "credentials.json"
    end

    def self.load : Credentials
      raise "Not logged in. Run `mailmate login`." unless File.exists?(path)
      from_json(File.read(path))
    rescue JSON::ParseException
      raise "Credentials file is corrupt. Run `mailmate login` to re-authenticate."
    end

    def self.exists? : Bool
      File.exists?(path)
    end

    def save : Nil
      dir = self.class.path.parent
      Dir.mkdir_p(dir)
      File.write(self.class.path, to_pretty_json)
      File.chmod(self.class.path, 0o600)
    end

    def delete : Nil
      File.delete(self.class.path) if File.exists?(self.class.path)
    end
  end
end

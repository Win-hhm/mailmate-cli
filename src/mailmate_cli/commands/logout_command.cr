module MailMate::CLI
  class LogoutCommand < ACON::Command
    def initialize
      super("logout")
    end

    protected def configure : Nil
      self.description = "Remove saved credentials"
    end

    protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
      unless MailMate::Credentials.exists?
        output.puts "<comment>Not logged in.</comment>"
        return ACON::Command::Status::SUCCESS
      end

      creds = MailMate::Credentials.load

      begin
        client = MailMate::Client.new(creds)
        client.sign_out
      rescue
        # Best-effort — still delete local credentials even if server call fails
      end

      creds.delete
      Formatter.success(output, "Logged out")
      ACON::Command::Status::SUCCESS
    end
  end
end

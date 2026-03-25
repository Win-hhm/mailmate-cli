module MailMate::CLI
  class AccountCommand < ACON::Command
    def initialize
      super("account")
    end

    protected def configure : Nil
      @description = "Show account info and inboxes"
    end

    protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
      client  = MailMate::Client.from_credentials_file
      result  = client.list_inboxes
      inboxes = result.data || [] of MailMateAPI::JsonapiResource

      creds = MailMate::Credentials.load
      output.puts ""
      output.puts "  <info>Account</info>  #{creds.uid}"
      output.puts "  <info>Server</info>   #{creds.base_url}"
      output.puts ""

      if inboxes.empty?
        output.puts "<comment>No inboxes found.</comment>"
        return ACON::Command::Status::SUCCESS
      end

      rows = inboxes.map do |inbox|
        a = inbox.attributes
        [
          inbox.id,
          Formatter.attr(a, "name"),
          Formatter.attr(a, "address"),
          Formatter.attr(a, "plan_name"),
        ]
      end

      Formatter.table(output, ["ID", "Name", "Address", "Plan"], rows)

      ACON::Command::Status::SUCCESS
    rescue ex
      Formatter.error(output, ex.message || "Not logged in. Run `mailmate login`.")
      ACON::Command::Status::FAILURE
    end
  end
end

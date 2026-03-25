module MailMate::CLI
  # Authenticates the user and saves DeviseTokenAuth credentials to
  # ~/.config/mailmate/credentials.json
  #
  # TODO: replace email/password prompt with device OAuth flow once the
  # Rails API exposes a /oauth/device endpoint via Doorkeeper.
  class LoginCommand < ACON::Command
    def initialize
      super("login")
    end

    protected def configure : Nil
      @description = "Authenticate with MailMate (saves credentials locally)"
    end

    protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
      if MailMate::Credentials.exists?
        output.puts "<comment>Already logged in. Run `mailmate logout` first to switch accounts.</comment>"
      end

      helper = self.helper(ACON::Helper::Question)

      email    = helper.ask(input, output, ACON::Question(String).new("Email: ", ""))
      password = helper.ask(input, output, ACON::Question(String).new("Password: ", "").tap { |q| q.hidden = true })

      output.puts "Authenticating…"

      config   = MailMateAPI::Configuration.new
      auth_api = MailMateAPI::AuthApi.new(MailMateAPI::ApiClient.new(config))
      request  = MailMateAPI::SignInRequest.new(email: email, password: password)

      begin
        _body, status, headers = auth_api.sign_in_with_http_info(request)

        unless status == 200
          Formatter.error(output, "Login failed (HTTP #{status})")
          return ACON::Command::Status::FAILURE
        end

        token     = headers["access-token"]? || raise "Missing access-token header"
        client_id = headers["client"]?        || raise "Missing client header"
        uid       = headers["uid"]?           || raise "Missing uid header"

        MailMate::Credentials.new(
          access_token: token,
          client_id:    client_id,
          uid:          uid
        ).save

        Formatter.success(output, "Logged in as #{uid}")
      rescue ex
        Formatter.error(output, ex.message || "Unknown error")
        return ACON::Command::Status::FAILURE
      end

      ACON::Command::Status::SUCCESS
    end
  end
end

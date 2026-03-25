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
      self.option("url", "u", :optional, "API base URL", "https://mailmate.jp")
    end

    protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
      if MailMate::Credentials.exists?
        output.puts "<comment>Already logged in. Run `mailmate logout` first to switch accounts.</comment>"
      end

      helper = self.helper(ACON::Helper::Question)

      email    = helper.ask(input, output, ACON::Question(String).new("Email: ", "")).as(String)
      password = helper.ask(input, output, ACON::Question(String).new("Password: ", "").tap { |q| q.hidden = true }).as(String)

      base_url = input.option("url", String)
      output.puts "Authenticating…"

      uri    = URI.parse(base_url)
      config = MailMateAPI::Configuration.new.tap do |c|
        c.scheme = uri.scheme || "https"
        c.host   = "#{uri.host}#{uri.port ? ":#{uri.port}" : ""}"
      end
      auth_api = MailMateAPI::AuthApi.new(MailMateAPI::ApiClient.new(config))
      request  = MailMateAPI::SignInRequest.new(email: email, password: password)

      begin
        _body, status, headers = auth_api.sign_in_with_http_info(request)

        unless status == 200
          Formatter.error(output, "Login failed (HTTP #{status})")
          return ACON::Command::Status::FAILURE
        end

        token     = header_string(headers, "access-token") || raise "Missing access-token header"
        client_id = header_string(headers, "client")       || raise "Missing client header"
        uid       = header_string(headers, "uid")          || raise "Missing uid header"

        MailMate::Credentials.new(
          access_token: token,
          client_id:    client_id,
          uid:          uid,
          base_url:     base_url
        ).save

        Formatter.success(output, "Logged in as #{uid}")
      rescue ex
        Formatter.error(output, ex.message || "Unknown error")
        return ACON::Command::Status::FAILURE
      end

      ACON::Command::Status::SUCCESS
    end

    private def header_string(headers, key : String) : String?
      val = headers[key]?
      case val
      when Array then val.first?.try(&.to_s)
      when String then val
      else nil
      end
    end
  end
end

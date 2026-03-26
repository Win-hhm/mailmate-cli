require "openssl"
require "base64"
require "http"
require "uri"
require "json"

module MailMate::CLI
  OAUTH_CLIENT_ID    = "mailmate-cli"
  OAUTH_CALLBACK_PORT = 9374
  OAUTH_CALLBACK_PATH = "/callback"

  # Authenticates via browser-based OAuth 2.0 Authorization Code + PKCE flow
  # (RFC 7636 / RFC 8252). The user's browser opens the MailMate login page;
  # the CLI captures the callback automatically — no copy-paste required.
  class LoginCommand < ACON::Command
    def initialize
      super("login")
    end

    protected def configure : Nil
      @description = "Authenticate with MailMate (opens browser)"
      self.option("url", "u", :optional, "API base URL", "https://mailmate.jp")
    end

    protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
      if MailMate::Credentials.exists?
        output.puts "<comment>Already logged in. Run `mailmate logout` first to switch accounts.</comment>"
      end

      base_url      = input.option("url", String)
      code_verifier = generate_code_verifier
      challenge     = generate_code_challenge(code_verifier)
      state         = Random::Secure.hex(16)
      redirect_uri  = "http://localhost:#{OAUTH_CALLBACK_PORT}#{OAUTH_CALLBACK_PATH}"

      auth_url = build_auth_url(base_url, challenge, state, redirect_uri)

      output.puts "Opening your browser for authentication…"
      output.puts "<comment>If it does not open automatically, visit:</comment>"
      output.puts auth_url
      output.puts ""

      open_browser(auth_url)

      # Block until callback is received or we time out (2 minutes)
      code = wait_for_callback

      if code.nil?
        Formatter.error(output, "Authentication timed out or was cancelled")
        return ACON::Command::Status::FAILURE
      end

      output.puts "Exchanging authorization code for credentials…"

      bearer = exchange_code_for_token(base_url, code, code_verifier, redirect_uri)
      if bearer.nil?
        Formatter.error(output, "Failed to exchange authorization code for access token")
        return ACON::Command::Status::FAILURE
      end

      credentials = exchange_token_for_devise(base_url, bearer)
      if credentials.nil?
        Formatter.error(output, "Failed to exchange OAuth token for API credentials")
        return ACON::Command::Status::FAILURE
      end

      credentials.save
      Formatter.success(output, "Logged in as #{credentials.uid}")

      ACON::Command::Status::SUCCESS
    end

    # ── PKCE helpers ────────────────────────────────────────────────────────

    private def generate_code_verifier : String
      Base64.urlsafe_encode(Random::Secure.random_bytes(32), padding: false)
    end

    private def generate_code_challenge(verifier : String) : String
      digest = OpenSSL::Digest.new("SHA256")
      digest.update(verifier)
      Base64.urlsafe_encode(digest.final, padding: false)
    end

    # ── OAuth URL builder ───────────────────────────────────────────────────

    private def build_auth_url(base_url : String, challenge : String, state : String, redirect_uri : String) : String
      params = HTTP::Params.encode({
        "client_id"             => OAUTH_CLIENT_ID,
        "response_type"         => "code",
        "redirect_uri"          => redirect_uri,
        "scope"                 => "read write",
        "state"                 => state,
        "code_challenge"        => challenge,
        "code_challenge_method" => "S256",
      })
      "#{base_url}/oauth/authorize?#{params}"
    end

    # ── Browser opener (compile-time OS detection) ─────────────────────────

    private def open_browser(url : String) : Nil
      {% if flag?(:darwin) %}
        Process.run("open", [url])
      {% elsif flag?(:linux) %}
        Process.run("xdg-open", [url])
      {% else %}
        Process.run("cmd.exe", ["/c", "start", url])
      {% end %}
    end

    # ── Local HTTP callback server ──────────────────────────────────────────

    private def wait_for_callback : String?
      result = Channel(String?).new(1)

      server = HTTP::Server.new do |ctx|
        query = HTTP::Params.parse(ctx.request.query || "")
        code  = query["code"]?

        ctx.response.content_type = "text/html; charset=utf-8"
        if code
          ctx.response.print success_page
          result.send(code)
        else
          ctx.response.status_code = 400
          ctx.response.print error_page
          result.send(nil)
        end
      end

      server.bind_tcp("127.0.0.1", OAUTH_CALLBACK_PORT)
      spawn { server.listen }

      code : String? = nil
      select
      when v = result.receive
        code = v
      when timeout(2.minutes)
        code = nil
      end

      server.close rescue nil
      code
    end

    # ── Token exchange steps ────────────────────────────────────────────────

    private def exchange_code_for_token(base_url : String, code : String, verifier : String, redirect_uri : String) : String?
      response = HTTP::Client.post(
        "#{base_url}/oauth/token",
        headers: HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded"},
        body: HTTP::Params.encode({
          "grant_type"    => "authorization_code",
          "client_id"     => OAUTH_CLIENT_ID,
          "code"          => code,
          "redirect_uri"  => redirect_uri,
          "code_verifier" => verifier,
        })
      )
      return nil unless response.status_code == 200
      JSON.parse(response.body)["access_token"]?.try(&.as_s)
    end

    private def exchange_token_for_devise(base_url : String, bearer : String) : MailMate::Credentials?
      response = HTTP::Client.post(
        "#{base_url}/api/v1/auth/cli_exchange",
        headers: HTTP::Headers{
          "Authorization" => "Bearer #{bearer}",
          "Content-Type"  => "application/json",
        }
      )
      return nil unless response.status_code == 200

      json         = JSON.parse(response.body)
      access_token = json["access_token"]?.try(&.as_s) || return nil
      client_id    = json["client_id"]?.try(&.as_s)    || return nil
      uid          = json["uid"]?.try(&.as_s)           || return nil

      MailMate::Credentials.new(
        access_token: access_token,
        client_id:    client_id,
        uid:          uid,
        base_url:     base_url
      )
    end

    # ── Callback page HTML ──────────────────────────────────────────────────

    private def success_page : String
      <<-HTML
        <!DOCTYPE html>
        <html lang="en">
        <head><meta charset="utf-8"><title>MailMate CLI</title>
        <style>body{font-family:sans-serif;display:flex;align-items:center;justify-content:center;height:100vh;margin:0;background:#f5f5f5}
        .card{background:#fff;border-radius:8px;padding:2rem 3rem;box-shadow:0 2px 8px rgba(0,0,0,.12);text-align:center}
        h1{color:#22c55e;margin-bottom:.5rem}p{color:#555}</style>
        </head>
        <body><div class="card">
          <h1>&#10003; Authentication successful</h1>
          <p>You can close this tab and return to your terminal.</p>
        </div></body></html>
      HTML
    end

    private def error_page : String
      <<-HTML
        <!DOCTYPE html>
        <html lang="en">
        <head><meta charset="utf-8"><title>MailMate CLI</title>
        <style>body{font-family:sans-serif;display:flex;align-items:center;justify-content:center;height:100vh;margin:0;background:#f5f5f5}
        .card{background:#fff;border-radius:8px;padding:2rem 3rem;box-shadow:0 2px 8px rgba(0,0,0,.12);text-align:center}
        h1{color:#ef4444;margin-bottom:.5rem}p{color:#555}</style>
        </head>
        <body><div class="card">
          <h1>&#10007; Authentication failed</h1>
          <p>Something went wrong. Please try again from your terminal.</p>
        </div></body></html>
      HTML
    end
  end
end

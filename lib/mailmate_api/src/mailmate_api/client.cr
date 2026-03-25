module MailMate
  # High-level facade over the generated MailMateAPI client.
  # Injects DeviseTokenAuth credentials into every call automatically —
  # callers never need to pass access_token/client/uid manually.
  #
  # Usage:
  #   client = MailMate::Client.from_credentials_file
  #   inboxes = client.list_inboxes
  #   items   = client.list_items(inbox_id: inboxes.first.id)
  #   item    = client.get_item(inbox_id: inbox.id, id: 42)
  class Client
    getter credentials : Credentials

    def initialize(@credentials : Credentials)
    end

    def self.from_credentials_file : Client
      new(Credentials.load)
    end

    # ── Inboxes ────────────────────────────────────────────────────────────

    def list_inboxes(page : Int32? = nil, per_page : Int32? = nil)
      inboxes_api.list_inboxes(token, client_id, uid, page, per_page)
    end

    def get_inbox(id : Int32)
      inboxes_api.get_inbox(id, token, client_id, uid)
    end

    def list_inboxes_flat
      inboxes_api.list_inboxes_flat(token, client_id, uid)
    end

    # ── Items (postal mails) ───────────────────────────────────────────────

    def list_items(inbox_id : Int32, page : Int32? = nil, per_page : Int32? = nil, keyword : String? = nil,
                   received_after : Time? = nil, received_up_until : Time? = nil,
                   updated_after : Time? = nil, updated_up_until : Time? = nil)
      items_api.list_items(
        inbox_id, token, client_id, uid,
        page, per_page, keyword,
        received_after, received_up_until,
        updated_after, updated_up_until
      )
    end

    def get_item(inbox_id : Int32, id : Int32)
      items_api.get_item(inbox_id, id, token, client_id, uid)
    end

    def open_item(inbox_id : Int32, id : Int32)
      items_api.open_item(inbox_id, id, token, client_id, uid)
    end

    # ── Auth ───────────────────────────────────────────────────────────────

    def sign_out
      auth_api.sign_out(token, client_id, uid)
    end

    private def token;     @credentials.access_token; end
    private def client_id; @credentials.client_id;   end
    private def uid;       @credentials.uid;          end

    private def api_client;  MailMateAPI::ApiClient.new(build_config);    end
    private def auth_api;    MailMateAPI::AuthApi.new(api_client);         end
    private def inboxes_api; MailMateAPI::InboxesApi.new(api_client);      end
    private def items_api;   MailMateAPI::ItemsApi.new(api_client);        end

    private def build_config
      uri = URI.parse(@credentials.base_url)
      MailMateAPI::Configuration.new.tap do |c|
        c.scheme = uri.scheme || "https"
        c.host   = uri.host   || "app.mailmate.jp"
      end
    end
  end
end

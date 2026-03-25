module MailMate::CLI
  class ItemsOpenCommand < ACON::Command
    def initialize
      super("items:open")
    end

    protected def configure : Nil
      @description = "Request a mail item to be opened and scanned (takes up to 24 hours)"
      self
        .argument("id", :required, "Item ID")
        .option("inbox", "i", :optional, "Inbox ID", nil)
    end

    protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
      client   = MailMate::Client.from_credentials_file
      item_id  = input.argument("id", String).to_i? || (Formatter.error(output, "Invalid ID"); return ACON::Command::Status::FAILURE)
      inbox_id = resolve_inbox(client, input, output) || return ACON::Command::Status::FAILURE

      client.open_item(inbox_id: inbox_id, id: item_id)
      Formatter.success(output, "Open requested for item #{item_id}. Processing within 24 hours.")

      ACON::Command::Status::SUCCESS
    rescue ex : MailMateAPI::ApiError
      Formatter.error(output, "API error #{ex.code}: #{ex.message}")
      ACON::Command::Status::FAILURE
    rescue ex
      Formatter.error(output, ex.message || "Unknown error")
      ACON::Command::Status::FAILURE
    end

    private def resolve_inbox(client : MailMate::Client, input : ACON::Input::Interface, output : ACON::Output::Interface) : Int32?
      if id_str = input.option("inbox", String?)
        return id_str.to_i?
      end
      result  = client.list_inboxes_flat
      inboxes = result.try(&.data) || [] of MailMateAPI::JsonapiResource
      inboxes.first?.try(&.id.to_i) || (Formatter.error(output, "No inboxes found. Use --inbox <id>."); nil)
    end
  end
end

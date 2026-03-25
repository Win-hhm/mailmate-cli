module MailMate::CLI
  class ItemsInfoCommand < ACON::Command
    def initialize
      super("items:info")
    end

    protected def configure : Nil
      @description = "Show mail item detail (use -j for JSON with S3 links)"
      self
        .argument("id", :required, "Item ID")
        .option("inbox", "i", :optional, "Inbox ID (auto-selected if you have one inbox)", nil)
        .option("json", "j", :none, "Output raw JSON (includes pre-signed S3 links to scanned contents)")
    end

    protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
      client   = MailMate::Client.from_credentials_file
      item_id  = input.argument("id", String).to_i? || (Formatter.error(output, "Invalid ID"); return ACON::Command::Status::FAILURE)
      inbox_id = resolve_inbox(client, input, output) || return ACON::Command::Status::FAILURE
      as_json  = input.option("json", Bool)

      result = client.get_item(inbox_id: inbox_id, id: item_id)
      item   = result.data || (Formatter.error(output, "Item not found"); return ACON::Command::Status::FAILURE)

      if as_json
        output.puts item.to_json
      else
        a = item.attributes
        rows = {
          "ID"          => item.id,
          "Type"        => item._type,
          "Title"       => Formatter.attr(a, "title"),
          "Status"      => Formatter.attr(a, "status"),
          "Received"    => Formatter.attr(a, "received_at"),
          "Inbox"       => Formatter.attr(a, "inbox_id"),
          "Notes"       => Formatter.attr(a, "notes"),
        }
        width = rows.keys.map(&.size).max
        rows.each { |k, v| output.puts "  #{k.rjust(width)}  #{v}" }
      end

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

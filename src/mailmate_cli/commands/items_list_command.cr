module MailMate::CLI
  class ItemsListCommand < ACON::Command
    def initialize
      super("items")
    end

    protected def configure : Nil
      @description = "List mail items"
      self
        .add_option("inbox", "i", :optional, "Inbox ID (auto-selected if you have one inbox)", nil)
        .add_option("page", "p", :optional, "Page number", "1")
        .add_option("per-page", nil, :optional, "Items per page", "20")
        .add_option("keyword", "k", :optional, "Filter by keyword", nil)
    end

    protected def execute(input : ACON::Input::Interface, output : ACON::Output::Interface) : ACON::Command::Status
      client    = authenticated_client(output) || return ACON::Command::Status::FAILURE
      inbox_id  = resolve_inbox(client, input, output) || return ACON::Command::Status::FAILURE
      page      = input.option("page", String).to_i? || 1
      per_page  = input.option("per-page", String).to_i? || 20
      keyword   = input.option("keyword", String?)

      result = client.list_items(inbox_id: inbox_id, page: page, per_page: per_page, keyword: keyword)
      items  = result.data || [] of MailMateAPI::JsonapiResource

      if items.empty?
        output.puts "<comment>No items found.</comment>"
        return ACON::Command::Status::SUCCESS
      end

      rows = items.map do |item|
        a = item.attributes
        [
          item.id,
          Formatter.attr(a, "title"),
          Formatter.attr(a, "status"),
          Formatter.attr(a, "received_at"),
        ]
      end

      Formatter.table(output, ["ID", "Title", "Status", "Received"], rows)

      if meta = result.meta
        output.puts "<comment>Page #{meta.current_page}/#{meta.total_pages} · #{meta.total_count} total</comment>"
      end

      ACON::Command::Status::SUCCESS
    end

    private def authenticated_client(output) : MailMate::Client?
      MailMate::Client.from_credentials_file
    rescue ex
      Formatter.error(output, ex.message || "Not logged in. Run `mailmate login`.")
      nil
    end

    private def resolve_inbox(client : MailMate::Client, input : ACON::Input::Interface, output : ACON::Output::Interface) : Int32?
      if id_str = input.option("inbox", String?)
        return id_str.to_i? || (Formatter.error(output, "Invalid inbox ID"); nil)
      end

      result  = client.list_inboxes_flat
      inboxes = result.try(&.data) || [] of MailMateAPI::JsonapiResource

      case inboxes.size
      when 0
        Formatter.error(output, "No inboxes found on your account.")
        nil
      when 1
        inboxes.first.id.to_i
      else
        output.puts "<comment>Multiple inboxes found — use --inbox <id>:</comment>"
        inboxes.each { |i| output.puts "  #{i.id}  #{Formatter.attr(i.attributes, "name")}" }
        nil
      end
    end
  end
end

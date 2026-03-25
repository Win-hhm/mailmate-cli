require "athena-console"
require "mailmate_api"

require "./mailmate_cli/formatter"
require "./mailmate_cli/commands/login_command"
require "./mailmate_cli/commands/logout_command"
require "./mailmate_cli/commands/items_list_command"
require "./mailmate_cli/commands/items_info_command"
require "./mailmate_cli/commands/items_open_command"
require "./mailmate_cli/commands/account_command"

app = ACON::Application.new("mailmate", "0.1.0")
app.add(MailMate::CLI::LoginCommand.new)
app.add(MailMate::CLI::LogoutCommand.new)
app.add(MailMate::CLI::ItemsListCommand.new)
app.add(MailMate::CLI::ItemsInfoCommand.new)
app.add(MailMate::CLI::ItemsOpenCommand.new)
app.add(MailMate::CLI::AccountCommand.new)
app.run

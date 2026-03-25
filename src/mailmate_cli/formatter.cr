require "colorize"

module MailMate::CLI
  module Formatter
    # Print a simple ASCII table.
    # headers : Array(String)
    # rows    : Array(Array(String))
    def self.table(output : ACON::Output::Interface, headers : Array(String), rows : Array(Array(String))) : Nil
      widths = headers.map(&.size)
      rows.each do |row|
        row.each_with_index { |cell, i| widths[i] = {widths[i], cell.size}.max if i < widths.size }
      end

      sep = "+" + widths.map { |w| "-" * (w + 2) }.join("+") + "+"
      header_row = "|" + headers.each_with_index.map { |h, i| " #{h.ljust(widths[i])} " }.join("|") + "|"

      output.puts sep
      output.puts header_row
      output.puts sep
      rows.each do |row|
        line = "|" + row.each_with_index.map { |c, i| " #{c.ljust(widths[i])} " }.join("|") + "|"
        output.puts line
      end
      output.puts sep
    end

    def self.success(output : ACON::Output::Interface, msg : String) : Nil
      output.puts "<info>✓ #{msg}</info>"
    end

    def self.error(output : ACON::Output::Interface, msg : String) : Nil
      output.puts "<error>✗ #{msg}</error>"
    end

    def self.attr(value : JSON::Any, key : String, fallback : String = "—") : String
      value[key]?.try(&.as_s?) ||
        value[key]?.try(&.as_i?.try(&.to_s)) ||
        fallback
    end
  end
end

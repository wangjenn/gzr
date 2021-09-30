# The MIT License (MIT)

# Copyright (c) 2018 Mike DeAngelo Looker Data Sciences, Inc.

# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
# the Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
# FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# frozen_string_literal: true

require_relative '../../command'
require_relative '../../modules/user'
require 'tty-table'

module Gzr
  module Commands
    class User
      class Ls < Gzr::Command
        include Gzr::User
        def initialize(options)
          super()
          @options = options
        end

        def execute(input: $stdin, output: $stdout)
          say_warning(@options) if @options[:debug]
          with_session do
            f = @options[:fields]
            f += ',credentials_email,credentials_totp,credentials_google,credentials_saml,credentials_oidc' if @options[:"last-login"]
            data = query_all_users(f, "id")
            begin
              say_ok "No users found"
              return nil
            end unless data && data.length > 0

            table_hash = Hash.new
            fields = field_names(@options[:fields])
            fields.unshift 'last_login' if @options[:"last-login"]
            table_hash[:header] = fields unless @options[:plain]
            expressions = fields.collect { |fn| field_expression(fn) }
            table_hash[:rows] = data.map do |row|
              expressions.collect do |e|
                next(eval "row.#{e}") unless (e == 'last_login')
                [
                  row.credentials_email()&.logged_in_at(),
                  (row.credentials_totp()&.logged_in_at()),
                  (row.credentials_google()&.logged_in_at()),
                 (row.credentials_saml()&.logged_in_at()),
                  (row.credentials_oidc()&.logged_in_at())
                ].compact.max
              end
            end
            table = TTY::Table.new(table_hash)
            alignments = fields.collect do |k|
              (k =~ /id$/) ? :right : :left
            end
            begin
              if @options[:csv] then
                output.puts render_csv(table)
              else
                output.puts table.render(if @options[:plain] then :basic else :ascii end, alignments: alignments, width: @options[:width] || TTY::Screen.width)
              end
            end if table
          end
        end
      end
    end
  end
end

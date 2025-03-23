# Copyright 2025 Luis Lavena
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require "http/server/handler"

require "./custom_web_socket"

class Vite
  class ProxyHandler
    include HTTP::Handler

    VITE_WS_PROTOCOLS = {"vite-hmr", "vite-ping"}

    @vite : Vite

    def initialize(@vite)
    end

    def call(context : HTTP::Server::Context)
      return call_next(context) unless vite_request?(context.request)
      return proxy_websocket(context) if websocket_request?(context.request)

      proxy_http(context)
    end

    # Client (Browser) <-> Server (Vite)
    private def bind_web_sockets(client, server)
      # PING: Client -> Server, PONG: Server -> Client
      client.on_ping do |message|
        server.ping(message)
      end
      server.on_pong do |message|
        client.pong(message)
      end

      # PING: Server -> Client, PONG: Client -> Server
      server.on_ping do |message|
        client.ping(message)
      end
      client.on_pong do |message|
        server.pong(message)
      end

      # MESSAGE: Client -> Server & back
      client.on_message do |message|
        server.send(message)
      end
      server.on_message do |message|
        client.send(message)
      end

      # CLOSE: Client -> Server & back
      client.on_close do |code, message|
        server.close(code, message)
      end
      server.on_close do |code, message|
        client.close(code, message)
      end
    end

    private def check_vite_server_running(context)
      return true if @vite.dev_server_running?

      context.response.respond_with_status(
        :service_unavailable,
        "Vite development server is not running"
      )

      false
    end

    private def proxy_http(context)
      return unless check_vite_server_running(context)

      client = HTTP::Client.new("localhost", @vite.port)
      headers = context.request.headers.dup

      # Spoof localhost to use default Vite configuration
      headers["Host"] = "localhost"

      client.exec(context.request.method, context.request.path, headers) do |response|
        context.response.status_code = response.status_code
        context.response.headers.merge!(response.headers)

        if response.body_io
          IO.copy(response.body_io, context.response)
        end
      end
    end

    # adapted from HTTP::WebSocketHandler to handle WebSocket protocols
    # Ref: https://github.com/crystal-lang/crystal/blob/master/src/http/server/handlers/websocket_handler.cr
    private def proxy_websocket(context)
      return unless check_vite_server_running(context)

      response = context.response

      version = context.request.headers["Sec-WebSocket-Version"]?
      unless version == HTTP::WebSocket::Protocol::VERSION
        response.status = :upgrade_required
        response.headers["Sec-WebSocket-Version"] = HTTP::WebSocket::Protocol::VERSION
        return
      end

      key = context.request.headers["Sec-WebSocket-Key"]?
      unless key
        response.respond_with_status(:bad_request)
        return
      end

      # Process WebSocket sub-protocol
      selected_protocol = nil
      if client_protocol_header = context.request.headers["Sec-WebSocket-Protocol"]?
        # Split and trim protocols (could be comma-separated or multiple headers)
        client_protocols = client_protocol_header.split(',').map(&.strip)

        if !client_protocols.empty?
          selected_protocol = client_protocols.find { |p| VITE_WS_PROTOCOLS.includes?(p) }

          unless selected_protocol
            response.respond_with_status(:bad_request)
            return
          end
        end
      end

      accept_code = HTTP::WebSocket::Protocol.key_challenge(key)

      response.status = :switching_protocols
      response.headers["Upgrade"] = "websocket"
      response.headers["Connection"] = "Upgrade"
      response.headers["Sec-WebSocket-Accept"] = accept_code

      # add the selected protocol to our response
      if selected_protocol
        response.headers["Sec-WebSocket-Protocol"] = selected_protocol
      end

      response.upgrade do |io|
        server_headers = HTTP::Headers.new
        if selected_protocol
          server_headers["Sec-WebSocket-Protocol"] = selected_protocol
        end

        ws_server = CustomWebSocket.new(
          host: "localhost",
          port: @vite.port,
          path: "#{context.request.path}?#{context.request.query}",
          headers: server_headers,
        )

        ws_client = CustomWebSocket.new(io, sync_close: false)
        bind_web_sockets(ws_client, ws_server)

        spawn { ws_server.run }

        ws_client.run
      end
    end

    private def vite_request?(request) : Bool
      request.path.starts_with?("/vite-dev/")
    end

    private def websocket_request?(request) : Bool
      return false unless upgrade = request.headers["Upgrade"]?
      return false unless upgrade.compare("websocket", case_insensitive: true) == 0

      request.headers.includes_word?("Connection", "Upgrade")
    end
  end
end

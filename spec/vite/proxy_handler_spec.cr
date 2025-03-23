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

require "../spec_helper"

describe Vite::ProxyHandler do
  context "(dealing with non-Vite requests)" do
    it "skips the request to the next middleware" do
      handler = Vite::ProxyHandler.new(Vite.new)

      next_called = false
      next_handler = HTTP::Handler::HandlerProc.new do |context|
        next_called = true
        context.response.status_code = 200
        context.response.print("next handler")
      end
      handler.next = next_handler

      # GET /any/path
      request = HTTP::Request.new("GET", "/any/path")
      response = HTTP::Server::Response.new(IO::Memory.new)
      context = HTTP::Server::Context.new(request, response)

      handler.call(context)
      next_called.should be_true
    end
  end

  context "(dealing with Vite requests)" do
    describe "when Vite is not running" do
      it "returns service not available" do
        vite = StubbedVite.new
        vite.dev_server_running_stub = false

        handler = Vite::ProxyHandler.new(vite)

        request = HTTP::Request.new("GET", "/vite-dev/some-file.js")
        io = IO::Memory.new
        response = HTTP::Server::Response.new(io)
        context = HTTP::Server::Context.new(request, response)

        handler.call(context)
        response.close

        response.status_code.should eq(503) # Service Unavailable

        io.rewind
        response_text = io.gets_to_end
        response_text.should contain("Vite development server is not running")
      end
    end
  end
end

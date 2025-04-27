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

require "json"

class Vite
  # :nodoc:
  class ManifestEntry
    include JSON::Serializable

    property file : String
    property name : String?
    property src : String

    property css : Array(String)?
  end

  getter port : Int32
  getter source_path : String

  # Internals
  @dev_server_running : Bool = false
  @last_check_at : Time = Time.unix(0)

  alias Manifest = Hash(String, ManifestEntry)

  @manifest_path : String = "public/build/manifest.json"
  @manifest : Manifest? = nil

  def initialize(@port = 5173, @source_path = "src/frontend")
    load_manifest
  end

  # Returns the Vite client script tag when in development mode
  def client_tag : String
    return "" unless dev_server_running?

    %(<script type="module" src="/vite-dev/@vite/client"></script>)
  end

  # Returns a pre-configured instance Proxy Handler for development
  def dev_handler
    ProxyHandler.new(self)
  end

  # FIXME: perhaps use .monotonic instead?
  def dev_server_running? : Bool
    current_time = Time.utc

    # Return cached result if it's less than 1 second old
    if (current_time - @last_check_at) < 1.second
      return @dev_server_running
    end

    @last_check_at = current_time

    begin
      # Try to establish a TCP connection to verify if server is running
      TCPSocket.new("localhost", @port, connect_timeout: 0.3.seconds).close
      @dev_server_running = true
    rescue ex : Socket::Error | IO::TimeoutError
      # Connection failed, server is not running
      @dev_server_running = false
    end

    @dev_server_running
  end

  def script_tag(path : String, preload : Bool = false) : String
    full_path = expand_path(path)

    if @manifest.nil? || dev_server_running?
      return %(<script type="module" src="/vite-dev/#{full_path}"></script>)
    end

    entry = @manifest.try &.[full_path]?
    return "" unless entry

    tag = %(<script type="module" src="/build/#{entry.file}"></script>)

    return tag unless preload

    # Generate style tags if CSS is available
    if css = entry.css
      tags = String.build do |str|
        css.each do |css_file|
          str << %(<link rel="stylesheet" href="/build/#{css_file}" />)
        end

        # append at last our script tag
        str << tag
      end

      return tags
    end

    tag
  end

  def style_tag(path : String) : String
    full_path = expand_path(path)

    if @manifest.nil? || dev_server_running?
      return %(<link rel="stylesheet" href="/vite-dev/#{full_path}">)
    end

    entry = @manifest.try &.[full_path]?
    return "" unless entry

    return %(<link rel="stylesheet" href="/build/#{entry.file}">)
  end

  private def expand_path(path : String) : String
    if path.starts_with?("@/")
      path.sub("@", @source_path)
    else
      File.join(@source_path, path)
    end
  end

  private def load_manifest
    return unless File.exists?(@manifest_path)

    @manifest = Manifest.from_json(File.read(@manifest_path))
  end
end

require "./vite/proxy_handler"

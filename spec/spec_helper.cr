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

require "spec"
require "../src/vite"

class StubbedVite < Vite
  property? dev_server_running_stub : Bool = false

  def dev_server_running?
    @dev_server_running_stub
  end
end

class FixturedVite < Vite
  @manifest_path : String = "#{__DIR__}/fixtures/manifest.json"
end

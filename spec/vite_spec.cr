require "./spec_helper"

require "socket"

describe Vite do
  describe "#new" do
    context "(port)" do
      it "uses Vite's default port (5173)" do
        vite = Vite.new
        vite.port.should eq(5173)
      end

      it "accepts custom port" do
        vite = Vite.new(port: 3000)
        vite.port.should eq(3000)
      end
    end

    context "(source_path)" do
      it "defaults to src/frontend" do
        vite = Vite.new
        vite.source_path.should eq("src/frontend")
      end

      it "accepts a custom path" do
        vite = Vite.new(source_path: "resources/js")
        vite.source_path.should eq("resources/js")
      end
    end
  end

  describe "#dev_server_running?" do
    it "returns true if can connect to specified server" do
      # fake port to avoid clash with running Vite
      mock_server = TCPServer.new("localhost", 55173)
      vite = Vite.new(port: 55173)

      result = vite.dev_server_running?
      result.should be_true
      mock_server.close
    end

    it "returns false if cannot connect to server" do
      vite = Vite.new(port: 90909)

      result = vite.dev_server_running?
      result.should be_false
    end
  end

  describe "#client_tag" do
    it "returns empty when dev server is not running" do
      vite = StubbedVite.new
      vite.dev_server_running_stub = false

      vite.client_tag.should eq("")
    end

    it "returns script tag when dev server is running" do
      vite = StubbedVite.new
      vite.dev_server_running_stub = true

      vite.client_tag.should eq(%(<script type="module" src="/vite-dev/@vite/client"></script>))
    end
  end

  context "(expanding @/ prefix)" do
    it "expands prefix in script_tag" do
      vite = StubbedVite.new(source_path: "source/path")
      vite.dev_server_running_stub = true

      vite.script_tag("@/test.js").should contain("/vite-dev/source/path/test.js")
    end

    it "expands prefix in style_tag" do
      vite = StubbedVite.new(source_path: "source/path")
      vite.dev_server_running_stub = true

      vite.style_tag("@/styles/test.css").should contain("/vite-dev/source/path/styles/test.css")
    end
  end

  context "with a manifest present" do
    describe "#script_tag" do
      it "returns the asset from the build directory" do
        vite = FixturedVite.new
        vite.script_tag("@/main.js").should contain("/build/assets/main-123abc.js")
      end

      it "includes the CSS dependencies when preloading" do
        vite = FixturedVite.new
        output = vite.script_tag("@/main.js", preload: true)
        output.should contain("/build/assets/main-456def.css")
        output.should contain("/build/assets/main-123abc.js")
      end

      it "does not include styles when none is defined for the asset" do
        vite = FixturedVite.new
        output = vite.script_tag("@/secondary.js", preload: true)
        output.should contain("/build/assets/secondary-456def.js")
        output.should_not contain(".css")
      end
    end

    describe "#style_tag" do
      it "returns the asset from the build directory" do
        vite = FixturedVite.new
        vite.style_tag("@/style.css").should contain("/build/assets/style-789ghi.css")
      end
    end
  end

  describe "#dev_handler" do
    it "returns a pre-initialized instance of ProxyHandler" do
      vite = Vite.new
      handler = vite.dev_handler

      handler.should be_a(Vite::ProxyHandler)
    end
  end
end

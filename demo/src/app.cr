require "http/server"
require "vite"

vite = Vite.new

handlers = [
  HTTP::LogHandler.new,
  HTTP::StaticFileHandler.new("public", directory_listing: false),
  # (only in development)
  vite.dev_handler,
]

server = HTTP::Server.new(handlers) do |context|
  context.response.content_type = "text/html"
  ECR.embed "#{__DIR__}/views/index.html.ecr", context.response
end

Process.on_terminate do
  puts "Shutdown requested."
  server.close
end

ipaddr = server.bind_tcp("0.0.0.0", 8080)

puts "Listening on http://#{ipaddr.address}:#{ipaddr.port}/"
server.listen

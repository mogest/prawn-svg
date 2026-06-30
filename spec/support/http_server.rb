require 'socket'

module Support
  # Serves canned raw HTTP responses keyed by request path, recording each path requested.
  def with_http_server(responses)
    server = TCPServer.new('127.0.0.1', 0)
    requested = []
    thread = Thread.new do
      loop do
        client = server.accept
        path = client.gets.split[1]
        nil while client.gets != "\r\n"
        requested << path
        client.write(responses.fetch(path, "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"))
        client.close
      end
    end

    yield "http://127.0.0.1:#{server.addr[1]}", requested
  ensure
    thread&.kill
    server&.close
  end

  def raw_http_response(status, body = '', headers = {})
    headers = { 'Content-Length' => body.bytesize, 'Connection' => 'close' }.merge(headers)
    "HTTP/1.1 #{status}\r\n#{headers.map { |k, v| "#{k}: #{v}\r\n" }.join}\r\n#{body}"
  end
end

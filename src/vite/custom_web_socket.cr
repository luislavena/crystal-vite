require "http/web_socket"

class Vite
  # :nodoc:
  #
  # Replaces `#run` until we can override `ping?` behavior
  # Ref: https://github.com/crystal-lang/crystal/pull/15545
  class CustomWebSocket < HTTP::WebSocket
    def run : Nil
      loop do
        begin
          info = @ws.receive(@buffer)
        rescue
          @on_close.try &.call(CloseCode::AbnormalClosure, "")
          @closed = true
          break
        end

        case info.opcode
        in .ping?
          @current_message.write @buffer[0, info.size]
          if info.final
            message = @current_message.to_s
            @on_ping.try &.call(message)
            @current_message.clear
          end
        in .pong?
          @current_message.write @buffer[0, info.size]
          if info.final
            @on_pong.try &.call(@current_message.to_s)
            @current_message.clear
          end
        in .text?
          @current_message.write @buffer[0, info.size]
          if info.final
            @on_message.try &.call(@current_message.to_s)
            @current_message.clear
          end
        in .binary?
          @current_message.write @buffer[0, info.size]
          if info.final
            @on_binary.try &.call(@current_message.to_slice)
            @current_message.clear
          end
        in .close?
          @current_message.write @buffer[0, info.size]
          if info.final
            @current_message.rewind

            if @current_message.size >= 2
              code = @current_message.read_bytes(UInt16, IO::ByteFormat::NetworkEndian).to_i
              code = CloseCode.new(code)
            else
              code = CloseCode::NoStatusReceived
            end
            message = @current_message.gets_to_end

            @on_close.try &.call(code, message)
            close

            @current_message.clear
            break
          end
        in .continuation?
        end
      end
    end
  end
end

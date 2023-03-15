module Helpers
  # Returns the number of decimal digits inside the given number.
  #
  # Only works for non-negative integers.
  protected def self.number_digits(number : Int32) : Int32
    ret = 0
    while number > 0
      number //= 10
      ret += 1
    end
    ret
  end

  protected def self.html_escape_from_utf8_slice_to_io(string : Bytes, io : IO) : Nil
    last_copy_at : Int32 = 0
    string.each_with_index do |byte, index|
      str = case byte
            when '&' then "&amp;"
            when '<' then "&lt;"
            when '>' then "&gt;"
            when '"' then "&quot;"
            when '\'' then "&#39;"
            else
              nil
            end
      if str
        io.write_string(string[last_copy_at, index &- last_copy_at])
        last_copy_at = index &+ 1
        io << str
      end
    end
    io.write_string(string[last_copy_at, string.size &- last_copy_at])
  end

  # Streams the file from the given filepath into the io.
  #
  # The method first skips most code before the errorneous code as it is irrelevant for the report.
  # Then, the
  #
  # The method is written in a quite low-level manner and could be hard to understand.
  def self.stream_file_to_html(
    io : IO,
    filepath : String,
    begin_line : Int32,
    begin_column : Int32,
    end_line : Int32,
    end_column : Int32,

  ) : Nil
    buffer = uninitialized UInt8[IO::DEFAULT_BUFFER_SIZE]
    current_line : Int32 = 1
    char_pos_current_line : Int32 = 1
    used_digits : Int32 = Math.max(number_digits(begin_line), number_digits(end_line))
    last_char_was_newline : Bool = true

    File.open(filepath) do |file|
      while true
        read_bytes : Int32 = file.read_utf8(Slice.new(buffer.to_unsafe, IO::DEFAULT_BUFFER_SIZE))
        break if read_bytes == 0
        buffer_pos : Int32 = 0

        is_finished : Bool = false
        while buffer_pos < read_bytes
          if current_line > (end_line + 1)
            is_finished = true
            break
          end

          if last_char_was_newline
            if begin_line < current_line <= end_line
              io << "</mark>"
            end

            if current_line >= begin_line && current_line > 1
              io << "</div>"
            end

            if current_line >= (begin_line - 1)
              io << "<div><span class=\"text-dimmed\">"
              (used_digits - number_digits(current_line)).times do
                io << ' '
              end
              io << current_line
              io << "</span>"
              io << "  "

              if begin_line < current_line <= end_line
                io << "<mark class=\"text-danger\">"
              end
            end
          end

          tmp_buffer_pos = Slice.new(buffer.to_unsafe + buffer_pos, read_bytes - buffer_pos).index('\n'.ord.to_u8!).try { |index| index + buffer_pos }

          if current_line == begin_line && char_pos_current_line <= begin_column
            search_pos = buffer_pos
            while true
              break if char_pos_current_line == begin_column

              byte = buffer[search_pos]
              search_pos += 1
              search_pos += 1 if byte >= 192
              search_pos += 1 if byte >= 224
              search_pos += 1 if byte >= 240
              char_pos_current_line += 1

              if tmp_buffer_pos && tmp_buffer_pos <= search_pos
                search_pos = tmp_buffer_pos
                break
              end

              if search_pos > read_bytes
                file.skip(search_pos - read_bytes)
                search_pos = read_bytes
                break
              end
            end

            html_escape_from_utf8_slice_to_io(Slice.new(buffer.to_unsafe + buffer_pos, search_pos - buffer_pos), io)
            buffer_pos = search_pos
            io << "<mark class=\"text-danger\">" if char_pos_current_line == begin_column
          end

          if current_line == end_line && char_pos_current_line <= (end_column + 1)
            search_pos = buffer_pos
            while true
              break if char_pos_current_line == (end_column + 1)

              byte = buffer[search_pos]
              search_pos += 1
              search_pos += 1 if byte >= 192
              search_pos += 1 if byte >= 224
              search_pos += 1 if byte >= 240
              char_pos_current_line += 1

              if tmp_buffer_pos && tmp_buffer_pos <= search_pos
                search_pos = tmp_buffer_pos
                break
              end

              if search_pos > read_bytes
                file.skip(search_pos - read_bytes)
                search_pos = read_bytes
                break
              end
            end

            html_escape_from_utf8_slice_to_io(Slice.new(buffer.to_unsafe + buffer_pos, search_pos - buffer_pos), io)
            buffer_pos = search_pos
            io << "</mark>" if char_pos_current_line == (end_column + 1)
          end

          writeable_bytes = (tmp_buffer_pos ? tmp_buffer_pos + 1 : read_bytes) - buffer_pos
          if current_line >= (begin_line - 1)
            html_escape_from_utf8_slice_to_io(Slice.new(buffer.to_unsafe + buffer_pos, writeable_bytes), io)
          end

          buffer_pos += writeable_bytes
          break unless tmp_buffer_pos
          last_char_was_newline = true
          current_line += 1
          char_pos_current_line = 1
        end

        break if is_finished
      end
    end

    io << "</div>" if begin_line <= current_line <= (end_line + 1)

    # if (char_pos_current_line > 0
    #   (
    #     (begin_line < current_line < end_line) ||
    #     (end_line == current_line && char_pos_current_line < end_column && (begin_line != end_line || char_pos_current_line > begin_column))
    #     (begin_line == current_line && char_pos_current_line > begin_column && (begin_line != end_line || char_pos_current_line < end_column))
    #   )
    # )
    #   io << "</mark>"
    # end
  end
end

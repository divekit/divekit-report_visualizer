module CLI
  module Context
    abstract def init_context : Nil
    abstract def parse_option(option : String, &read_value : -> String?) : Nil
    abstract def cli_usage : String

    private macro extended
      include CLI::Macros

      # :nodoc:
      HEADERS = [] of Nil

      # :nodoc:
      OPTIONS = [] of Nil

      # :nodoc:
      FOOTERS = [] of Nil

      # :nodoc:
      def self.init_context : Nil
      end

      # :nodoc:
      def self.parse_option(option : String, &read_value : -> String?) : Nil
        raise "Unknown argument \"#{option}\" for current file context"
      end

      # :nodoc:
      def self.cli_usage : String
        {% verbatim do %}
          "#{ {{ HEADERS.first }} }\n#{ {{ OPTIONS.empty? ? "  None" : OPTIONS.join('\n') }} }#{ {{ FOOTERS.first }} }"
        {% end %}
      end
    end
  end

  module Macros
    # A constant with exactly 31 space characters, used in the `.option` macro.
    private PADDING = "                               "

    macro option(long_flag, description, &block)
      option(nil, {{long_flag}}, {{description}}) {{ block }}
    end

    macro option(short_flag, long_flag, description, &block)
      {% short_flag.raise "Short flags need the prefix \"-\"" if short_flag && !short_flag.starts_with? "-" %}
      {% long_flag.raise "Long flags need the prefix \"--\"" unless long_flag.starts_with? "--" %}
      {% short_flag.raise "Invalid flag string" if short_flag && short_flag.empty? %}
      {% long_flag.raise "Invalid flag string" if long_flag.empty? %}
      {% short_flag_parts = !short_flag || short_flag.tr(" ", "=").split('=') %}
      {% long_flag_parts = long_flag.tr(" ", "=").split('=') %}

      {% var_name = long_flag_parts[0][2..].id %}
      {% wants_arg = long_flag_parts.size == 2 %}

      {% if short_flag %}
        {% OPTIONS << "  #{short_flag.id}, #{long_flag.id}#{PADDING[..(29 - long_flag.size - short_flag.size)].id} #{description.id}".id %}
      {% else %}
        {% OPTIONS << "  #{long_flag.id}#{PADDING[..(31 - long_flag.size)].id} #{description.id}".id %}
      {% end %}

      def self.parse_option(option %tmp : String, &block : -> String) : Nil
        if %tmp == {{ long_flag_parts[0] }} {% if short_flag %} || %tmp == {{ short_flag_parts[0] }} {% end %}
          {% if wants_arg %}
            {% block.raise "expected exactly one block parameter" unless block.args.size == 1 %}
            {{ block.args.first }} = yield
            {{ yield }}
          {% else %}
            {{ yield }}
          {% end %}
          return
        end
        previous_def { yield }
      end
    end

    macro header(text)
      {% HEADERS << text %}
    end

    macro footer(text)
      {% FOOTERS << text %}
    end
  end

  def self.parse(
    argv : Enumerable(String) = ARGV,
    *,
    default_context : CLI::Context,
    find_context_callback : Proc(String, CLI::Context),
    context_finished_callback : Proc(CLI::Context, String, Nil)
  )
    default_context.init_context
    context : CLI::Context = default_context
    context_arg : String? = nil
    arg_index = 0

    # Parse command-line arguments
    #
    # Note that the while condition is `arg_index <= argv.size` - the body of the while loop
    # will be executed for each element inside argv and once at the end using `nil`
    while arg_index <= argv.size
      arg = argv[arg_index]?
      is_arg = arg ? arg.starts_with?("-") : false
      arg_index += 1

      if is_arg && arg
        # Here, arguments (--arg value, -h, --test=TEST) are parsed.

        parts = arg.split('=', 2)
        consumed_value = false

        context.parse_option(parts.first) do
          consumed_value = true
          if parts.size == 1
            arg_value = argv[arg_index]?
            arg_index += 1
            raise "Argument #{parts.first} requires a value" if !arg_value || arg_value.starts_with? "-"
          else
            arg_value = parts[1]
          end
          arg_value
        end

        raise "Argument #{parts.first} does not accept value" if parts.size == 2 && !consumed_value
      else
        # A argument has been found which is not a `--argument`.

        context_finished_callback.call(context, context_arg) if context_arg

        if arg
          context = find_context_callback.call(arg)
          context.init_context
          context_arg = arg
        end
      end
    end
  rescue ex
    STDERR.print "ERROR: #{ex.message}\n\n"
    STDERR.print default_context.cli_usage
    exit(1)
  end
end

require "ecr/macros"
require "html"
require "option_parser"

require "./reports"

module App
  # Parses cli options and executes the visualization
  def self.run(argv = ARGV)
    commit : String = "local"
    commit_url : String? = nil
    commit_tz : Time = Time.local
    output_path : String = "public"
    report_paths = [] of Path

    parser = OptionParser.parse(argv) do |parser|
      parser.banner = "Usage: divekit-rv [arguments] <report-path> <report-path>..."
      parser.on("-c HASH", "--commit=HASH", "Specifies the displayed commit hash (default: \"local\")") { |hash| commit = hash }
      parser.on("-u URI", "--commit-url=URI", "Specifies the link to the current commit (default: none)") { |url| commit_url = url }
      parser.on("-t TIME", "--commit-time=TIME", "Specifies the timestamp of the current commit, in ISO 8601 format (default: current local time)") { |time| commit_tz = Time.parse_iso8601(time) }
      parser.on("-o PATH", "--output=PATH", "Specifies the path to deploy to (default: \"public\")") { |path| output_path = path }
      parser.on("-h", "--help", "Show this help") do
        puts parser
        exit
      end

      parser.unknown_args do |options, _|
        options.each do |option|
          report_paths << Path[option]
        end
      end

      parser.invalid_option do |flag|
        STDERR.puts "ERROR: #{flag} is not a valid option."
        STDERR.puts parser
        exit(1)
      end

      parser.missing_option do |flag|
        STDERR.puts "ERROR: #{flag} requires a value."
        STDERR.puts parser
        exit(1)
      end
    end

    # From this point onwards, all options have been parsed and evaluated.
    # Now the reports can be parsed.

    reports = [] of Report
    total_report_count = 0
    successful_report_count = 0

    report_paths.each do |path|
      report_class = case ext = path.extension
                     when ".xml"  then Report::Surefire
                     when ".json" then Report::Custom
                     else
                       raise ArgumentError.new("Invalid file extension for report: #{ext}")
                     end
      report_class.from_path(path).each do |report|
        reports << report
        total_report_count += 1
        successful_report_count += 1 if report.status.success?
      end
    end

    # Finally, deploy the visualization.
    deploy(
      output_path: Path[output_path],
      reports_by_category: reports.group_by { |report| report.category },
      total_report_count: total_report_count,
      successful_report_count: successful_report_count,
      commit_name: commit,
      commit_url: commit_url,
      commit_tz: commit_tz
    )
  end

  # This method deploys the visualization.
  # Here, the output directory is created, all static files are copied and the ECR files are rendered.
  # This is done using macros so the `template` directory does not need to be shipped.
  #
  # FIXME: The macro currently uses shell commands to fetch the template. This is hacky and does not work on windows.
  def self.deploy(*,
                  output_path : Path,
                  reports_by_category : Hash(String, Array(Report)),
                  total_report_count : Int32,
                  successful_report_count : Int32,
                  commit_name : String,
                  commit_url : String?,
                  commit_tz : Time)
    Dir.mkdir_p(output_path)

    {% begin %}
      # Copy all static files.
      {% for path in system("cd template && find . -type f -not -name \"*.ecr\" -maxdepth 1").lines %}
        File.write(output_path / {{ path }}, {{ read_file("template/#{path.id}") }})
      {% end %}

      # Render all ECR files.
      {% for path in system("cd template && find . -type f -name \"*.ecr\" -maxdepth 1").lines %}
        File.open(output_path / {{ path[..-5] }}, "w") do |io|
          ECR.embed({{ "template/#{path.id}" }}, io)
        end
      {% end %}
    {% end %}
  end
end

App.run

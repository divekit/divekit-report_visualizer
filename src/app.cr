require "ecr/macros"
require "html"
require "option_parser"

require "./report"

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

    if report_paths.empty?
      STDERR.puts "ERROR: At least one report is required."
      STDERR.puts parser
      exit(1)
    end

    # From this point onwards, all options have been parsed and evaluated.
    # Now the reports can be parsed.

    reports = [] of Report
    total_report_count = 0
    successful_report_count = 0
    report_paths.each do |path|
      begin
        parse_reports(path).each do |report|
          reports << report
          total_report_count += 1
          successful_report_count += 1 if report.status.success?
        end
      rescue ex
        STDERR.puts "ERROR: #{ex.message}"
        exit(1)
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

  # This method parses the report from the given paths and returns an array of parsed reports.
  #
  # The method matches the report type using its filename.
  def self.parse_reports(path : Path) : Array(Report)
    # For each `Report` subclass the `.is_candidate?` method is executed.
    # This method checks if the filepath implies it could possibly be this type of report.
    # For example, a surefire report starts with "TEST-" and ends with ".xml".
    #
    # If no report subclass matches the filename, it is an invalid report.
    # If multiple report subclasses match the filename,
    # the report visualizer has multiple reports which are incompatible.
    # In both cases, the tool immediately stops executing.

    candidate_count = 0
    last_candidate : Report.class | Nil = nil

    {% begin %}
      {% for type in Report.subclasses %}
        if {{type}}.is_candidate?(path.basename)
          candidate_count += 1
          last_candidate = {{type}}
        end
      {% end %}
    {% end %}

    raise ArgumentError.new("Could not find a candidate for report \"#{path}\"") unless last_candidate
    raise ArgumentError.new("Ambiguous report \"#{path}\" has multiple candidates") if candidate_count > 1

    last_candidate.from_path(path)
  end

  # This method deploys the visualization.
  # Here, the output directory is created, all static files are copied and the ECR files are rendered.
  # This is done using macros so the `template` directory does not need to be shipped.
  def self.deploy(*,
                  output_path : Path,
                  reports_by_category : Hash(String, Array(Report)),
                  total_report_count : Int32,
                  successful_report_count : Int32,
                  commit_name : String,
                  commit_url : String?,
                  commit_tz : Time)
    Dir.mkdir_p(output_path)

    # Render all ECR files and copy all static files.
    {% begin %}
      {% for file in run("./macros/list_files.cr", "template").lines %}
        {% if file.ends_with?(".ecr") %}
          File.open(output_path / {{ file[..-5] }}, "w") do |io|
            ECR.embed({{ "template/#{file.id}" }}, io)
          end
        {% else %}
          File.write(output_path / {{ file }}, {{ read_file("template/#{file.id}") }})
        {% end %}
      {% end %}
    {% end %}
  end
end

App.run

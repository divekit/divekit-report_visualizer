require "ecr/macros"
require "html"
require "./util/*"
require "./report"

module App
  extend CLI::Context

  VERSION = "0.2.1"

  @@read_context = false
  @@incomplete = false

  @@commit : String = "local"
  @@commit_url : String? = nil
  @@commit_tz : Time = Time.local
  @@output_path : String = "public"
  @@reports = [] of Report

  header <<-TXT
  Divekit Report Visualizer #{VERSION} #{{{ `git log --pretty=format:'[%h] (%cs)' -n 1`.stringify }}}
  Usage: divekit-rv [global arguments] <report-path> [report arguments] <report-path> [report arguments] ...

  Global arguments (affects whole program instead of just one file):
  TXT

  option "-c HASH", "--commit=HASH", "Specifies the displayed commit hash (default: \"local\")" { |hash| @@commit = hash }
  option "-u URI", "--commit_url=URI", "Specifies the link to the current commit (default: none)" { |url| @@commit_url = url }
  option "-o PATH", "--output=PATH", "Specifies the path to deploy to (default: \"public\")" { |path| @@output_path = path }
  option "-t TIME", "--commit_time=TIME",
    "Specifies the timestamp of the current commit, in ISO 8601 format (default: current local time)" do |time|
    @@commit_tz = Time.parse_iso8601(time)
  end
  option "-h", "--help", "Show this help"

  {% begin %}
    footer "{% for type in Report.subclasses %}\n\n#{{{type}}.cli_usage}{% end %}\n"
  {% end %}

  # Parses cli options and executes the visualization
  def self.run(argv = ARGV)
    CLI.parse(
      default_context: App.as(CLI::Context),
      find_context_callback: ->find_report_type(String),
      context_finished_callback: ->context_finished_callback(CLI::Context, String)
    )

    unless @@read_context
      STDERR.print "ERROR: At least one report is required.\n\n"
      STDERR.print App.cli_usage
      exit(1)
    end

    # From this point onwards, all options have been parsed and evaluated.
    # Now the reports can be parsed.

    # Finally, deploy the visualization.
    deploy(
      output_path: Path[@@output_path],
      reports_by_category: @@reports.group_by { |report| report.category },
      reports: @@reports,
      commit_name: @@commit,
      commit_url: @@commit_url,
      commit_tz: @@commit_tz,
      incomplete: @@incomplete
    )
  end

  def self.context_finished_callback(context : CLI::Context, argument : String) : Nil
    @@read_context = true

    unless File.file?(argument)
      @@incomplete = true
      STDERR.puts "WARN: File #{argument} does not exist!"
      return
    end

    context.as(Report.class).from_path(Path[argument]).each do |report|
      @@reports << report
    end
  end

  def self.find_report_type(path : String) : CLI::Context
    # For each `Report` subclass the `.is_candidate?` method is executed.
    # This method checks if the filepath implies it could possibly be this type of report.
    # For example, a surefire report starts with "TEST-" and ends with ".xml".
    #
    # If no report subclass matches the filename, it is an invalid report.
    # If multiple report subclasses match the filename,
    # the report visualizer has multiple reports which are incompatible.
    # In both cases, the tool immediately stops executing.

    path = Path[path]
    candidate_count = 0
    last_candidate : CLI::Context | Nil = nil
    basename = path.basename

    {% begin %}
      {% for type in Report.subclasses %}
        if {{type}}.is_candidate?(basename)
          candidate_count += 1
          last_candidate = {{type}}.as(CLI::Context)
        end
      {% end %}
    {% end %}

    raise ArgumentError.new("Could not find a candidate for report \"#{path}\"") unless last_candidate
    raise ArgumentError.new("Ambiguous report \"#{path}\" has multiple candidates") if candidate_count > 1

    last_candidate
  end

  # This method deploys the visualization.
  # Here, the output directory is created, all static files are copied and the ECR files are rendered.
  # This is done using macros so the `template` directory does not need to be shipped.
  def self.deploy(*,
                  output_path : Path,
                  reports_by_category : Hash(String, Array(Report)),
                  reports : Array(Report),
                  commit_name : String,
                  commit_url : String?,
                  commit_tz : Time,
                  incomplete : Bool)
    Dir.mkdir_p(output_path)

    # Render all ECR files and copy all static files.
    {% begin %}
      {% ecr_file_extension_size = flag?("no_minify") ? 5 : 9 %}
      {% for file in run("./macros/list_files.cr", "template").lines %}
        {% if file.ends_with?(".ecr") %}
          {% if flag?("no_minify") != file.ends_with?(".min.ecr") && !file.starts_with?("$") %}
            File.open(output_path / {{ file[..-ecr_file_extension_size] }}, "w") do |io|
              ECR.embed({{ "template/#{file.id}" }}, io)
            end
          {% end %}
        {% elsif !file.ends_with?(".ignore") %}
          File.write(output_path / {{ file }}, {{ read_file("template/#{file.id}") }})
        {% end %}
      {% end %}
    {% end %}
  end
end

App.run

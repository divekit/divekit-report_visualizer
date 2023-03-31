require "json"

# The json-format output from the PMD source code analyzer.
class Report::PMD < Report
  record Document, formatVersion : Int32, pmdVersion : String, timestamp : Time, files : Array(ReportFile) do
    include JSON::Serializable
  end

  # An entry in the `Report#files` array.
  record ReportFile, filename : String, violations : Array(Violation) do
    include JSON::Serializable
  end

  # A rule violation inside a `File#violations` array.
  record Violation, beginline : Int32, begincolumn : Int32, endline : Int32, endcolumn : Int32,
    description : String, rule : String, ruleset : String, priority : Int32, externalInfoUrl : String do
    include JSON::Serializable
  end

  getter name : String
  getter category : String

  @@category : String = "PMD"
  @@split_rules : Hash(String, String) = {} of String => String
  @@default_report_name : String? = "PMD"

  def self.init_context : Nil
    @@category = "PMD"
    @@split_rules = {} of String => String
    @@default_report_name = "PMD"
  end

  patterns "*.pmd.json", "pmd.net.sourceforge.pmd.renderers.JsonRenderer"

  option "--category=NAME", "Specifies the category the PMD report is put in (default: \"PMD\")" do |name|
    @@category = name
  end
  option "--split=RULE,RULE,...:NAME",
    "Splits the specified rules into an own report with the given name" do |rule|
    rules = (@@split_rules ||= {} of String => String)
    name_separator = rule.index(':')
    raise ArgumentError.new("No name given for split rule") unless name_separator && name_separator != 0 && name_separator < (rule.size - 1)
    rule_name = rule[name_separator + 1, -1]
    rule[0, name_separator - 1].split(',') do |ref|
      @@split_rules[ref] = rule_name
    end
  end
  option "--default-report=NAME",
    "Specifies the default report name (default: \"PMD\", no default report if empty)" do |name|
    @@default_report_name = name
  end

  def self.from_path(path : Path) : Enumerable(Report)
    # Read and parse XML document, exit with error message if it is invalid XML
    begin
      File.open(path) do |io|
        document = Report::PMD::Document.from_json(io)
        category = @@category
        reports = {} of String? => Report::PMD

        if name = @@default_report_name
          reports[nil] = Report::PMD.new(category: category, name: name, files: [] of ReportFile)
        end

        @@split_rules.each do |ref, reportname|
          reports[reportname] ||= Report::PMD.new(category: category, name: reportname, files: [] of ReportFile)
        end

        document.files.each do |file|
          file.violations.each do |violation|
            report_name = @@split_rules[violation.rule]?
            report = reports[report_name]?
            next unless report
            dest_file = report.@files.find(&.filename.same?(file.filename))
            unless dest_file
              dest_file = ReportFile.new(filename: file.filename, violations: [] of Violation)
              report.@files << dest_file
            end
            dest_file.violations << violation
          end
        end

        reports.map { |k, v| v.as(Report) }
      end
    rescue ex
      STDERR.puts "Could not read #{path}: #{ex.message}"
      exit(1)
    end
  end

  def initialize(@category : String, @name : String, @files : Array(ReportFile))
  end

  def status : Status
    if @files.all?(&.violations.empty?)
      Status::Success
    else
      Status::Failure
    end
  end
end

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
  @@split_rules : String? = nil

  def self.init_context : Nil
    @@category = "PMD"
    @@split_rules = nil
  end

  pattern "*.pmd.json"

  option "--category=NAME", "Specifies the category the PMD report is put in (default: \"PMD\")" do |name|
    @@category = name
  end
  option "--split_rules=RULE1,RULE2,...", "Splits this report into one report for each specified rule" do |rules|
    @@split_rules = rules
  end

  def self.from_path(path : Path) : Enumerable(Report)
    # Read and parse XML document, exit with error message if it is invalid XML
    begin
      File.open(path) do |io|
        document = Report::PMD::Document.from_json(io)
        category = @@category

        if split_rules = @@split_rules
          rules = {} of String => Report::PMD

          split_rules.split(',') do |rule|
            rules[rule] = Report::PMD.new(category: category, name: rule, files: [] of ReportFile)
          end

          document.files.each do |file|
            file.violations.each do |violation|
              report = rules[violation.rule]?
              next unless report
              dest_file = report.@files.find(&.filename.same?(file.filename))
              unless dest_file
                dest_file = ReportFile.new(filename: file.filename, violations: [] of Violation)
                report.@files << dest_file
              end
              dest_file.violations << violation
            end
          end

          rules.map { |k, v| v.as(Report) }
        else
          [Report::PMD.new(category: category, name: "PMD", files: document.files)] of Report
        end
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

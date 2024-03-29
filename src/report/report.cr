# Class inherited by all reports parseable by the visualizer.
#
# Each report subclass must define the following class methods:
#
# - `def self.is_candidate?(filename : String) : Bool`
#
#   This method checks if the file could be of this report type using the filename.
#   This tool only uses the filenames to check which report subclass to use,
#   and any ambiguous filenames cause the tool to immediately stop.
#
# - `def self.from_path(path : Path) : Enumerable(Report)`
#
#   This method should actually parse the report and return any amount of reports.
abstract class Report
  @@sequence : Int32 = 0

  # Creates a sequential id used for mapping each report to a unique id.
  def self.create_sequential_id : Int32
    @@sequence += 1
    @@sequence
  end

  private module ReportClass
    abstract def from_path(path : Path) : Enumerable(Report)
    abstract def is_candidate?(filename : String) : Bool
  end

  # This macro makes every Report subclass extend the `ReportClass` module.
  #
  # This forces the Report subclasses to implement specific class-methods.
  private macro inherited
    extend ReportClass
    extend CLI::Context
  end

  macro patterns(*filenames)
    {%
      parts = filenames.map do |filename|
        ret = filename.split('*')
        filename.raise "Invalid pattern" unless ret.size == 1 || ret.size == 2
        ret
      end
    %}

    def self.is_candidate?(filename : String) : Bool
      {% for filename_parts in parts %}
        {% if filename_parts.size == 2 %}
          return true if filename.starts_with?({{ filename_parts[0] }}) && filename.ends_with?({{ filename_parts[1] }})
        {% else %}
          return true if filename == {{ filename_parts[0] }}
        {% end %}
      {% end %}
      false
    end

    header {{ "#{parse_type(@type.name.stringify).names.last}-Report (#{filenames.join(", ")}) arguments:" }}
  end

  # The report status.
  #
  # Currently, there are only two possible values `Success` and `Failed`.
  # Maybe in the future other values could be added in cases where partial progress can be evaluated.
  enum Status
    # A status stating a test is currently correct.
    Success

    # A status stating a test is currently errorneous.
    Failure

    # An errorneous status which cannot be recovered from.
    #
    # For example, a fraud attempt could be given this status.
    # The student is informed that the test cannot be corrected.
    Fatal
  end

  # The category this report is grouped in.
  #
  # The string should be below ~20 characters to prevent the sidebar from overflowing.
  abstract def category : String

  # The name displayed for this report.
  #
  # The string should be below ~20 characters to prevent the sidebar from overflowing.
  abstract def name : String

  # The status of this report.
  #
  # This will control the successful-test-count in the report header,
  # filtering options and an indicator next to the test in the sidebar.
  abstract def status : Status

  # Abstract method to create a visualization of the current report.
  abstract def render(io : IO) : Nil

  # The unique identifier for this report.
  getter id : Int32 { Report.create_sequential_id }

  # This macro is run for every subclass of `Report`.
  # It is used to automatically define the `to_html` method.
  {% begin %}
    {% file_extension = flag?("no_minify") ? ".ecr" : ".min.ecr" %}
    private macro inherited
      def render(io : IO) : Nil
        ECR.embed(\\{{ "./template/reports/#{__FILE__[(__DIR__.size + 1)..-4].id}.html#{{{file_extension}}}" }}, io)
      end
    end
  {% end %}
end

require "./*"

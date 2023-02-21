# Class inherited by all reports parseable by the visualizer
abstract class Report
  # The report status.
  #
  # Currently, there are only two possible values `Success` and `Failed`.
  # Maybe in the future other values could be added in cases where partial progress can be evaluated.
  enum Status
    Success
    Failure
  end

  def initialize(@category : String, @name : String, @status : Status)
  end

  # The category this report is grouped in.
  #
  # The string should be below ~20 characters to prevent the sidebar from overflowing.
  property category : String

  # The name displayed for this report.
  #
  # The string should be below ~20 characters to prevent the sidebar from overflowing.
  property name : String

  # The status of this report.
  #
  # This will control the successful-test-count in the report header,
  # filtering options and an indicator next to the test in the sidebar.
  property status : Status

  # Abstract method to create an html-based visualization of the current report.
  abstract def to_html(io : IO) : Nil

  # This macro is run for every subclass of `Report`.
  # It is used to automatically define the `to_html` method.
  private macro inherited
    def to_html(io : IO) : Nil
      ECR.embed(\{{ "./template/reports/#{__FILE__[(__DIR__.size + 1)..-4].id}.html.ecr" }}, io)
    end
  end
end

require "./*"

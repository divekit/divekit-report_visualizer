require "html"
require "json"

# A custom report format allowing to use arbitrary html for a test.
#
# The reports must be an array of objects with the keys `name`, `category`, `status` and `content`.
# `status` may only have the values `failure` or `success`.
#
# Example:
# ```json
# [
#   {
#     "name": "meinTest",
#     "category": "Kategorie",
#     "status": "failure",
#     "content": "<b>text</b>"
#   },
#   {
#     "name": "meinTest2",
#     "category": "Kategorie",
#     "status": "success",
#     "content": "<b>text</b>"
#   }
# ]
# ```
class Report::Custom < Report
  struct Document
    include JSON::Serializable

    @[JSON::Field]
    property name : String

    @[JSON::Field]
    property category : String

    @[JSON::Field]
    property status : Status

    @[JSON::Field]
    property content : String
  end

  def self.from_path(path) : Array(Report::Custom)
    # Read and parse XML document, exit wih error message if it is invalid XML
    begin
      document = File.open(path) do |file|
        reports = Array(Report::Custom::Document).from_json(file)
        return reports.map { |report| Report::Custom.new(report.category, report.name, report.status, report.content) }
      end
    rescue ex
      STDERR.puts "Could not read #{path}: #{ex.message}"
      exit(1)
    end
  end

  def initialize(category : String, name : String, status : Status, @content : String)
    super(category, name, status)
  end
end

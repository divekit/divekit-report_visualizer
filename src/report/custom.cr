require "json"

# A custom report format allowing to insert arbitrary content for a test.
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
#
# WARNING: Using custom reports is discouraged outside of development phases as they are hard to translate or re-theme.
class Report::Custom < Report
  include JSON::Serializable

  @[JSON::Field]
  getter name : String

  @[JSON::Field]
  getter category : String

  @[JSON::Field]
  getter status : Status

  @[JSON::Field]
  getter content : String

  def self.is_candidate?(filename : String) : Bool
    filename.ends_with?(".custom-test.json")
  end

  def self.from_path(path : Path) : Enumerable(Report)
    # Read and parse XML document, exit wih error message if it is invalid XML
    begin
      document = File.open(path) do |file|
        reports = Array(Report::Custom).from_json(file)
        return reports.map { |report| report.as(Report) }
      end
    rescue ex
      STDERR.puts "Could not read #{path}: #{ex.message}"
      exit(1)
    end
  end

  def initialize(@category : String, @name : String, @status : Status, @content : String)
  end
end

require "xml"

# The Surefire report format.
#
# XML Schema: https://maven.apache.org/surefire/maven-surefire-plugin/xsd/surefire-test-report-3.0.xsd
class Report::Surefire < Report
  pattern "TEST-*.xml"

  def self.is_candidate?(filename : String) : Bool
    filename.starts_with?("TEST-") && filename.ends_with?(".xml")
  end

  def self.from_path(path : Path) : Enumerable(Report)
    # Read and parse XML document, exit wih error message if it is invalid XML
    begin
      document = File.open(path) do |file|
        XML.parse(file)
      end
    rescue ex
      STDERR.puts "Could not read #{path}: #{ex.message}"
      exit(1)
    end

    raise RuntimeError.new("Empty XML document") unless testsuite = document.first_element_child
    raise RuntimeError.new("Invalid root node: Expected <testsuite> but got <#{testsuite.name}>") unless testsuite.name == "testsuite"

    test_cases = testsuite.xpath_nodes("./testcase")

    test_cases.map do |test|
      test_name = test["name"]
      test_classname = test["classname"]

      # Isolate category name.
      #
      # Surefire doesn't actually have a "test category".
      # We only get a class path (ex. "org.example.ExampleClass.test01")
      # Here, the category is the class the current test is directly located in (in this example, "ExampleClass").
      name_offset = test_classname.rindex('.').not_nil!
      classname_offset = test_classname.rindex('.', offset: name_offset - 1).not_nil!
      category = test_classname[(classname_offset + 1)..(name_offset - 1)]

      exception_message : String? = nil
      exception_type : String? = nil

      # TODO: Tests can also contain other error nodes, like <failure/>, <rerunFailure/>, <skipped/> or <system-out/>
      if error = test.xpath_node("./error")
        exception_message = error.inner_text
        exception_type = error["type"]
      end

      Report::Surefire.new(
        name: test_name,
        category: category,
        status: error ? Status::Failure : Status::Success,
        exception_message: exception_message,
        exception_type: exception_type,
      ).as(Report)
    end
  end

  getter category : String
  getter name : String
  getter status : Status
  getter exception_message : String?
  getter exception_type : String?

  def initialize(@category : String, @name : String, @status : Status, @exception_message : String?, @exception_type : String?)
  end
end

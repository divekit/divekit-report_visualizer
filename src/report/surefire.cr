require "xml"

# The Surefire report format.
#
# XML Schema: https://maven.apache.org/surefire/maven-surefire-plugin/xsd/surefire-test-report-3.0.xsd
class Report::Surefire < Report
  patterns "TEST-*.xml"

  @@category : String?

  option "--category=NAME", "Overwrites the report category (default: extracted from classpath)" do |name|
    @@category = name
  end

  def self.init_context : Nil
    @@category = nil
  end

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

      unless category = @@category
        # Isolate category name.
        #
        # Surefire doesn't actually have a "test category".
        # We only get a class path (ex. "org.example.ExampleClass.test01")
        # Here, the category is the class the current test is directly located in (in this example, "ExampleClass").
        test_classname = test["classname"]?
        if test_classname
          name_offset = test_classname.rindex('.') || 0
          classname_offset = test_classname.rindex('.', offset: name_offset - 1) if name_offset > 0
          category = classname_offset ? test_classname[(classname_offset + 1)..(name_offset - 1)] : "No Category"
        else
          category = "nil"
        end
      end

      summary : String? = nil
      message : String? = nil

      # NOTE: Currently, flaky errors are considered successful.
      if node = test.xpath_node("./error")
        tmp = node["message"]?
        summary = tmp ? "#{tmp} (#{node["type"]})" : node["type"]
        message = node.inner_text
      elsif node = test.xpath_node("./skipped | ./failure")
        summary = node["message"]?
        message = node.inner_text
      end

      Report::Surefire.new(
        name: test_name,
        category: category,
        status: message ? Status::Failure : Status::Success,
        message: message,
        summary: summary,
      ).as(Report)
    end
  end

  getter category : String
  getter name : String
  getter status : Status
  getter message : String?
  getter summary : String?

  def initialize(@category : String, @name : String, @status : Status, @message : String?, @summary : String?)
  end
end

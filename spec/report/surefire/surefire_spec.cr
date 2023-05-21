require "../spec_helper"

describe Report::Surefire do
  it "correctly parses different testcases" do
    Report::Surefire.init_context
    reports = Report::Surefire.from_path(Path[__DIR__, "TEST-crystal-error.xml"])
    reports.size.should eq(1)
    report = reports.first
    report.status.should eq(Report::Status::Failure)

    Report::Surefire.init_context
    reports = Report::Surefire.from_path(Path[__DIR__, "TEST-minimal.xml"])
    reports.size.should eq(1)
    report = reports.first
    report.status.should eq(Report::Status::Failure)

    Report::Surefire.init_context
    reports = Report::Surefire.from_path(Path[__DIR__, "TEST-success.xml"])
    reports.size.should eq(1)
    report = reports.first
    report.status.should eq(Report::Status::Success)
  end

  it "infers the category from the classname" do
    Report::Surefire.init_context
    reports = Report::Surefire.from_path(Path[__DIR__, "TEST-crystal-failure.xml"])
    reports.size.should eq(1)
    report = reports.first
    report.category.should eq("No Category")

    Report::Surefire.init_context
    reports = Report::Surefire.from_path(Path[__DIR__, "TEST-java-error.xml"])
    reports.size.should eq(1)
    report = reports.first
    report.category.should eq("E01Variables")
  end

  it "allows overriding category" do
    Report::Surefire.init_context
    Report::Surefire.parse_option("--category") { "Example Category" }
    reports = Report::Surefire.from_path(Path[__DIR__, "TEST-minimal.xml"])
    reports.size.should eq(1)
    report = reports.first
    report.category.should eq("Example Category")

    Report::Surefire.init_context
    Report::Surefire.parse_option("--category") { "Example Category" }
    reports = Report::Surefire.from_path(Path[__DIR__, "TEST-java-error.xml"])
    reports.size.should eq(1)
    report = reports.first
    report.category.should eq("Example Category")
  end
end

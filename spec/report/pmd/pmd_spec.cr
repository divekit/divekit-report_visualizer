require "../spec_helper"

describe Report::PMD do
  #it "correctly parses different testcases" do
  #  Report::Surefire.init_context
  #  reports = Report::PMD.from_path(Path[__DIR__, "example.pmd.json"])
  #  reports.size.should eq(1)
  #  reports.first.status.should eq(Report::Status::Failure)
  #end

  it "allows overriding category" do
    Report::PMD.init_context
    Report::PMD.parse_option("--category") { "Example Category" }
    reports = Report::PMD.from_path(Path[__DIR__, "example.pmd.json"])
    reports.empty?.should eq(false)
    reports.each { |report| report.category.should eq("Example Category") }
  end

  it "allows grouping by rules" do
    Report::PMD.init_context
    Report::PMD.parse_option("--split") { "UseUtilityClass,PackageCase:MULTIPLE CLASSES" }
    Report::PMD.parse_option("--split") { "ShortClassName:SINGLE CLASS" }
    Report::PMD.parse_option("--split") { "NonExistingError:DOESN'T EXIST" }
    reports = Report::PMD.from_path(Path[__DIR__, "example.pmd.json"])
    reports.size.should eq(4)

    found_group_1 = false
    found_group_2 = false
    found_group_3 = false
    found_group_4 = false

    reports.each do |report|
      case report.name
      when "MULTIPLE CLASSES"
        found_group_1 = true
        report.status.should eq(Report::Status::Failure)
      when "SINGLE CLASS"
        found_group_2 = true
        report.status.should eq(Report::Status::Failure)
      when "DOESN'T EXIST"
        found_group_3 = true
        report.status.should eq(Report::Status::Success)
      when "PMD"
        found_group_4 = true
        report.status.should eq(Report::Status::Success)
      else
        raise "Unknown group"
      end
    end

    (found_group_1 & found_group_2 & found_group_3 & found_group_4).should eq(true)
  end

  it "allows grouping by rules without default group" do
    Report::PMD.init_context
    Report::PMD.parse_option("--split") { "UseUtilityClass,PackageCase:MULTIPLE CLASSES" }
    Report::PMD.parse_option("--split") { "ShortClassName:SINGLE CLASS" }
    Report::PMD.parse_option("--split") { "NonExistingError:DOESN'T EXIST" }
    Report::PMD.parse_option("--default-report") { "" }
    reports = Report::PMD.from_path(Path[__DIR__, "example.pmd.json"])
    reports.size.should eq(3)

    found_group_1 = false
    found_group_2 = false
    found_group_3 = false

    reports.each do |report|
      case report.name
      when "MULTIPLE CLASSES"
        found_group_1 = true
        report.status.should eq(Report::Status::Failure)
      when "SINGLE CLASS"
        found_group_2 = true
        report.status.should eq(Report::Status::Failure)
      when "DOESN'T EXIST"
        found_group_3 = true
        report.status.should eq(Report::Status::Success)
      else
        raise "Unknown group"
      end
    end

    (found_group_1 & found_group_2 & found_group_3).should eq(true)
  end

  it "allows setting default report name" do
    Report::PMD.init_context
    Report::PMD.parse_option("--split") { "UseUtilityClass,PackageCase,ShortClassName:EVERYTHING" }
    Report::PMD.parse_option("--default-report") { "NEW DEFAULT GROUP" }
    reports = Report::PMD.from_path(Path[__DIR__, "example.pmd.json"])
    reports.size.should eq(2)

    found_group_1 = false
    found_group_2 = false

    reports.each do |report|
      case report.name
      when "EVERYTHING"
        found_group_1 = true
        report.status.should eq(Report::Status::Failure)
      when "NEW DEFAULT GROUP"
        found_group_2 = true
        report.status.should eq(Report::Status::Success)
      else
        raise "Unknown group"
      end
    end

    (found_group_1 & found_group_2).should eq(true)
  end
end

require "../spec_helper"

describe Report::Custom do
  it "correctly parses different testcases" do
    Report::Custom.init_context
    reports = Report::Custom.from_path(Path[__DIR__, "example.custom-test.json"])
    reports.size.should eq(3)

    found_first_test = false
    found_second_test = false
    found_third_test = false

    reports.each do |report|
      case report.name
      when "first test"
        found_first_test = true
        report.category.should eq("test-testing")
        report.status.should eq(Report::Status::Success)
        (String.build { |io| report.render(io) }).should be_empty
      when "second test"
        found_second_test = true
        report.category.should eq("test-testing")
        report.status.should eq(Report::Status::Failure)
        (String.build { |io| report.render(io) }).should eq(
          "Gentlemen, welcome to Test Club. \
           The first rule of Test Club is: \
           You do not talk about Test Club. \
           The second rule of Test Club is: \
           YOU DO NOT. TALK. ABOUT TEST CLUB!"
        )
      when "third test"
        found_third_test = true
        report.category.should eq("different category")
        report.status.should eq(Report::Status::Fatal)
        (String.build { |io| report.render(io) }).should eq("<b>TEST!!!</b>")
      else
        raise "Unknown test: #{report.name}"
      end
    end

    (found_first_test & found_second_test & found_third_test).should eq(true)
  end
end

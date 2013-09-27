require_relative '../spec_helper'

describe ExtractSharedStrings do
  
  it "should create an array of the shared strings" do
    input = excel_fragment 'SharedStrings.xml'
    output = StringIO.new
    ExtractSharedStrings.extract(input).should == [
      "This a second shared string",
      "This is, hopefully, the first shared string"
    ]
  end
end

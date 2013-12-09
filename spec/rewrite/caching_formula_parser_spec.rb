require_relative '../spec_helper'

describe CachingFormulaParser do
  
  it "should turn sheet and cell references into symbols" do
    CachingFormulaParser.parse("Sheet1!B$1").should == [:sheet_reference, :Sheet1, [:cell, :"B$1"]]
    CachingFormulaParser.parse("Sheet1!B$1:B10").should == [:sheet_reference, :Sheet1, [:area, :"B$1", :B10]]
  end

  it "should turn numbers into numeric values" do
    CachingFormulaParser.parse("1.31").should == [:number, 1.31]
  end

  it "should cache numbers and strings" do
    first = CachingFormulaParser.parse("1.31")
    second = CachingFormulaParser.parse("1.31")
    first.object_id.should == second.object_id

    first = CachingFormulaParser.parse('"Hello"')
    second = CachingFormulaParser.parse('"Hello"')
    first.object_id.should == second.object_id
  end

  it "should turn function names into symbols" do 
    CachingFormulaParser.parse('INDIRECT("A1")').should == [:function, :INDIRECT, [:string, "A1"]]

  end

end


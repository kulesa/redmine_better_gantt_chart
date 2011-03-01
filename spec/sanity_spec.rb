require File.dirname(__FILE__) + '/spec_helper'

describe Class do
  it "should be a class of Class" do
    Class.class.should eql(Class)
  end
end

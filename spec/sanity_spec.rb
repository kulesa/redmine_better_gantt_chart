require File.expand_path('../spec_helper', __FILE__)

describe Class do
  it "should be a class of Class" do
    Class.class.should eql(Class)
  end
end

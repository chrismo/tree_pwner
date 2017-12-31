require_relative '../lib/file_criteria'

describe FileCriteria do
  it 'should escape apostrophes in name' do
    FileCriteria.name_is("foo's bar's").should == %q{name = 'foo\'s bar\'s'}
  end
end

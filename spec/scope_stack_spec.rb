require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe RipperPlus::ScopeStack do
  before do
    @stack = RipperPlus::ScopeStack.new
  end
  
  it 'can see variables added at top level' do
    @stack.should_not have_variable(:hello)
    @stack.add_variable :hello
    @stack.should have_variable(:hello)
  end
  
  it 'can not see variables added beyond a closed scope' do
    @stack.add_variable :hello
    @stack.with_closed_scope do
      @stack.should_not have_variable(:hello)
    end
    @stack.should have_variable(:hello)
  end
  
  it 'can see variables added beyond an open scope' do
    @stack.add_variable :hello
    @stack.with_open_scope do
      @stack.should have_variable(:hello)
    end
    @stack.should have_variable(:hello)
  end
end

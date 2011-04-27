module RipperPlus
  # internal class that manages the current scopes.
  class ScopeStack
    SCOPE_BLOCKER_9000 = :scope_block
    def initialize
      # simplifies algorithm to have the scope blocker be the stack base
      @stack = [SCOPE_BLOCKER_9000, Set.new]
    end

    def inspect
      middle = @stack.map do |scope|
        if SCOPE_BLOCKER_9000 == scope
          '||'
        else
          "[ #{scope.to_a.sort.join(', ')} ]"
        end
      end.join(' ')
      "< #{middle} >"
    end

    def add_variable(var)
      @stack.last << var
    end
  
    # An open scope permits reference to local variables in enclosing scopes.
    def with_open_scope
      @stack.push(Set.new)
      yield
    ensure
      @stack.pop  # pops open scope
    end
  
    # An open scope denies reference to local variables in enclosing scopes.
    def with_closed_scope
      @stack.push(SCOPE_BLOCKER_9000)
      @stack.push(Set.new)
      yield
    ensure
      @stack.pop  # pop closed scope
      @stack.pop  # pop scope blocker
    end
  
    # Checks if the given variable is in scope.
    def has_variable?(var)
      @stack.reverse_each do |scope|
        if SCOPE_BLOCKER_9000 == scope
          return false
        elsif scope.include?(var)
          return true
        end
      end
    end
  end
end
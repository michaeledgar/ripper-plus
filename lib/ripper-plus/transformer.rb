require 'set'
module RipperPlus
  # Transforms a 1.9.2 Ripper AST into a RipperPlus AST. The only
  # change as a result of this transformation is that the nodes for
  # local variable references and zcalls (bareword calls to self)
  # have different node types:
  #
  #    def foo(x)
  #      y
  #      y = x
  #    end
  #
  # becomes
  #
  # [:def,
  #   [:@ident, "foo", [1, 4]],
  #   [:paren, [:params, [[:@ident, "x", [1, 8]]], nil, nil, nil, nil]],
  #   [:bodystmt,
  #    [[:zcall, [:@ident, "y", [2, 2]]],
  #     [:assign,
  #      [:var_field, [:@ident, "y", [3, 2]]],
  #      [:var_ref, [:@ident, "x", [3, 6]]]]],
  #    nil, nil, nil]]
  #
  # while:
  #
  #    def foo(x)
  #      y = x
  #      y
  #    end
  #
  # becomes
  #
  # [:def,
  #   [:@ident, "foo", [1, 4]],
  #   [:paren, [:params, [[:@ident, "x", [1, 8]]], nil, nil, nil, nil]],
  #   [:bodystmt,
  #    [[:assign,
  #      [:var_field, [:@ident, "y", [2, 2]]],
  #      [:var_ref, [:@ident, "x", [2, 6]]]],
  #     [:var_ref, [:@ident, "y", [3, 2]]]],
  #    nil, nil, nil]]
  module Transformer
    extend self

    # Transforms the given AST into a RipperPlus AST.
    def transform(root)
      new_copy = clone_sexp(root)
      scope_stack = ScopeStack.new
      transform_tree(new_copy, scope_stack)
      new_copy
    end

    # Transforms the given tree into a RipperPlus AST.
    def transform_tree(tree, scope_stack)
      case tree[0]
      when :assign, :massign
        lhs, rhs = tree[1..2]
        add_variables_from_lhs(lhs, scope_stack)
        transform_tree(rhs, scope_stack)
      when :for
        vars, iterated, body = tree[1..3]
        add_variables_from_lhs(vars, scope_stack)
        transform_tree(iterated, scope_stack)
        transform_tree(body, scope_stack)
      when :var_ref
        if tree[1][0] == :@ident && !scope_stack.has_variable?(tree[1][1])
          tree[0] = :zcall
        end
      when :class
        superclass, body = tree[2..3]
        transform_tree(superclass, scope_stack) if superclass  # superclass node
        scope_stack.with_closed_scope do
          transform_tree(body, scope_stack)
        end
      when :module
        scope_stack.with_closed_scope do
          transform_tree(tree[2], scope_stack)  # body
        end
      when :sclass
        singleton, body = tree[1..2]
        transform_tree(singleton, scope_stack)
        scope_stack.with_closed_scope do
          transform_tree(body, scope_stack)
        end
      when :def
        scope_stack.with_closed_scope do
          param_node = tree[2]
          body = tree[3]
          transform_params(param_node, scope_stack)
          transform_tree(body, scope_stack)
        end
      when :defs
        transform_tree(tree[1], scope_stack)  # singleton could be a method call!
        scope_stack.with_closed_scope do
          param_node = tree[4]
          body = tree[5]
          transform_params(param_node, scope_stack)
          transform_tree(body, scope_stack)
        end
      when :method_add_block
        call, block = tree[1..2]
        # first transform the call
        transform_tree(call, scope_stack)
        # then transform the block
        block_args, block_body = block[1..2]
        scope_stack.with_open_scope do
          if block_args
            transform_params(block_args[1], scope_stack)
            if block_args[2]
              block_args[2].each { |var| add_variables_from_lhs(var, scope_stack) }
            end
          end
          transform_tree(block_body, scope_stack)
        end
      when :if_mod, :unless_mod, :while_mod, :until_mod
        # The AST is the reverse of the parse order for these nodes.
        transform_tree(tree[2], scope_stack)
        transform_tree(tree[1], scope_stack)
      else
        transform_in_order(tree, scope_stack)
      end
    end

    def add_variables_from_lhs(lhs, scope_stack)
      case lhs[0]
      when :@ident
        scope_stack.add_variable(lhs[1])
      when Array
        lhs.each { |var| add_variables_from_lhs(var, scope_stack) }
      when :mlhs_paren, :var_field, :rest_param, :blockarg
        add_variables_from_lhs(lhs[1], scope_stack)
      when :mlhs_add_star
        pre_star, star, post_star = lhs[1..3]
        pre_star.each { |var| add_variables_from_lhs(var, scope_stack) }
        if star
          add_variables_from_lhs(star, scope_stack)
        end
        if post_star
          post_star.each { |var| add_variables_from_lhs(var, scope_stack) }
        end
      end
    end

    # If this node's subtrees are ordered as they are lexically, as most are,
    # transform each subtree in order.
    def transform_in_order(tree, scope_stack)
      # some nodes have no type: include the first element in this case
      range = Symbol === tree[0] ? 1..-1 : 0..-1
      tree[range].each do |subtree|
        # obviously don't transform literals or token locations
        if Array === subtree && !(Fixnum === subtree[0])
          transform_tree(subtree, scope_stack)
        end
      end
    end

    # Transforms a parameter list, and adds the new variables to current scope.
    # Used by both block args and method args.
    def transform_params(param_node, scope_stack)
      param_node = param_node[1] if param_node[0] == :paren
      if param_node
        positional_1, optional, rest, positional_2, block = param_node[1..5]
        if positional_1
          positional_1.each { |var| add_variables_from_lhs(var, scope_stack) }
        end
        if optional
          optional.each do |var, value|
            # MUST walk value first. (def foo(y=y); end) == (def foo(y=y()); end)
            transform_tree(value, scope_stack)
            add_variables_from_lhs(var, scope_stack)
          end
        end
        if rest && rest[1]
          add_variables_from_lhs(rest, scope_stack)
        end
        if positional_2
          positional_2.each { |var| add_variables_from_lhs(var, scope_stack) }
        end
        if block
          add_variables_from_lhs(block, scope_stack)
        end
      end
    end

    # Deep-copies the sexp. I wish Array#clone did deep copies...
    def clone_sexp(node)
      node.map do |part|
        # guess: arrays most common, then un-dupables, then dup-ables (strings only)
        if Array === part
          clone_sexp(part)
        elsif [Symbol, Fixnum, TrueClass, FalseClass, NilClass].any? { |k| k === part }
          part
        else
          part.dup
        end
      end
    end
    private :clone_sexp
  end
end
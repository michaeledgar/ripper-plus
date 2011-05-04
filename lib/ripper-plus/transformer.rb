require 'set'
module RipperPlus
  class SyntaxError < StandardError; end
  class LHSError < SyntaxError; end
  class DynamicConstantError < SyntaxError; end
  class InvalidArgumentError < SyntaxError; end
  class DuplicateArgumentError < SyntaxError; end
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
    def transform(root, opts={})
      new_copy = opts[:in_place] ? root : clone_sexp(root)
      scope_stack = ScopeStack.new
      transform_tree(new_copy, scope_stack)
      new_copy
    end

    # Transforms the given tree into a RipperPlus AST, using a scope stack.
    # This will be recursively called through each level of the tree.
    def transform_tree(tree, scope_stack)
      if Symbol === tree[0]
        case tree[0]
        when :assign, :massign
          lhs, rhs = tree[1..2]
          begin
            add_variables_from_node(lhs, scope_stack)
          rescue SyntaxError => err
            wrap_node_with_error(tree)
          else
            transform_tree(rhs, scope_stack)
          end
        when :for
          vars, iterated, body = tree[1..3]
          add_variables_from_node(vars, scope_stack)
          transform_tree(iterated, scope_stack)
          transform_tree(body, scope_stack)
        when :var_ref
          # When we reach a :var_ref, we should know everything we need to know
          # in order to tell if it should be transformed into a :zcall.
          if tree[1][0] == :@ident && !scope_stack.has_variable?(tree[1][1])
            tree[0] = :zcall
          end
        when :class
          name, superclass, body = tree[1..3]
          if name[1][0] == :class_name_error || scope_stack.in_method?
            wrap_node_with_error(tree)
          else
            transform_tree(superclass, scope_stack) if superclass  # superclass node
            scope_stack.with_closed_scope do
              transform_tree(body, scope_stack)
            end
          end
        when :module
          name, body = tree[1..2]
          if name[1][0] == :class_name_error || scope_stack.in_method?
            wrap_node_with_error(tree)
          else
            scope_stack.with_closed_scope do
              transform_tree(body, scope_stack)  # body
            end
          end
        when :sclass
          singleton, body = tree[1..2]
          transform_tree(singleton, scope_stack)
          scope_stack.with_closed_scope do
            transform_tree(body, scope_stack)
          end
        when :def
          scope_stack.with_closed_scope(true) do
            param_node = tree[2]
            body = tree[3]
            transform_params_then_body(tree, param_node, body, scope_stack)
          end
        when :defs
          transform_tree(tree[1], scope_stack)  # singleton could be a method call!
          scope_stack.with_closed_scope(true) do
            param_node = tree[4]
            body = tree[5]
            transform_params_then_body(tree, param_node, body, scope_stack)
          end
        when :lambda
          param_node, body = tree[1..2]
          scope_stack.with_open_scope do
            transform_params_then_body(tree, param_node, body, scope_stack)
          end
        when :rescue
          list, name, body = tree[1..3]
          transform_tree(list, scope_stack)
          # Don't forget the rescue argument!
          if name
            add_variables_from_node(name, scope_stack)
          end
          transform_tree(body, scope_stack)
        when :method_add_block
          call, block = tree[1..2]
          # first transform the call
          transform_tree(call, scope_stack)
          # then transform the block
          param_node, body = block[1..2]
          scope_stack.with_open_scope do
            begin
              if param_node
                transform_params(param_node[1], scope_stack)
                if param_node[2]
                  add_variable_list(param_node[2], scope_stack, false)
                end
              end
            rescue SyntaxError
              wrap_node_with_error(tree)
            else
              transform_tree(body, scope_stack)
            end
          end
        when :binary
          # must check for named groups in a literal match. wowzerz.
          lhs, op, rhs = tree[1..3]
          if op == :=~
            if lhs[0] == :regexp_literal
              add_locals_from_regexp(lhs, scope_stack)
              transform_tree(rhs, scope_stack)
            elsif lhs[0] == :paren && !lhs[1].empty? && lhs[1] != [[:void_stmt]] && lhs[1].last[0] == :regexp_literal
              lhs[1][0..-2].each { |node| transform_tree(node, scope_stack) }
              add_locals_from_regexp(lhs[1].last, scope_stack)
              transform_tree(rhs, scope_stack)
            else
              transform_in_order(tree, scope_stack)
            end
          else
            transform_in_order(tree, scope_stack)
          end
        when :if_mod, :unless_mod, :while_mod, :until_mod, :rescue_mod
          # The AST is the reverse of the parse order for these nodes.
          transform_tree(tree[2], scope_stack)
          transform_tree(tree[1], scope_stack)
        when :alias_error, :assign_error  # error already top-level! wrap it again.
          wrap_node_with_error(tree)
        else
          transform_in_order(tree, scope_stack)
        end
      else
        transform_in_order(tree, scope_stack)
      end
    end

    def transform_params_then_body(tree, params, body, scope_stack)
      transform_params(params, scope_stack)
    rescue SyntaxError
      wrap_node_with_error(tree)
    else
      transform_tree(body, scope_stack)
    end

    def add_locals_from_regexp(regexp, scope_stack)
      regexp_parts = regexp[1]
      if regexp_parts.one? && regexp_parts[0][0] == :@tstring_content
        regexp_text = regexp_parts[0][1]
        captures = Regexp.new(regexp_text).names
        captures.each { |var_name| scope_stack.add_variable(var_name) }
      end
    end

    def add_variable_list(list, scope_stack, allow_duplicates=true)
      list.each { |var| add_variables_from_node(var, scope_stack, allow_duplicates) }
    end

    # Adds variables to the given scope stack from the given node. Allows
    # nodes from parameter lists, left-hand-sides, block argument lists, and
    # so on.
    def add_variables_from_node(lhs, scope_stack, allow_duplicates=true)
      case lhs[0]
      when :@ident
        scope_stack.add_variable(lhs[1], allow_duplicates)
      when :const_path_field, :@const, :top_const_field
        if scope_stack.in_method?
          raise DynamicConstantError.new
        end
      when Array
        add_variable_list(lhs, scope_stack, allow_duplicates)
      when :mlhs_paren, :var_field, :rest_param, :blockarg
        add_variables_from_node(lhs[1], scope_stack, allow_duplicates)
      when :mlhs_add_star
        pre_star, star, post_star = lhs[1..3]
        add_variable_list(pre_star, scope_stack, allow_duplicates)
        if star
          add_variables_from_node(star, scope_stack, allow_duplicates)
        end
        add_variable_list(post_star, scope_stack, allow_duplicates) if post_star
      when :param_error
        raise InvalidArgumentError.new
      when :assign_error
        raise LHSError.new
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
        add_variable_list(positional_1, scope_stack, false) if positional_1
        if optional
          optional.each do |var, value|
            # MUST walk value first. (def foo(y=y); end) == (def foo(y=y()); end)
            transform_tree(value, scope_stack)
            add_variables_from_node(var, scope_stack, false)
          end
        end
        if rest && rest[1]
          add_variables_from_node(rest, scope_stack, false)
        end
        add_variable_list(positional_2, scope_stack, false) if positional_2
        add_variables_from_node(block, scope_stack, false) if block
      end
    end

    # Wraps the given node as an error node with minimal space overhead.
    def wrap_node_with_error(tree)
      new_tree = [:error, tree.dup]
      tree.replace(new_tree)
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
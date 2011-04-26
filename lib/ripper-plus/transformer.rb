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
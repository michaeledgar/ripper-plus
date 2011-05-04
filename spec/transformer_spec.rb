require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe RipperPlus::Transformer do
  describe 'zcall detection' do
    it 'should transform a simple zcall in a method' do
      input_tree =
        [:program,
         [[:def,
           [:@ident, "foo", [1, 4]],
           [:paren, [:params, [[:@ident, "x", [1, 8]]], nil, nil, nil, nil]],
           [:bodystmt,
            [[:void_stmt],
             [:var_ref, [:@ident, "y", [1, 12]]],
             [:assign,
              [:var_field, [:@ident, "y", [1, 15]]],
              [:var_ref, [:@ident, "x", [1, 19]]]]],
            nil, nil, nil]]]]
      output_tree =
        [:program,
         [[:def,
           [:@ident, "foo", [1, 4]],
           [:paren, [:params, [[:@ident, "x", [1, 8]]], nil, nil, nil, nil]],
           [:bodystmt,
            [[:void_stmt],
             [:zcall, [:@ident, "y", [1, 12]]],
             [:assign,
              [:var_field, [:@ident, "y", [1, 15]]],
              [:var_ref, [:@ident, "x", [1, 19]]]]],
            nil, nil, nil]]]]
      input_tree.should transform_to(output_tree)
    end

    it 'should respect argument order in method definitions' do
      input_tree =
        [:program,
         [[:def,
           [:@ident, "foo", [1, 4]],
           [:paren,
            [:params,
             [[:@ident, "x", [1, 8]]],
             [[[:@ident, "y", [1, 11]], [:var_ref, [:@ident, "z", [1, 13]]]],
              [[:@ident, "z", [1, 16]], [:var_ref, [:@ident, "y", [1, 18]]]]],
             nil,
             nil,
             nil]],
           [:bodystmt, [[:void_stmt]], nil, nil, nil]]]]
      output_tree =
        [:program,
         [[:def,
           [:@ident, "foo", [1, 4]],
           [:paren,
            [:params,
             [[:@ident, "x", [1, 8]]],
             [[[:@ident, "y", [1, 11]], [:zcall, [:@ident, "z", [1, 13]]]],
              [[:@ident, "z", [1, 16]], [:var_ref, [:@ident, "y", [1, 18]]]]],
             nil,
             nil,
             nil]],
           [:bodystmt, [[:void_stmt]], nil, nil, nil]]]]
      input_tree.should transform_to(output_tree)
    end

    it 'should respect argument order in block argument definitions' do
      input_tree =
        [:program,
         [[:method_add_block,
           [:zsuper],
           [:do_block,
            [:block_var,
             [:params,
              [[:@ident, "x", [1, 10]]],
              [[[:@ident, "y", [1, 13]], [:var_ref, [:@ident, "x", [1, 15]]]],
               [[:@ident, "z", [1, 18]], [:var_ref, [:@ident, "a", [1, 20]]]]],
              [:rest_param, [:@ident, "a", [1, 24]]],
              nil,
              nil],
             nil],
            [[:void_stmt],
             [:command,
              [:@ident, "p", [1, 28]],
              [:args_add_block,
               [[:var_ref, [:@ident, "x", [1, 30]]],
                [:var_ref, [:@ident, "y", [1, 33]]],
                [:var_ref, [:@ident, "z", [1, 36]]],
                [:var_ref, [:@ident, "a", [1, 39]]]],
               false]]]]]]]
      output_tree =
        [:program,
         [[:method_add_block,
           [:zsuper],
           [:do_block,
            [:block_var,
             [:params,
              [[:@ident, "x", [1, 10]]],
              [[[:@ident, "y", [1, 13]], [:var_ref, [:@ident, "x", [1, 15]]]],
               [[:@ident, "z", [1, 18]], [:zcall, [:@ident, "a", [1, 20]]]]],
              [:rest_param, [:@ident, "a", [1, 24]]],
              nil,
              nil],
             nil],
            [[:void_stmt],
             [:command,
              [:@ident, "p", [1, 28]],
              [:args_add_block,
               [[:var_ref, [:@ident, "x", [1, 30]]],
                [:var_ref, [:@ident, "y", [1, 33]]],
                [:var_ref, [:@ident, "z", [1, 36]]],
                [:var_ref, [:@ident, "a", [1, 39]]]],
               false]]]]]]]
      input_tree.should transform_to(output_tree)
    end

    it 'should transform singleton names in singleton method definitions' do
      input_tree =
        [:program,
         [[:defs,
           [:var_ref, [:@ident, "foo", [1, 4]]],
           [:@period, ".", [1, 7]],
           [:@ident, "silly", [1, 8]],
           [:paren, [:params, nil, nil, nil, nil, nil]],
           [:bodystmt, [[:void_stmt]], nil, nil, nil]]]]
      output_tree =
        [:program,
         [[:defs,
           [:zcall, [:@ident, "foo", [1, 4]]],
           [:@period, ".", [1, 7]],
           [:@ident, "silly", [1, 8]],
           [:paren, [:params, nil, nil, nil, nil, nil]],
           [:bodystmt, [[:void_stmt]], nil, nil, nil]]]]
      input_tree.should transform_to(output_tree)
    end
  
    it 'should not transform singleton names when an appropriate local variable exists' do
      input_tree =
        [:program,
         [[:assign,
           [:var_field, [:@ident, "foo", [1, 0]]],
           [:var_ref, [:@kw, "self", [1, 6]]]],
          [:defs,
           [:var_ref, [:@ident, "foo", [1, 16]]],
           [:@period, ".", [1, 19]],
           [:@ident, "silly", [1, 20]],
           [:params, nil, nil, nil, nil, nil],
           [:bodystmt, [[:void_stmt]], nil, nil, nil]]]]
      input_tree.should transform_to(input_tree)
    end
  
    it 'does not transform the tricky x = 5 unless defined?(x) case' do
      input_tree =
        [:program,
         [[:unless_mod,
           [:defined, [:var_ref, [:@ident, "x", [1, 22]]]],
           [:assign, [:var_field, [:@ident, "x", [1, 0]]], [:@int, "5", [1, 4]]]]]]
      input_tree.should transform_to(input_tree)
    end
  
    it 'finds all LHS vars before transforming an MLHS' do
      input_tree =
        [:program,
         [[:massign,
           [[:@ident, "a", [1, 0]],
            [:@const, "B", [1, 3]],
            [:mlhs_paren,
             [:mlhs_add_star,
              [[:@gvar, "$c", [1, 7]]],
              [:@ident, "rest", [1, 12]],
              [[:@ident, "d", [1, 18]], [:@ident, "e", [1, 21]]]]]],
           [:method_add_arg,
            [:fcall, [:@ident, "foo", [1, 26]]],
            [:arg_paren,
             [:args_add_block,
              [[:var_ref, [:@ident, "a", [1, 30]]],
               [:var_ref, [:@ident, "c", [1, 33]]],
               [:var_ref, [:@ident, "d", [1, 36]]]],
              false]]]]]]
      output_tree =
        [:program,
         [[:massign,
           [[:@ident, "a", [1, 0]],
            [:@const, "B", [1, 3]],
            [:mlhs_paren,
             [:mlhs_add_star,
              [[:@gvar, "$c", [1, 7]]],
              [:@ident, "rest", [1, 12]],
              [[:@ident, "d", [1, 18]], [:@ident, "e", [1, 21]]]]]],
           [:method_add_arg,
            [:fcall, [:@ident, "foo", [1, 26]]],
            [:arg_paren,
             [:args_add_block,
              [[:var_ref, [:@ident, "a", [1, 30]]],
               [:zcall, [:@ident, "c", [1, 33]]],
               [:var_ref, [:@ident, "d", [1, 36]]]],
              false]]]]]]
      input_tree.should transform_to(output_tree)
    end
  
    it 'creates for-loop MLHS vars before transforming the iteratee' do
      input_tree =
        [:program,
         [[:for,
           [[:@ident, "a", [1, 4]],
            [:@ident, "b", [1, 7]],
            [:mlhs_paren,
             [[:@ident, "c", [1, 11]],
              [:mlhs_paren,
               [:mlhs_add_star,
                [],
                [:@ident, "d", [1, 16]],
                [[:@ident, "e", [1, 19]]]]]]]],
           [:method_add_arg,
            [:fcall, [:@ident, "foo", [1, 26]]],
            [:arg_paren,
             [:args_add_block,
              [[:var_ref, [:@ident, "a", [1, 30]]],
               [:var_ref, [:@ident, "b", [1, 33]]],
               [:var_ref, [:@ident, "c", [1, 36]]],
               [:var_ref, [:@ident, "d", [1, 39]]],
               [:var_ref, [:@ident, "e", [1, 42]]],
               [:var_ref, [:@ident, "f", [1, 45]]],
               [:var_ref, [:@ident, "g", [1, 48]]]],
              false]]],
           [[:void_stmt]]]]]
      output_tree =
        [:program,
         [[:for,
           [[:@ident, "a", [1, 4]],
            [:@ident, "b", [1, 7]],
            [:mlhs_paren,
             [[:@ident, "c", [1, 11]],
              [:mlhs_paren,
               [:mlhs_add_star,
                [],
                [:@ident, "d", [1, 16]],
                [[:@ident, "e", [1, 19]]]]]]]],
           [:method_add_arg,
            [:fcall, [:@ident, "foo", [1, 26]]],
            [:arg_paren,
             [:args_add_block,
              [[:var_ref, [:@ident, "a", [1, 30]]],
               [:var_ref, [:@ident, "b", [1, 33]]],
               [:var_ref, [:@ident, "c", [1, 36]]],
               [:var_ref, [:@ident, "d", [1, 39]]],
               [:var_ref, [:@ident, "e", [1, 42]]],
               [:zcall, [:@ident, "f", [1, 45]]],
               [:zcall, [:@ident, "g", [1, 48]]]],
              false]]],
           [[:void_stmt]]]]]
      input_tree.should transform_to(output_tree)
    end
  
    it 'should transform respecting stabby-lambda arguments' do
      input_tree =
        [:program,
         [[:assign,
           [:var_field, [:@ident, "y", [1, 0]]],
           [:lambda,
            [:paren,
             [:params,
              [[:@ident, "a", [1, 7]]],
              [[[:@ident, "b", [1, 10]], [:var_ref, [:@ident, "a", [1, 12]]]],
               [[:@ident, "c", [1, 15]], [:var_ref, [:@ident, "d", [1, 17]]]]],
              [:rest_param, [:@ident, "rest", [1, 21]]],
              nil,
              nil]],
            [[:binary,
              [:array,
               [[:binary,
                 [:binary,
                  [:binary,
                   [:var_ref, [:@ident, "a", [1, 30]]],
                   :*,
                   [:var_ref, [:@ident, "b", [1, 34]]]],
                  :*,
                  [:var_ref, [:@ident, "c", [1, 38]]]],
                 :*,
                 [:var_ref, [:@ident, "d", [1, 42]]]]]],
              :+,
              [:var_ref, [:@ident, "rest", [1, 47]]]]]]],
          [:var_ref, [:@ident, "a", [1, 55]]]]]
      output_tree =
        [:program,
         [[:assign,
           [:var_field, [:@ident, "y", [1, 0]]],
           [:lambda,
            [:paren,
             [:params,
              [[:@ident, "a", [1, 7]]],
              [[[:@ident, "b", [1, 10]], [:var_ref, [:@ident, "a", [1, 12]]]],
               [[:@ident, "c", [1, 15]], [:zcall, [:@ident, "d", [1, 17]]]]],
              [:rest_param, [:@ident, "rest", [1, 21]]],
              nil,
              nil]],
            [[:binary,
              [:array,
               [[:binary,
                 [:binary,
                  [:binary,
                   [:var_ref, [:@ident, "a", [1, 30]]],
                   :*,
                   [:var_ref, [:@ident, "b", [1, 34]]]],
                  :*,
                  [:var_ref, [:@ident, "c", [1, 38]]]],
                 :*,
                 [:zcall, [:@ident, "d", [1, 42]]]]]],
              :+,
              [:var_ref, [:@ident, "rest", [1, 47]]]]]]],
          [:zcall, [:@ident, "a", [1, 55]]]]]
      input_tree.should transform_to output_tree
    end
  
    it 'should transform respecting subassignments in block arguments' do
      input_tree =
        [:program,
         [[:assign, [:var_field, [:@ident, "x", [1, 0]]], [:@int, "10", [1, 4]]],
          [:method_add_block,
           [:call,
            [:top_const_ref, [:@const, "ARR", [1, 10]]],
            :".",
            [:@ident, "each", [1, 14]]],
           [:brace_block,
            [:block_var,
             [:params,
              [[:@ident, "y", [1, 22]],
               [:mlhs_paren,
                [[:mlhs_paren, [:@ident, "z", [1, 26]]],
                 [:mlhs_paren, [:@ident, "a", [1, 29]]]]]],
              [[[:@ident, "k", [1, 33]], [:var_ref, [:@ident, "z", [1, 37]]]],
               [[:@ident, "j", [1, 40]], [:var_ref, [:@ident, "d", [1, 44]]]]],
              [:rest_param, [:@ident, "r", [1, 48]]],
              nil,
              [:blockarg, [:@ident, "blk", [1, 52]]]],
             [[:@ident, "local", [1, 57]]]],
            [[:command,
              [:@ident, "p", [1, 64]],
              [:args_add_block,
               [[:var_ref, [:@ident, "x", [1, 66]]],
                [:var_ref, [:@ident, "y", [1, 69]]],
                [:var_ref, [:@ident, "z", [1, 72]]],
                [:var_ref, [:@ident, "a", [1, 75]]],
                [:var_ref, [:@ident, "k", [1, 78]]],
                [:var_ref, [:@ident, "j", [1, 81]]],
                [:var_ref, [:@ident, "r", [1, 84]]],
                [:var_ref, [:@ident, "blk", [1, 87]]],
                [:var_ref, [:@ident, "local", [1, 92]]],
                [:var_ref, [:@ident, "foo", [1, 99]]]],
               false]]]]]]]
      output_tree =
        [:program,
         [[:assign, [:var_field, [:@ident, "x", [1, 0]]], [:@int, "10", [1, 4]]],
          [:method_add_block,
           [:call,
            [:top_const_ref, [:@const, "ARR", [1, 10]]],
            :".",
            [:@ident, "each", [1, 14]]],
           [:brace_block,
            [:block_var,
             [:params,
              [[:@ident, "y", [1, 22]],
               [:mlhs_paren,
                [[:mlhs_paren, [:@ident, "z", [1, 26]]],
                 [:mlhs_paren, [:@ident, "a", [1, 29]]]]]],
              [[[:@ident, "k", [1, 33]], [:var_ref, [:@ident, "z", [1, 37]]]],
               [[:@ident, "j", [1, 40]], [:zcall, [:@ident, "d", [1, 44]]]]],
              [:rest_param, [:@ident, "r", [1, 48]]],
              nil,
              [:blockarg, [:@ident, "blk", [1, 52]]]],
             [[:@ident, "local", [1, 57]]]],
            [[:command,
              [:@ident, "p", [1, 64]],
              [:args_add_block,
               [[:var_ref, [:@ident, "x", [1, 66]]],
                [:var_ref, [:@ident, "y", [1, 69]]],
                [:var_ref, [:@ident, "z", [1, 72]]],
                [:var_ref, [:@ident, "a", [1, 75]]],
                [:var_ref, [:@ident, "k", [1, 78]]],
                [:var_ref, [:@ident, "j", [1, 81]]],
                [:var_ref, [:@ident, "r", [1, 84]]],
                [:var_ref, [:@ident, "blk", [1, 87]]],
                [:var_ref, [:@ident, "local", [1, 92]]],
                [:zcall, [:@ident, "foo", [1, 99]]]],
               false]]]]]]]
      input_tree.should transform_to(output_tree)  
    end
  
    it 'does not let block variables escape into enclosing scopes' do
      input_tree =
        [:program,
         [[:assign, [:var_field, [:@ident, "x", [1, 0]]], [:@int, "5", [1, 4]]],
          [:method_add_block,
           [:call, [:array, nil], :".", [:@ident, "each", [1, 10]]],
           [:brace_block,
            [:block_var,
             [:params, [[:@ident, "y", [1, 18]]], nil, nil, nil, nil],
             [[:@ident, "z", [1, 20]], [:@ident, "x", [1, 23]]]],
            [[:var_ref, [:@ident, "x", [1, 26]]],
             [:var_ref, [:@ident, "y", [1, 28]]],
             [:var_ref, [:@ident, "z", [1, 30]]]]]],
          [:var_ref, [:@ident, "x", [1, 36]]],
          [:var_ref, [:@ident, "y", [1, 39]]],
          [:var_ref, [:@ident, "z", [1, 42]]]]]
      output_tree =
        [:program,
         [[:assign, [:var_field, [:@ident, "x", [1, 0]]], [:@int, "5", [1, 4]]],
          [:method_add_block,
           [:call, [:array, nil], :".", [:@ident, "each", [1, 10]]],
           [:brace_block,
            [:block_var,
             [:params, [[:@ident, "y", [1, 18]]], nil, nil, nil, nil],
             [[:@ident, "z", [1, 20]], [:@ident, "x", [1, 23]]]],
            [[:var_ref, [:@ident, "x", [1, 26]]],
             [:var_ref, [:@ident, "y", [1, 28]]],
             [:var_ref, [:@ident, "z", [1, 30]]]]]],
          [:var_ref, [:@ident, "x", [1, 36]]],
          [:zcall, [:@ident, "y", [1, 39]]],
          [:zcall, [:@ident, "z", [1, 42]]]]]
      input_tree.should transform_to(output_tree)
    end
  
    it 'creates closed scopes when classes are created' do
      input_tree =
        [:program,
         [[:assign, [:var_field, [:@ident, "x", [1, 0]]], [:@int, "5", [1, 4]]],
          [:class,
           [:const_ref, [:@const, "Foo", [1, 13]]],
           nil,
           [:bodystmt, [[:var_ref, [:@ident, "x", [1, 18]]]], nil, nil, nil]],
          [:var_ref, [:@ident, "x", [1, 26]]]]]
      output_tree =
        [:program,
         [[:assign, [:var_field, [:@ident, "x", [1, 0]]], [:@int, "5", [1, 4]]],
          [:class,
           [:const_ref, [:@const, "Foo", [1, 13]]],
           nil,
           [:bodystmt, [[:zcall, [:@ident, "x", [1, 18]]]], nil, nil, nil]],
          [:var_ref, [:@ident, "x", [1, 26]]]]]
      input_tree.should transform_to(output_tree)
    end
  
    it 'uses the previous scope for superclass specification' do
      input_tree =
        [:program,
         [[:assign,
           [:var_field, [:@ident, "x", [1, 0]]],
           [:var_ref, [:@const, "String", [1, 4]]]],
          [:class,
           [:const_ref, [:@const, "A", [1, 18]]],
           [:var_ref, [:@ident, "x", [1, 22]]],
           [:bodystmt, [[:var_ref, [:@ident, "x", [1, 25]]]], nil, nil, nil]]]]
      output_tree =
        [:program,
         [[:assign,
           [:var_field, [:@ident, "x", [1, 0]]],
           [:var_ref, [:@const, "String", [1, 4]]]],
          [:class,
           [:const_ref, [:@const, "A", [1, 18]]],
           [:var_ref, [:@ident, "x", [1, 22]]],
           [:bodystmt, [[:zcall, [:@ident, "x", [1, 25]]]], nil, nil, nil]]]]
      input_tree.should transform_to output_tree
    end
  
    it 'creates closed scopes when modules are created' do
      input_tree =
        [:program,
         [[:assign, [:var_field, [:@ident, "x", [1, 0]]], [:@int, "5", [1, 4]]],
          [:module,
           [:const_ref, [:@const, "Foo", [1, 14]]],
           [:bodystmt,
            [[:void_stmt], [:var_ref, [:@ident, "x", [1, 19]]]],
            nil,
            nil,
            nil]],
          [:var_ref, [:@ident, "x", [1, 27]]]]]
      output_tree =
        [:program,
         [[:assign, [:var_field, [:@ident, "x", [1, 0]]], [:@int, "5", [1, 4]]],
          [:module,
           [:const_ref, [:@const, "Foo", [1, 14]]],
           [:bodystmt,
            [[:void_stmt], [:zcall, [:@ident, "x", [1, 19]]]],
            nil,
            nil,
            nil]],
          [:var_ref, [:@ident, "x", [1, 27]]]]]
      input_tree.should transform_to output_tree
    end
  
    it 'creates closed scopes when singleton classes are opened' do
      input_tree =
        [:program,
         [[:assign, [:var_field, [:@ident, "x", [1, 0]]], [:@int, "5", [1, 4]]],
          [:sclass,
           [:var_ref, [:@const, "String", [1, 16]]],
           [:bodystmt, [[:var_ref, [:@ident, "x", [1, 24]]]], nil, nil, nil]]]]
      output_tree =
        [:program,
         [[:assign, [:var_field, [:@ident, "x", [1, 0]]], [:@int, "5", [1, 4]]],
          [:sclass,
           [:var_ref, [:@const, "String", [1, 16]]],
           [:bodystmt, [[:zcall, [:@ident, "x", [1, 24]]]], nil, nil, nil]]]]
      input_tree.should transform_to output_tree
    end
  
    it 'refers to the enclosing environment to determine the singleton to open' do
      input_tree =
        [:program,
         [[:assign,
           [:var_field, [:@ident, "x", [1, 0]]],
           [:string_literal, [:string_content, [:@tstring_content, "hi", [1, 5]]]]],
          [:sclass,
           [:var_ref, [:@ident, "x", [1, 19]]],
           [:bodystmt, [[:void_stmt]], nil, nil, nil]]]]
      input_tree.should transform_to input_tree
    end
  
    it 'refers to the enclosing environment to determine the singleton to open - resulting in zcall' do
      input_tree =
        [:program,
         [[:sclass,
           [:var_ref, [:@ident, "x", [1, 19]]],
           [:bodystmt, [[:void_stmt]], nil, nil, nil]]]]
      output_tree =
        [:program,
         [[:sclass,
           [:zcall, [:@ident, "x", [1, 19]]],
           [:bodystmt, [[:void_stmt]], nil, nil, nil]]]]
      input_tree.should transform_to output_tree
    end
  
    it 'observes the creation of local variables by rescue clauses' do
      input_tree =
        [:program,
         [[:def,
           [:@ident, "foo", [1, 4]],
           [:paren, [:params, [[:@ident, "x", [1, 8]]], nil, nil, nil, nil]],
           [:bodystmt,
            [[:void_stmt],
             [:assign,
              [:var_field, [:@ident, "y", [1, 12]]],
              [:binary,
               [:@int, "1", [1, 16]],
               :/,
               [:var_ref, [:@ident, "x", [1, 20]]]]]],
            [:rescue,
             [[:var_ref, [:@const, "Exception", [1, 30]]]],
             [:var_field, [:@ident, "err", [1, 43]]],
             [[:command,
               [:@ident, "p", [1, 48]],
               [:args_add_block, [[:var_ref, [:@ident, "err", [1, 50]]]], false]]],
             nil],
            [:else,
             [[:void_stmt],
              [:command,
               [:@ident, "p", [1, 61]],
               [:args_add_block, [[:var_ref, [:@ident, "err", [1, 63]]]], false]]]],
            [:ensure,
             [[:void_stmt],
              [:command,
               [:@ident, "p", [1, 76]],
               [:args_add_block, [[:var_ref, [:@ident, "err", [1, 78]]]], false]]]]]]]]
      input_tree.should transform_to input_tree
    end
  
    it 'handles rescue clauses normally otherwise' do
      input_tree =
        [:program,
         [[:def,
           [:@ident, "foo", [1, 4]],
           [:paren, [:params, [[:@ident, "x", [1, 8]]], nil, nil, nil, nil]],
           [:bodystmt,
            [[:void_stmt],
             [:assign,
              [:var_field, [:@ident, "y", [1, 12]]],
              [:binary,
               [:@int, "1", [1, 16]],
               :/,
               [:var_ref, [:@ident, "x", [1, 20]]]]]],
            [:rescue,
             [[:var_ref, [:@const, "Exception", [1, 30]]]],
             nil,
             [[:command,
               [:@ident, "p", [1, 48]],
               [:args_add_block, [[:var_ref, [:@ident, "err", [1, 50]]]], false]]],
             nil],
            [:else,
             [[:void_stmt],
              [:command,
               [:@ident, "p", [1, 61]],
               [:args_add_block, [[:var_ref, [:@ident, "err", [1, 63]]]], false]]]],
            [:ensure,
             [[:void_stmt],
              [:command,
               [:@ident, "p", [1, 76]],
               [:args_add_block, [[:var_ref, [:@ident, "err", [1, 78]]]], false]]]]]]]]
      output_tree =
        [:program,
         [[:def,
           [:@ident, "foo", [1, 4]],
           [:paren, [:params, [[:@ident, "x", [1, 8]]], nil, nil, nil, nil]],
           [:bodystmt,
            [[:void_stmt],
             [:assign,
              [:var_field, [:@ident, "y", [1, 12]]],
              [:binary,
               [:@int, "1", [1, 16]],
               :/,
               [:var_ref, [:@ident, "x", [1, 20]]]]]],
            [:rescue,
             [[:var_ref, [:@const, "Exception", [1, 30]]]],
             nil,
             [[:command,
               [:@ident, "p", [1, 48]],
               [:args_add_block, [[:zcall, [:@ident, "err", [1, 50]]]], false]]],
             nil],
            [:else,
             [[:void_stmt],
              [:command,
               [:@ident, "p", [1, 61]],
               [:args_add_block, [[:zcall, [:@ident, "err", [1, 63]]]], false]]]],
            [:ensure,
             [[:void_stmt],
              [:command,
               [:@ident, "p", [1, 76]],
               [:args_add_block, [[:zcall, [:@ident, "err", [1, 78]]]], false]]]]]]]]
      input_tree.should transform_to output_tree
    end
  end
  describe 'error transformation' do
    it 'should push up module name errors' do
      input_tree =
        [:program,
         [[:module,
           [:const_ref, [:class_name_error, [:@ident, "a", [1, 7]]]],
           [:bodystmt, [[:void_stmt]], nil, nil, nil]]]]
      output_tree =
        [:program,
         [[:error,
           [:module,
            [:const_ref, [:class_name_error, [:@ident, "a", [1, 7]]]],
            [:bodystmt, [[:void_stmt]], nil, nil, nil]]]]]
      input_tree.should transform_to output_tree
    end
    
    it 'should push up class name errors' do
      input_tree =
        [:program,
         [[:class,
           [:const_ref, [:class_name_error, [:@ident, "a", [1, 6]]]],
           nil,
           [:bodystmt, [[:void_stmt]], nil, nil, nil]]]]
      output_tree =
        [:program,
         [[:error,
           [:class,
            [:const_ref, [:class_name_error, [:@ident, "a", [1, 6]]]],
            nil,
            [:bodystmt, [[:void_stmt]], nil, nil, nil]]]]]
      input_tree.should transform_to output_tree
    end

    it 'wraps single assignments in :error if they assign read-only gvars' do
      input_tree =
        [:program,
         [[:assign, [:assign_error, [:@backref, "$`", [1, 0]]], [:@int, "3", [1, 5]]]]]
      output_tree =
        [:program,
         [[:error, [:assign, [:assign_error, [:@backref, "$`", [1, 0]]], [:@int, "3", [1, 5]]]]]]
      input_tree.should transform_to output_tree
    end

    it 'wraps multiple assignments in :error if they assign read-only gvars' do
      input_tree =
        [:program,
         [[:massign,
           [[:@ident, "a", [1, 0]],
            [:@ident, "b", [1, 3]],
            [:assign_error, [:var_field, [:@backref, "$&", [1, 6]]]]],
           [:mrhs_add_star,
            [],
            [:paren, [[:dot2, [:@int, "1", [1, 13]], [:@int, "3", [1, 16]]]]]]]]]
      output_tree =
        [:program,
         [[:error,
           [:massign,
            [[:@ident, "a", [1, 0]],
             [:@ident, "b", [1, 3]],
             [:assign_error, [:var_field, [:@backref, "$&", [1, 6]]]]],
            [:mrhs_add_star,
             [],
             [:paren, [[:dot2, [:@int, "1", [1, 13]], [:@int, "3", [1, 16]]]]]]]]]]
      input_tree.should transform_to output_tree
    end

    it 'wraps assignments in :error if they assign read-only vars deep in subassignments' do
      input_tree =
        [:program,
         [[:massign,
           [[:@ident, "a", [1, 0]],
            [:mlhs_paren,
             [:mlhs_add_star,
              [[:@ident, "b", [1, 4]]],
              [:@ident, "c", [1, 8]],
              [[:mlhs_paren,
                [[:assign_error, [:var_field, [:@backref, "$1", [1, 12]]]],
                 [:@ident, "d", [1, 16]]]]]]]],
           [:mrhs_add_star,
            [],
            [:method_add_arg,
             [:fcall, [:@ident, "foo", [1, 23]]],
             [:arg_paren, nil]]]]]]
      output_tree =
        [:program,
         [[:error,
           [:massign,
            [[:@ident, "a", [1, 0]],
             [:mlhs_paren,
              [:mlhs_add_star,
               [[:@ident, "b", [1, 4]]],
               [:@ident, "c", [1, 8]],
               [[:mlhs_paren,
                 [[:assign_error, [:var_field, [:@backref, "$1", [1, 12]]]],
                  [:@ident, "d", [1, 16]]]]]]]],
            [:mrhs_add_star,
             [],
             [:method_add_arg,
              [:fcall, [:@ident, "foo", [1, 23]]],
              [:arg_paren, nil]]]]]]]
      input_tree.should transform_to output_tree
    end
    
    it 'wraps alias errors with a standard :error node' do
      input_tree =
        [:program,
         [[:alias_error,
           [:var_alias, [:@gvar, "$foo", [1, 6]], [:@backref, "$1", [1, 11]]]]]]
      output_tree =
        [:program,
         [[:error, [:alias_error,
           [:var_alias, [:@gvar, "$foo", [1, 6]], [:@backref, "$1", [1, 11]]]]]]]
      input_tree.should transform_to output_tree
    end
    
    it 'wraps dynamic assignments to constants in :error nodes' do
      input_tree =
        [:program,
         [[:def,
           [:@ident, "foo", [1, 4]],
           [:params, nil, nil, nil, nil, nil],
           [:bodystmt,
            [[:assign, [:var_field, [:@const, "C", [1, 9]]], [:@int, "5", [1, 13]]]],
            nil,
            nil,
            nil]]]]
      output_tree =
        [:program,
         [[:def,
           [:@ident, "foo", [1, 4]],
           [:params, nil, nil, nil, nil, nil],
           [:bodystmt,
            [[:error, [:assign, [:var_field, [:@const, "C", [1, 9]]], [:@int, "5", [1, 13]]]]],
            nil,
            nil,
            nil]]]]
      input_tree.should transform_to output_tree
    end
    
    it 'wraps dynamic assignments in massigns in :error nodes' do
      input_tree =
        [:program,
         [[:defs,
           [:var_ref, [:@kw, "self", [1, 4]]],
           [:@period, ".", [1, 8]],
           [:@ident, "foo", [1, 9]],
           [:params, nil, nil, nil, nil, nil],
           [:bodystmt,
            [[:massign,
              [[:@ident, "a", [1, 14]],
               [:mlhs_paren,
                [[:@ident, "b", [1, 18]],
                 [:mlhs_paren,
                  [[:@gvar, "$c", [1, 22]],
                   [:const_path_field,
                    [:var_ref, [:@kw, "self", [1, 26]]],
                    [:@const, "D", [1, 32]]]]]]]],
              [:mrhs_add_star, [], [:var_ref, [:@const, "CONST", [1, 39]]]]]],
            nil, nil, nil]]]]
      output_tree =
        [:program,
         [[:defs,
           [:var_ref, [:@kw, "self", [1, 4]]],
           [:@period, ".", [1, 8]],
           [:@ident, "foo", [1, 9]],
           [:params, nil, nil, nil, nil, nil],
           [:bodystmt,
            [[:error, [:massign,
              [[:@ident, "a", [1, 14]],
               [:mlhs_paren,
                [[:@ident, "b", [1, 18]],
                 [:mlhs_paren,
                  [[:@gvar, "$c", [1, 22]],
                   [:const_path_field,
                    [:var_ref, [:@kw, "self", [1, 26]]],
                    [:@const, "D", [1, 32]]]]]]]],
              [:mrhs_add_star, [], [:var_ref, [:@const, "CONST", [1, 39]]]]]]],
            nil, nil, nil]]]]
      input_tree.should transform_to output_tree
    end
    
    it 'wraps classes in method bodies with error nodes' do
      input_tree =
        [:program,
         [[:def,
           [:@ident, "foo", [1, 4]],
           [:params, nil, nil, nil, nil, nil],
           [:bodystmt,
            [[:class,
              [:const_ref, [:@const, "A", [1, 15]]],
              nil,
              [:bodystmt, [[:void_stmt]], nil, nil, nil]]],
            nil,
            nil,
            nil]]]]
      output_tree =
        [:program,
         [[:def,
           [:@ident, "foo", [1, 4]],
           [:params, nil, nil, nil, nil, nil],
           [:bodystmt,
            [[:error, [:class,
              [:const_ref, [:@const, "A", [1, 15]]],
              nil,
              [:bodystmt, [[:void_stmt]], nil, nil, nil]]]],
            nil,
            nil,
            nil]]]]
      input_tree.should transform_to output_tree
    end
    
    it 'wraps modules in method bodies with error nodes' do
      input_tree =
        [:program,
         [[:def,
           [:@ident, "foo", [1, 4]],
           [:params, nil, nil, nil, nil, nil],
           [:bodystmt,
            [[:module,
              [:const_ref, [:@const, "A", [1, 15]]],
              [:bodystmt, [[:void_stmt]], nil, nil, nil]]],
            nil,
            nil,
            nil]]]]
      output_tree =
        [:program,
         [[:def,
           [:@ident, "foo", [1, 4]],
           [:params, nil, nil, nil, nil, nil],
           [:bodystmt,
            [[:error, [:module,
              [:const_ref, [:@const, "A", [1, 15]]],
              [:bodystmt, [[:void_stmt]], nil, nil, nil]]]],
            nil,
            nil,
            nil]]]]
      input_tree.should transform_to output_tree
    end
    
    %w(FOO @foo @@foo $foo).each do |bad_var|
      [['singleton', 'String.', :defs], ['normal', '', :def]].each do |kind, prefix, fail_node|
        it "wraps #{kind} definitions with #{bad_var} as a positional argument name with :error" do
          input_code = "def #{prefix}foo(a, #{bad_var}, *rest); end"
          tree = RipperPlus.sexp(input_code)
          error = dfs_for_node_type(tree, :error)
          error[1][0].should be fail_node
        end

        it "wraps #{kind} definitions with #{bad_var} as a second-section positional argument name with :error" do
          input_code = "def #{prefix}foo(a, b=2, #{bad_var}); end"
          tree = RipperPlus.sexp(input_code)
          error = dfs_for_node_type(tree, :error)
          error[1][0].should be fail_node
        end
      end
    end
    
  end
end

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe RipperPlus::Transformer do
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
end

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
    RipperPlus::Transformer.transform(input_tree).should == output_tree
  end
end

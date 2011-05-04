# ripper-plus

Ripper is the Ruby parser library packaged with Ruby 1.9. While quite complete, it still has bugs (2 of which I've patched alone while working on Laser, with the fixes targeted for 1.9.3: [mlhs-splats](http://redmine.ruby-lang.org/issues/4364) and [words/qwords](http://redmine.ruby-lang.org/issues/4365)), and it has higher-level quirks that can make use frustrating. ripper-plus is a gem intended to demonstrate what I believe the correct output from Ripper should be, *with the goal that these changes become the standard Ripper behavior*. I do *not* want to invent nor maintain a new AST standard. I do however believe these changes warrant separate implementation and discussion before a potential integration with Ripper, and creating a small library to demonstrate the proposed output seemed the simplest approach. Plus, [Laser](https://github.com/michaeledgar/laser/) needs all these improvements, so I had to do it anyway.

NB: Ripper is a SAX-style parser; one can construct an AST from the parser events however one wishes. Ripper also has a convenience method `Ripper.sexp`, which generates an Array-based AST directly from the SAX events. I personally use `Ripper.sexp` in my work, so the examples will be of `Ripper.sexp` output. All of the discussion below reflects deficiencies in the underlying SAX parser: they are unavoidable whether one uses `Ripper.sexp` or not.

## tl;dr Version

If you don't want to read everything, here's what you should take away:

1. Ripper does not distinguish between reading a local variable and implicit-self, no-paren, no-argument method calls. Due to Ruby's semantics, this must be done by the parser. Example: `y = foo`. Is foo a method call? Ripper does not tell you.
2. Ruby's Bison grammar rejects some invalid syntax not by restricting the grammar, but by parsing with a more permissive grammar and then validating the results. Ripper does report some of these errors in its parse tree, but not all of them, and sometimes inconveniently deep in the parse tree. Example: `proc { |a, a| }` is a syntax error, but Ripper parses it without flinching.

## Still Here?

If you use Ripper for anything important, I'll assume you've gotten this far. Quick info about `ripper-plus`: it is a gem I hope will correct the following issues until they are addressed in Ripper proper. To use `ripper-plus`, install it with `gem install ripper-plus`. The gem has two entry points:

    require 'ripper-plus'
    # Returns an AST from Ripper, modified as described below
    RipperPlus.sexp(any_input_object_Ripper_accepts)
    # Transforms a Ripper AST into a RipperPlus AST, as described below
    RipperPlus.for_ripper_ast(some_ripper_ast)
    # Transforms a Ripper AST into a RipperPlus AST, in-place
    RipperPlus.for_ripper_ast(some_ripper_ast, :in_place => true)

That's it - now read about why exactly ripper-plus exists.

# Bareword Resolution

In Ruby, a local variable is created when it is assigned to. If Ruby finds a bareword `foo` before an assignment `foo = 5`, then Ruby will call `self.foo()`.

Kind of.

What happens when you run this code?

    
    def label
      'hello'
    end
    def print_label
      label = 'Label: ' + label
      puts label
    end
    print_label


If one takes the intuitive approach, one would assume it prints "Label: hello", right? Afraid not: it errors out. The intuitive approach says that `'Label: ' + label` is run before the assignment to the local variable `label`, so the `label` method will be called and appended to `"Label: "`. In reality, it won't, because local variables aren't created on assignment. Local variables are created *immediately when the Ruby parser parses a left-hand-side local variable*. Before the right-hand-side is even parsed, the local variable has been created. This also results in an infamous anomaly:

[code]
    def say_what?
      x = 'hello' unless defined?(x)
      puts x
    end
[/code]

`say_what?` prints a blank line! This is because as soon as the `x` on the LHS is parsed, `x` is a local variable with value `nil`. By the time `defined?(x)` is executed, `x` has long since been a local variable!

This is further complicated by the many ways a local variable can be introduced:

1. Single- or multiple-assignment (including sub-assignment) anywhere an expression is allowed
2. A `for` loop's iterator variable(s)
3. Formal arguments to a method
4. Block arguments and block-local variables
5. Stabby Lambda variables
6. Rescue exception naming (`rescue StandardError => err`)
7. Named Regexp captures in literal matches (`/name: (?<person>\w+)/ =~ 'name: Mike'` creates a local variable named "person" with value "Mike")

I think that's a complete list, but I may be mistaken. In fact, I had forgotten named captures until I double-checked this list while writing this blog post. I tried to find all paths in `parse.y` to a call to `assignable()`, the C function in Ruby's parser that creates local variable in the current scope, and I think I caught them all, but I may have slipped up.

## Ripper's Mistake

Ripper doesn't carry scope information as it parses, and as such, parses any lone identifier as an AST node of type `:var_ref`. It is up to consumers of the AST to figure out the meaning of the `:var_ref` node. It can be reasonably argued that the semantics of the `:var_ref` node should not be part of the AST, as my thesis adviser pointed out when I complained about this, as the two are syntactically identical. Unfortunately, the meaning of the `:var_ref` node comes from the parser itself; any attempt to determine semantics based solely on the Ripper AST must simulate the work the parser ordinarily does. Indeed, when Ruby parses the code for execution, it *does* create different internal node types upon seeing a method-call bareword and a local variable bareword!

I'd like to see this behavior rolled into Ripper proper. Until then, `ripper-plus` is a reasonable replacement.

## ripper-plus's Approach

By using our knowledge of Ruby's parser, we can simulate the scope-tracking behavior by walking the AST generated by Ripper. We simply do normal scope tracking, observe the creation of local variables, and ensure that we walk each node of the tree in the order in which those nodes would have been parsed. Most subtrees generated by Ripper are already in this order, with the exception of the modifier nodes (`foo.bar if baz`, `x = bar() while x != nil`). Most importantly, since everything<sup>[*](http://carboni.ca/blog/p/Statements-in-Ruby)</sup> is an expression in Ruby and local variable assignments can occur just about anywhere, exact scoping semantics must be recreated. Every possible introduction of local variables (exception naming, named captures, ...) must be considered as the Ruby parser would. Corner cases such as this:

[code]
    def foo(x, y = y)
    end
[/code]

Need to be properly resolved. Did you know that, unlike the `label = label` example above, the above code is equivalent to:

[code]
    def foo(x, y = y())
    end
[/code]

Why doesn't y end up `nil` in the default case, as it would if you typed `y = y` into a method definition?

Anyway, ripper-plus turns all method-call `:var_ref` nodes into `:zcall` nodes; the node structure is otherwise unchanged. I believe Ripper should already make this distinction, and it can relatively simply: it simply has to re-implement the existing scope-tracking behavior to the relevant Ripper action routines. Not trivial, but `ripper-plus` does it in a couple hundred lines of Ruby.

# Error Handling

As mentioned above, not all invalid syntaxes are excluded by Ruby's CFG production rules: additional validation happens occasionally, and when validation fails, `yyerror` is called, and parsing attempts recovery. The Ruby program will not run if such an error exists, but since parsing continues, additional such errors might be found. These are some of (but likely not all) of the errors I'm describing:

1. `class name ... end`/`module name ... end` with a non-constant name (`=~ /^[^A-Z]/`)
2. `alias gvar $[0-9]`: you can't alias the numeric capture variables
3. duplicate argument names to a method, block
4. constant/instance variable/class variable/global variable as an argument name
5. assigning a constant in a method definition
6. class/module definition syntax in a method body
7. defining singleton methods on literals using expression syntax (`def (expr).foo; end`)

Whatever your tool is that is dealing with Ruby ASTs, it likely is concerned with whether the program is valid or not, and any program containing the above errors is invalid: Ruby won't even attempt to run it. Ripper, one would suppose, would also inform consumers of the parse tree that a given program is invalid in these ways.

## Ripper's Mistake

Some of these errors are noticed by Ripper, and the offending portion of the syntax tree will be wrapped in a corresponding error node:

[code]
    # Invalid alias
    pp Ripper.sexp('alias $foo $2')
    #=>[:program,
        [[:alias_error,
          [:var_alias, [:@gvar, "$foo", [1, 6]], [:@backref, "$2", [1, 11]]]]]]
    # Invalid class name
    pp Ripper.sexp('class abc; end')
    => [:program,
         [[:class,
           [:const_ref, [:class_name_error, [:@ident, "abc", [1, 6]]]],
           nil,
           [:bodystmt, [[:void_stmt]], nil, nil, nil]]]]
[/code]

The first error, a disallowed alias, results in an `:alias_error` node wrapping the entire `:var_alias` node. This is good: anybody walking this AST would see that the entire contents of the node are semantically invalid *before* any information about the attempted alias. The second error, an invalid class name, results in a `:class_name_error` node deep in the `:class` node structure. This is bad: it puts the onus on every consumer of the AST to check all class/module definitions for `:class_name_error` nodes before assuming *anything* about the meaning of the `:class` node. This unfortunate placement also occurs when a parameter is named with a non-identifier:

[code]
    pp Ripper.sexp('def foo(a, @b); end')
    => [:program,
         [[:def,
           [:@ident, "foo", [1, 4]],
           [:paren,
            [:params,
             [[:@ident, "a", [1, 8]], [:param_error, [:@ivar, "@b", [1, 11]]]],
             nil, nil, nil, nil]],
           [:bodystmt, [[:void_stmt]], nil, nil, nil]]]]
[/code]

Worse, some errors are not caught at all:

[code]
    pp Ripper.sexp('def foo(a, a, a); end')
    => [:program,
         [[:def,
           [:@ident, "foo", [1, 4]],
           [:paren,
            [:params,
             [[:@ident, "a", [1, 8]],
              [:@ident, "a", [1, 11]],
              [:@ident, "a", [1, 14]]],
             nil, nil, nil, nil]],
           [:bodystmt, [[:void_stmt]], nil, nil, nil]]]]
[/code]

This is very bad. Now every consumer of the Ripper parse tree must check *all method definitions* for repeated arguments, and bail accordingly. Don't forget about subassignments in block argument declarations; you'll need to check those yourself, too:

[code]
    pp Ripper.sexp('something.each { |a, (b, *c, (d, e), a), f| }')
    => [:program,
         [[:method_add_block,
           [:call,
            [:var_ref, [:@ident, "something", [1, 0]]], :".",
            [:@ident, "each", [1, 10]]],
           [:brace_block, [:block_var,
             [:params,
              [[:@ident, "a", [1, 18]],
               [:mlhs_paren,
                [:mlhs_add_star,
                 [[:mlhs_paren, [:@ident, "b", [1, 22]]]],
                 [:@ident, "c", [1, 26]]]],
               [:@ident, "f", [1, 41]]],
              nil, nil, nil, nil], nil],
            [[:void_stmt]]]]]]
[/code]

Can your Ripper-consuming code handle that case?

## ripper-plus's Approach

This is where it gets murky, and I don't have a definitive answer just yet. Right now, `ripper-plus` wraps all offending nodes it finds (which is *not* all such errors - yet) in a generic `:error` node. At least with this solution, anyone walking a `RipperPlus` AST will know when a given node is semantically invalid. However, the code walking the AST must find an `:error` node before it knows the entire AST is meaningless. For a tool like [YARD](http://yardoc.org/) or [Redcar](http://redcareditor.com/), which likely would prefer to keep extracting information from the AST, this seems preferable. The `:error` node could potentially be specified to potentially include descriptions and locations of the syntax errors discovered.

Yet it also seems convenient to receive, upon attempting to parse an invalid program, a simple list of errors and nothing else. For a tool like Laser, this is far preferable, and wastes a lot less time. I think Laser may be in the minority here. So Laser will do its own thing regardless.

# Minor Gripes

1. Flip-flops don't have their own node type. Upon encountering a range, you must check if you are in a conditional context manually. This is annoying.
2. \_\_END\_\_ just stops parsing: there's no getting at the actual data past it from Ripper's output.
3. Ripper.sexp never fails. Given a program that fails to parse, Ripper will simply return the best recovery parse Bison can come up with. (`Ripper.sexp('x*^y#$a') == [:program, [:var_ref, [:@ident, "y", [1, 3]]]]`)
4. This space reserved for future gripes.

## Conclusion

Overall, Ripper is very complete for a library covered in "EXPERIMENTAL" warning labels, and gives concise, traditional ASTs. What I've put forward is all I ask after nearly a year of being neck-deep in Ripper output. I think the main two points I've covered need to be addressed in the 1.9 branch of Ruby, and over the coming months, hope to work to get that done.

In the meantime, I'll be using `ripper-plus` in Laser to statically analyze all kinds of stuff about Ruby, but I look forward to the day where I can add `RipperPlus = Ripper if RUBY_VERSION >= MERGED_VERSION` to ripper-plus's main file. `ripper-plus` is O(N), though it's not blazingly fast: it takes about 20-30 ms on my machine to transform the Ripper AST for [the biggest, ugliest Laser code file: the CFG compiler](https://github.com/michaeledgar/laser/blob/master/lib/laser/analysis/control_flow/cfg_builder.rb) to a RipperPlus AST. It takes 50ms for Ripper to parse it in the first place. (That benchmarked transformation is done in-place: `ripper-plus`'s default behavior is to duplicate the Ripper AST.)

## Contributing to ripper-plus
 
* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it
* Fork the project
* Start a feature/bugfix branch
* Commit and push until you are happy with your contribution
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.

## Copyright

Copyright (c) 2011 Michael Edgar. See LICENSE.txt for
further details.
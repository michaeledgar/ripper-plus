# Top-level module for Ripper Plus. Provides global methods for
# getting a RipperPlus AST for a given input program.
module RipperPlus
  DEFAULT_OPTS = {:in_place => false}
  # Parses the given Ruby code into a RipperPlus AST.
  def self.sexp(text, opts={})
    for_ripper_ast(Ripper.sexp(text), opts.merge(:in_place => true))
  end
  
  # Transforms the provided Ripper AST into a RipperPlus AST.
  def self.for_ripper_ast(tree, opts={})
    opts = DEFAULT_OPTS.merge(opts)
    Transformer.transform(tree, opts)
  end
end
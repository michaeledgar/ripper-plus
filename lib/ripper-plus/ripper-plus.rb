# Top-level module for Ripper Plus. Provides global methods for
# getting a RipperPlus AST for a given input program.
module RipperPlus
  # Parses the given Ruby code into a RipperPlus AST.
  def self.sexp(text)
    for_ripper_ast(Ripper.sexp(text))
  end
  
  # Transforms the provided Ripper AST into a RipperPlus AST.
  def self.for_ripper_ast(tree)
    Transformer.transform(tree)
  end
end
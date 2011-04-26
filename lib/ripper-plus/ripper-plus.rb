# Top-level module for Ripper Plus. Provides global methods for
# getting a RipperPlus AST for a given input program.
module RipperPlus
  def self.sexp(text)
    Transformer.transform(Ripper.sexp(text))
  end
end
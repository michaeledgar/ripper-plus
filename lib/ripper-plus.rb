if RUBY_VERSION < "1.9"
  raise 'ripper-plus requires Ruby 1.9+'
end
require 'ripper'
require 'ripper-plus/ripper-plus'
require 'ripper-plus/scope_stack'
require 'ripper-plus/transformer'
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'rspec'
require 'ripper-plus'

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

RSpec::Matchers.define :transform_to do |output|
  match do |input|
    RipperPlus::Transformer.transform(input) == output
  end

  diffable
end

def dfs_for_node_type(tree, type)
  if tree[0] == type
    return tree
  else
    tree.select { |child| Array === child }.each do |child|
      result = dfs_for_node_type(child, type)
      return result if result
    end
  end
  nil
end

RSpec.configure do |config|
  config.filter_run focus: true
  config.run_all_when_everything_filtered = true
end

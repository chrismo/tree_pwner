require './lib/tree_pwner_cli'
@tp = TreePwnerCli.new('the.chrismo@gmail.com', 'chrismo@clabs.org')
# There's an automatic way to do this - a bit awkward. Need to look it up.
puts "Type 'cd @tp' to get into the TreePwnerCli instance:"
puts "Type 'commands' once in there to get additional help."
module Cake
  VERSION = "0.1.1"
end

require 'cake/session'
require 'cake/rubycompiler'
require 'cake/compilers/c'
#require 'cake/compilers/java'
require 'cake/platforms/mingw'
require 'cake/commands/compile'
require 'cake/commands/crossruby'


module LavaCake
  VERSION = "0.1"
end

require 'lavacake/session'
require 'lavacake/compiler'
require 'lavacake/rubycompiler'
require 'lavacake/compilers/c'
#require 'lavacake/compilers/java'
require 'lavacake/platforms/mingw'
require 'lavacake/commands/compile'
require 'lavacake/commands/crossruby'


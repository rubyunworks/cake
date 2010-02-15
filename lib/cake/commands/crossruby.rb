require 'cake/rubycompiler'
require 'optparse'

module Cake
module Command

  #
  class CrossRuby

    #
    def self.run
      new.run
    end

    #
    def parser
      OptionParser.new do |opts|

        opts.on("--source", "-s [URL]", "URL for Ruby source code") do |url|
          @source = url
        end

        opts.on("--version", "ruby version") do |ver|
          @version = ver
        end

        opts.on("--make [CMD]", "system's make command") do |cmd|
          @make_command = cmd
        end

        opts.on("--force", "force overwrites") do
          @force = true
        end

        opts.on("--debug", "turn on DEBUG mode") do
          $DEBUG = true
        end

        opts.on("--help", "-h", "show this help message") do
          puts opts
          exit
        end
      end
    end

    #
    def run
      parser.parse!

      compiler = RubyCompiler.new do |cc|
        cc.version        = @version
        cc.ruby_source    = @source
        cc.make_command   = @make_command
        cc.force          = @force
        cc.config_options = config_options
      end

      case ARGV.first
      when 'clean'
        compiler.clean
      when 'clobber'
        compiler.clobber
      when 'compile', '--', nil
        compiler.compile_ruby
      else
        $stderr.puts "Unknown command -- #{argv.first}"
        exit
      end
    end

    #
    def config_options
      argv = ARGV.dup
      argv.shift until (argv.first == '--' or argv.first.nil?)
      argv.shift
      argv
    end

  end

end
end


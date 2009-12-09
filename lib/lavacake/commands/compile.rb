require 'lavacake/session'

module LavaCake
module Command

  #
  class Compile

    attr :session

    #
    def initialize
      @session = Session.new
    end

    #
    def parser
      OptionParser.new do |opts|
        opts.on('--platform', '-p [PLATFORM]', "platform") do |platform|
          session.platform = platform
        end

        opts.on('--lib [DIR]', "put binaries into this folder") do |dir|
          session.lib_dir = dir
        end

        opts.on('--tmp [DIR]', "temporary folder used during compilation.") do |dir|
          session.tmp_dir = dir
        end

        opts.on('--source-pattern [PATTERN]', "monitor file changes to allow simple rebuild (eg. '*.{c,cpp}')") do |pattern|
          session.source_pattern = pattern
        end

        opts.on('--config-script [SCRIPT]', "use instead of 'extconf.rb' default") do |script|
          session.config_script = script
        end

        #opts.on('--config-option', '[OPTION]')

        #ext.name = 'hello_world'                # indicate the name of the extension.
        #ext.ext_dir = 'ext/weird_world'         # search for 'hello_world' inside it.

        #ext.config_options << '--with-foo'      # supply additional configure options to config script.

        #ext.gem_spec = spec                 # optional indicate which gem specification
                                            # will be used to based on.

        opts.on('--trace', "trace execution in detail") do
          session.trace = true
        end
      end

    end

    #
    def parse
      parser.parse!

      ARGV.each do |ext|
        break if ext == "--"
        session.extensions << ext
      end

      session.config_options = ARGV.dup
    end

    #
    def run
      parse
      session.compile
    end

  end

end
end


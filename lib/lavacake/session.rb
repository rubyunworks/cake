module LavaCake

  #
  #
  class Session

    attr_accessor :names

    attr_accessor :extensions

    attr_accessor :platforms

    attr_accessor :no_native

    attr_accessor :ext_dir


    attr_accessor :tmp_dir

    attr_accessor :lib_dir

    attr_accessor :config_script

    attr_accessor :config_options

    #attr_accessor :cross_config_options

    # New compile session.
    #
    def initialize(names=nil) #:yeild:
      @names     = names
      @platforms = [RUBY_PLATFORM]
      @no_native = false
      @ext_dir   = 'ext'

      @tmp_dir        = nil
      @lib_dir        = nil
      @config_script  = nil
      @config_options = nil
      #@cross_config_options = nil

      yield(self) if block_given?

      if @no_native
        @platforms -= [RUBY_PLATFORM]
        if @platforms.empty?
          @platforms = ['i386-mingw32']
        end
      end

      if names
        @extensions = names.map{ |name| File.join(@ext_dir, name) }
        raise ArgumentError if @extensions.any?{ |dir| !File.directory?(dir) }
      end        
    end

    # List of extensions to compile.
    def extensions
      @extensions ||= Dir[File.join(@ext_dir, '*')]
    end

    #
    def compile
      extensions.each do |location|
        platforms.each do |platform|
          compile_extension(location, platform)
        end
      end
    end

  private

    # +extension+ - path to extension
    #
    def compile_extension(extension, platform)
      compiler_options = compiler_options()
      compiler_class   = compiler_class(extension)

      compiler_options[:platform] = platform

      compiler = compiler_class.new(extension, compiler_options)

      compiler.compile
    end

    # Returns the compiler class to be used for a given extension.
    #
    def compiler_class(extension)
      if cname = compiler_setting(extension)
        compname = Compiler.register.find{ |c| c.name.split('::').last == cname }
        compiler = const_get(compname)::Compiler
      else
        Compiler.register.find do |c|
          c.compile?(extension)
        end
      end
    end

    # Compiler options that can be overriden.
    #
    def compiler_options
      options = {}
      options['tmp_dir']        = @tmp_dir        if @tmp_dir
      options['lib_dir']        = @lib_dir        if @lib_dir
      options['config_script']  = @config_script  if @config_script
      options['config_options'] = @config_options if @config_options
      #options['cross_config_options'] = @cross_config_options
      options
    end

=begin
    #
    def multi_compile
      if ruby_vers = ENV['RUBY_CC_VERSION']
        ruby_vers = ENV['RUBY_CC_VERSION'].split(':')
      else
        ruby_vers = [RUBY_VERSION]
      end

      multi = (ruby_vers.size > 1) ? true : false

      ruby_vers.each do |version|
        # tweak lib directory only when targeting multiple versions
        if multi
          version =~ /(\d+.\d+)/
          lib_dir = "#{@lib_dir}/#{$1}"
        end
        #
        compile(:lib_dir=>lib_dir, :ruby_ver=>version)
      end
    end
=end

    # Get compiler setting from .lavacake file, if present.
    def compiler_setting(location)
      file = File.join(location, '.lavacake')
      if File.exist?(file)
        pref = YAML.load(File.new(file))
      else
        pref = {}
      end
      pref['compiler']
    end

  end

end


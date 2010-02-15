require 'rbconfig'
require 'yaml'
require 'pathname'

require 'facets/filelist' # maybe Path::List or copy here

module Cake
module Abstract

  # 
  class Compiler

    def self.register
      @register ||= []
    end

    def self.inherited(klass)
      register << klass
    end

    attr_accessor :name
    attr_accessor :tmp_dir
    attr_accessor :ext_dir
    attr_accessor :lib_dir
    attr_accessor :platform
    attr_accessor :config_options
    attr_accessor :source_pattern

    attr_reader :clean
    attr_reader :clobber

    #
    def initialize(ext_dir, options={}) #:yeild:
      @ext_dir  = ext_dir

      fail "Extension location must be provided." unless @ext_dir

      @tmp_dir = 'tmp'
      @lib_dir = 'lib'

      @config_options = []

      @clean   = []
      @clobber = []

      initialize_special_options

      options.each do |k,v|
        __send__("#{k}=", v) if respond_to?("#{k}=") && v
      end

      yield(self) if block_given?
    end

    #
    def initialize_special_options
      options = settings(location, platform)
      options.each do |k,v|
        __send__("#{k}=", v) if respond_to?("#{k}=")
      end
    end

    # You can place a build configuration file in your extension directory
    # with the name '.lavacake'. The file is a YAML file that conatins
    # configuration entries to be passed to the compiler.
    #
    # Besides top level entries which apply to all compilations, you can add
    # platform and ruby version sub-entries to differentiate builds. Eg.
    #
    #   ---
    #   compiler: C
    #   x86_64-linux:
    #     config_script: extconfig64.rb
    #     1.8.7:
    #       config_options: "--exclude=foolib"
    #
    def settings(location, platform)
      file = File.join(location, '.lavacake')

      if File.exist?(file)
        pref = YAML.load(File.new(file))
      else
        pref = {}
      end

      set = {}
      settings_update(set, pref)
      settings_update(set, pref[ruby_ver])
      settings_update(set, pref[platform])
      settings_update(set, pref[ruby_ver][platform]) if pref[ruby_ver]
      settings_update(set, pref[platform][ruby_ver]) if pref[platform]
      return set
    end

    #
    def settings_update(hash, other)
      return unless other
      other.each do |k,v|
        hash[k] = v unless Hash === v
      end
      hash
    end

    #
    def name
      File.basename(location)
    end

    #
    def platform
      @platform ||= RUBY_PLATFORM
    end

    #
    def binary(platform = nil)
      ext = case platform
        when /darwin/
          'bundle'
        when /mingw|mswin|linux/
          'so'
        when /java/
          'jar'
        else
          RbConfig::CONFIG['DLEXT']
      end
      "#{@name}.#{ext}"
    end

    # TODO: how do these come in?
    def source_files
      @source_files ||= FileList["#{@ext_dir}/#{@source_pattern}"]
    end

    # FIXME
    def windows?
      Rake.application.windows?
    end

    # TODO: Adjustable?
    def ruby_ver
      @ruby_ver ||= RUBY_VERSION
    end


    private

    #
    def warn_once(message)
      @@already_warned ||= false
      return if @@already_warned
      @@already_warned = true
      warn message
    end

    #
    def mkdir_p(path)
      FileUtils.mkdir_p(path) unless File.exist?(path)
    end

    #
    def cp(path)
      FileUtils.cp(path)
    end

  end

end
end


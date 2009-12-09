#!/usr/bin/env ruby

require 'lavacake/compiler'

module LavaCake
module C

  # C Compiler
  class Compiler < Abstract::Compiler

    #
    SOURCE_PATTERN = "*.c"

    # Does the +directory+ contain source code compilable by this compiler?
    def self.compile?(directory)
      ! Dir[File.join(directory, SOURCE_PATTERN)].empty?
    end

    attr_accessor :platform

    attr_accessor :config_script

    attr_accessor :source_pattern

    attr_accessor :cross_config_options

    #
    def initialize(location, options, &block)
      @config_script  = 'extconf.rb'
      @source_pattern = SOURCE_PATTERN
      @cross_config_options = []

      super(location, options, &block)

      @cross_compile = (@platform != RUBY_PLATFORM)
    end

    #
    def settings

    end

    # FIXME: cleanup and clobbering
    #CLEAN.include(tmp_path)
    #CLOBBER.include("#{lib_path}/#{binary(platf)}")
    #CLOBBER.include("#{@tmp_dir}")

    #
    def cross_compile?
      @cross_compile
    end

    # HUH?
    #def cross_compiling(&block)
    #  @cross_compiling = block if block_given?
    #end

    #
    def compile
      if cross_compile?
        cross_compile
      else
        native_compile
      end
    end

    private

    #
    def native_compile
      mkdir_p(lib_path)
      make_binary
      copy_binary
    end

    # binary in temporary folder depends on makefile and source files
    # tmp/extension_name/extension_name.{so,bundle}
    #
    #   file "#{tmp_path}/#{binary(platf)}" => ["#{tmp_path}/Makefile"] + source_files do
    #     chdir tmp_path do
    #       sh make
    #     end
    #   end
    #
    def make_binary
      mkdir_p(tmp_path)
      makefile
      # TODO: source_files
      chdir tmp_path do
        sh(make)
      end
    end

    # Copy binary from temporary location to final lib
    # tmp/extension_name/extension_name.{so,bundle} => lib/
    #
    #   task "copy:#{@name}:#{platf}:#{ruby_ver}" => [lib_path, "#{tmp_path}/#{binary(platf)}"] do
    #     cp "#{tmp_path}/#{binary(platf)}", "#{lib_path}/#{binary(platf)}"
    #   end
    #
    def copy_binary
      cp("#{tmp_path}/#{binary(platform)}", "#{lib_path}/#{binary(platform)}")
    end

    # Makefile depends of tmp_dir and config_script
    #   tmp/extension_name/Makefile
    #
    def makefile
      options = @config_options.dup

      # include current directory
      cmd = ['-I.']

      # if fake.rb is present, add to the command line
      #if t.prerequisites.include?("#{tmp_path}/fake.rb") then
      #  cmd << '-rfake'
      #end
      if fake?  # FIXME
        cmd << '-rfake'
      end

      # build a relative path to extconf script
      abs_tmp_path = Pathname.new(Dir.pwd) + tmp_path
      abs_extconf  = Pathname.new(Dir.pwd) + extconf

      # now add the extconf script
      cmd << abs_extconf.relative_path_from(abs_tmp_path)

      # rbconfig.rb will be present if we are cross compiling
      #if t.prerequisites.include?("#{tmp_path}/rbconfig.rb") then
      #  options.push(*@cross_config_options)
      #end
      if cross_compile?
        options.push(*@cross_config_options)
      end

      # add options to command
      cmd.push(*options)

      chdir tmp_path do
        # FIXME: Rake is broken for multiple arguments system() calls.
        # Add current directory to the search path of Ruby
        # Also, include additional parameters supplied.
        ruby cmd.join(' ')
      end
    end

    #
    def config_path
      @config_path ||= File.expand_path("~/.rake-compiler/config.yml")
    end

    #
    def config_file
      config_file = YAML.load_file(config_path)
    end

    # tmp_path
    def tmp_path
      "#{tmp_dir}/#{platform}/#{name}/#{ruby_ver}"
    end

    # lib_path
    def lib_path
      lib_dir
    end

    #
    def rbconfig_file
      rbconfig_file = config_file["rbconfig-#{ruby_ver}"]
      rbconfig_file
    end

    # mkmf
    def mkmf_file
      @mkmf_file ||= File.expand_path(File.join(File.dirname(rbconfig_file), '..', 'mkmf.rb'))
    end

    #
    def cross_compile

      if RUBY_PLATFORM == 'java' || (defined?(RUBY_ENGINE) && RUBY_ENGINE == 'ironruby')
        warn_once <<-EOF
WARNING: You're attempting to (cross-)compile C extensions from a platform
(#{RUBY_ENGINE}) that does not support native extensions or mkmf.rb.
Rerun under MRI Ruby 1.8.x/1.9.x to cross/native compile.
        EOF
        return
      end

      if !File.exist?(config_path)
        warn "rake-compiler must be configured first to enable cross-compilation"
        return
      end

      if !rbconfig_file
        warn "no configuration section for specified version of Ruby (rbconfig-#{ruby_ver})"
        return
      end

      cross_prepare

      make_binary
      copy_binary
    end

    # Chain fake.rb, rbconfig.rb and mkmf.rb to Makefile generation
    #
    #   file "#{tmp_path}/Makefile" => ["#{tmp_path}/fake.rb",
    #                                   "#{tmp_path}/rbconfig.rb",
    #                                   "#{tmp_path}/mkmf.rb"]
    #
    def cross_prepare
      copy_fake
      copy_rbconfig
      copy_mkmf
    end

    # genearte fake.rb for different ruby versions
    #
    #   file "#{tmp_path}/fake.rb" do |t|
    #     File.open(t.name, 'w') do |f|
    #       f.write fake_rb(ruby_ver)
    #     end
    #   end
    #
    def copy_fake
      mkdir_p(tmp_path)
      File.open("#{tmp_path}/fake.rb", 'w') do |f|
        f.write(fake_rb(ruby_ver))
      end
    end

    # Copy the file from the cross-ruby location
    #
    #   file "#{tmp_path}/rbconfig.rb" => [rbconfig_file] do |t|
    #     cp t.prerequisites.first, t.name
    #   end
    #
    def copy_rbconfig
      cp(rbconfig_file, "#{tmp_path}/rbconfig.rb")
    end

    # copy mkmf from cross-ruby location
    def copy_mkmf
      cp(mkmf_file, "#{tmp_path}/mkmf.rb")
    end

    #
    def extconf
      "#{@ext_dir}/#{@config_script}"
    end

    #
    def make
      unless @make
        @make =
          if RUBY_PLATFORM =~ /mswin/ then
            'nmake'
          else
            ENV['MAKE'] || %w[gmake make].find { |c| system(c, '-v') }
          end
      end
      @make
    end

    #
    def source_files
      @source_files ||= FileList["#{@ext_dir}/#{@source_pattern}"]
    end

    #
    def fake_rb(version)
      <<-FAKE_RB
        class Object
          remove_const :RUBY_PLATFORM
          remove_const :RUBY_VERSION
          RUBY_PLATFORM = "i386-mingw32"
          RUBY_VERSION = "#{version}"
        end
      FAKE_RB
    end

  end

end
end


# Cross-compile ruby
#
# This source code is released under the MIT License.
# See LICENSE file for details
#
# This code is inspired and based on notes from the following sites:
#
# http://tenderlovemaking.com/2008/11/21/cross-compiling-ruby-gems-for-win32/
# http://github.com/jbarnette/johnson/tree/master/cross-compile.txt
# http://eigenclass.org/hiki/cross+compiling+rcovrt
#
# Information on where to store cross-compiled files:
#
# http://fedoraproject.org/wiki/Packaging_Cross_Compiling_Toolchains
# http://wiki.njh.eu/Cross_Compiling_for_Win32
#
# This recipe only cleanup the dependency chain and automate it.
# Also opens the door to usage different ruby versions 
# for cross-compilation.

require 'yaml'
require 'fileutils'
#require 'lavacake/session'
require 'lavacake/platforms/mingw'

module Cake

  # This class is used to compile different versions of Ruby
  # suitable for use as cross-compilers.
  #
  class RubyCompiler

    # Ruby source URL.
    attr_accessor :ruby_source

    # Make command.
    attr_accessor :make_command

    # Ruby version.
    attr_accessor :version

    # Force protected operations.
    attr_accessor :force

    # Extra config options.
    attr_accessor :config_options

    #
    def initialize #:yield:
      yield(self)
    end

    # This is the main command. It will build the ruby version requested
    # suitable for cross-platform development.
    #
    def compile_ruby
      if $DEBUG
        puts "user_home: #{user_home}"
        puts "user_local: #{user_local}"
        puts "make_command: #{make_command}"
        puts "version: #{version}"
        puts "ruby_cc_version: #{ruby_cc_version}"
        puts "ruby_source: #{ruby_source}"
        puts "srcdir: #{srcdir}"
        puts "blddir: #{blddir}"
        puts "libdir: #{libdir}"
      end

      mingw32
      environment
      download_source
      extract_source
      makefile_in_bak  # create Makefile.in.bak
      makefile_in      # create Makefile.in
      configure        # create Makefile
      make             # creates ruby.exe
      make_install
      update_config
    end

    # Clean intermediate files and folders.
    # TODO: What should be removed here?
    def clean
      #rm_r(srcdir)
      rm_r(blddir)
      #rm_r(libdir)
    end

    # Remove the final products and sources
    def clobber
      rm_r(srcdir)
      rm_r(blddir)
      rm_r(libdir)
      rm_r(config_file)
    end

    #
    def force?
      @force
    end

    #
    def user_home
      @user_home ||= (
        if xdg = ENV['XDG_CONFIG_HOME']
          File.expand_path(File.join(xdg, 'lavacake'))
        else
          File.expand_path('~/.config/lavacake')
        end
      )
    end

    #
    def user_cache
      @user_cache ||= (
        if xdg = ENV['XDG_CACHE_HOME']
          File.expand_path(File.join(xdg, 'lavacake'))
        else
          File.expand_path('~/.cache/lavacake')
        end
      )
    end

    #
    def user_local
      @user_local ||= (
        if xdg = ENV['XDG_LOCAL_HOME']
          File.expand_path(File.join(xdg)) #, 'lavacake'))
        else
          File.expand_path("~/.local/#{target}/#{ruby_cc_version}")
        end
      )
    end

    # TODO: Better way to get the default? How to keep quiet?
    def make_command
      @make_command ||= %w[gmake make].find{ |c| system("#{c} -v") }
    end

    #
    def version
      @version ||= '1.8.6-p287'
    end

    #
    def ruby_cc_version
      @ruby_cc_version ||= "ruby-#{version}"
    end

    #
    def ruby_source
      @ruby_source ||= "http://ftp.ruby-lang.org/pub/ruby/#{major}/#{ruby_cc_version}.tar.gz"
    end

    # grab the major "1.8" or "1.9" part of the version number
    def major
      @major ||= ruby_cc_version.match( /.*-(\d.\d).\d/ )[1]
    end

    #
    def config_file
      @config_file ||= "#{user_home}/config.yml"
    end

    #
    def config_options
      @config_options ||= []
    end

    # TODO: Sure this isn't supposed to be "i586-mingw32msvc" ?
    def target
      @target ||= "i386-mingw32"
    end

    # Use MinGW helper to find the proper host.
    def mingw_host
      @mingw_host ||= MinGW.mingw_host
    end

    #
    def srcdir
      @srcdir ||= "#{user_local}/src/#{ruby_cc_version}"
    end

    #
    def libdir
      @libdir ||= "#{user_local}/lib/ruby/#{version}"
    end

    #
    def blddir
      @blddir ||= "#{user_cache}/#{ruby_cc_version}"
    end

    # download the source file using wget or curl
    # ruby source file should be stored there
    #
    #   file "#{user_home}/sources/#{ruby_cc_version}.tar.gz" => ["#{user_home}/sources"] do |t|
    #
    def download_source
      file = srcdir + ".tar.gz"
      if File.exist?(file)
        if force?  # TODO: this should prbably be handled by clobber
          rm(file)
        else
          return
        end
      end
      dir = File.dirname(srcdir)
      mkdir_p(dir) unless File.exist?(dir)
      chdir(dir) do
        url = ruby_source
        #puts "Downloading #{ruby_source}"
        sh("wget #{url} || curl -O #{url}")
      end
    end

    # Extract the sources
    #
    #   file "#{user_home}/sources/#{ruby_cc_version}" => ["#{user_home}/sources/#{source_file}"] do |t|
    #
    def extract_source
      source_file = ruby_source ? ruby_source.split('/').last : "#{ruby_cc_version}.tar.gz"

      # TODO: can there really be more than one of these?
      sources = [File.join(File.dirname(srcdir), source_file)]

      puts "extracting #{srcdir}"

      chdir File.dirname(srcdir) do
        sources.each { |f| sh("tar xfz #{File.basename(f)}") }
      end
    end

    # backup Makefile.in
    #
    def makefile_in_bak
      from = File.join(srcdir, "Makefile.in")
      dest = File.join(srcdir, "Makefile.in.bak")
      install(from, dest) if File.exist?(from)
    end

    # correct the makefiles
    #
    #   file "#{user_home}/sources/#{ruby_cc_version}/Makefile.in" => ["#{user_home}/sources/#{ruby_cc_version}/Makefile.in.bak"]
    #
    def makefile_in
      file = File.join(srcdir, "Makefile.in")
      content = File.open(file, 'rb') { |f| f.read }
      out = ""
      content.each_line do |line|
        if line =~ /^\s*ALT_SEPARATOR =/
          out << "\t\t    ALT_SEPARATOR = \"\\\\\\\\\"; \\\n"
        else
          out << line
        end
      end
      puts "patching Makefile.in"
      File.open(file, 'wb') { |f| f.write(out) }
    end

    #
    def mingw32
      begin
        mingw_host
      rescue
        warn "You need to install mingw32 cross compile functionality to be able to continue."
        warn "Please refer to your distribution/package manager documentation about installation."
        exit
      end
    end

    #
    def environment
      ENV['ac_cv_func_getpgrp_void']   = 'no'
      ENV['ac_cv_func_setpgrp_void']   = 'yes'
      ENV['rb_cv_negative_time_t']     = 'no'
      ENV['ac_cv_func_memcmp_working'] = 'yes'
      ENV['rb_cv_binary_elf' ]         = 'no'
    end

    # generate the makefile in a clean build location
    #
    #   file "#{user_home}/builds/#{ruby_cc_version}/Makefile" => ["#{user_home}/builds/#{ruby_cc_version}",
    #                                  "#{user_home}/sources/#{ruby_cc_version}/Makefile.in"] do |t|
    #
    def configure
      file = File.join(blddir,"Makefile")

      # no need to recreate Makefile if it is uptodate (right?)
      return if uptodate?(file, Dir[File.join(srcdir,'*')]) unless force?

      mkdir_p(blddir) unless File.exist?(blddir)

      options = [
        "--target=#{target}",
        "--host=#{mingw_host}",
        '--build=i686-linux',
        '--enable-shared',
        '--disable-install-doc',
        '--without-tk',
        '--without-tcl'
      ] 

      options += config_options

      chdir(blddir) do
        #prefix = File.expand_path("../../ruby/#{version}")
        options << "--prefix=#{user_local}"
        #options << "--prefix=#{prefix}"
        # TODO: do we need to set --libdir, etc.?
        sh File.join(srcdir, "configure"), *options
      end
    end

    # make
    #
    #   file #{user_home}/builds/#{ruby_cc_version}/ruby.exe" => ["#{user_home}/builds/#{ruby_cc_version}/Makefile"]
    #
    def make
      file = File.join(blddir, "ruby.exe")
      chdir(blddir) do
        sh(make_command)
      end
    end

    # make install
    #
    #   file "#{user_home}/ruby/#{ruby_cc_version}/bin/ruby.exe" => ["#{user_home}/builds/#{ruby_cc_version}/ruby.exe"]
    #
    def make_install
      file = File.join(libdir, 'bin/ruby.exe')
      puts "file: #{file}"
      chdir(blddir) do
        sh "#{make_command} install"
      end
    end

    # Update rake-compiler list of installed Ruby versions.
    #
    def update_config
      if File.exist?(config_file) then
        puts "updating #{config_file}"
        config = YAML.load_file(config_file)
      else
        puts "generating #{config_file}"
        config = {}
      end

      files = Dir.glob(File.join(libdir, '**', "rbconfig.rb")).sort

      files.each do |rbconfig|
        version = rbconfig.match(/.*-(\d.\d.\d)/)[1]
        config["rbconfig-#{version}"] = rbconfig
        puts "Found Ruby version #{version} (#{rbconfig})"
      end

      mkdir_p(File.dirname(config_file))

      File.open(config_file, 'w') do |f|
        f.puts(config.to_yaml)
      end
    end

  private

    #
    def chdir(dir, &block)
      Dir.chdir(dir, &block)
    end

    #
    def sh(*argv)
      cmd = argv.join(" ")
      $stderr.puts cmd if $DUBUG
      system(cmd)
    end

    #
    def mkdir_p(dir)
      FileUtils.mkdir_p(dir)
    end

    #
    def install(from, dest, opts={})
      FileUtils.install(from, dest, opts)
    end

    #
    def uptodate?(file, compare)
      FileUtils.uptodate?(file, compare)
    end

    #task :default do
    #  # Force the display of the available tasks when no option is given
    #  Rake.application.options.show_task_pattern = //
    #  Rake.application.display_tasks_and_comments
    #end

    # define a location where sources will be stored
    #prepare_directories
    #  mkdir_p "#{user_home}/sources/#{ruby_cc_version}"
    #  mkdir_p "#{user_home}/builds/#{ruby_cc_version}"
    #end

  end

end


require 'rake'
require 'nokogiri'
require 'albacore/paths'
require 'albacore/cmd_config'
require 'albacore/cross_platform_cmd'
require 'albacore/nugets_authentication'

module Albacore
  module NugetsRestore
    class Cmd
      include Logging
      include CrossPlatformCmd
      def initialize work_dir, executable, *args
        opts = Map.options(args)
        raise ArgumentError, 'pkgcfg is nil' if opts.getopt(:pkgcfg).nil? 
        raise ArgumentError, 'out is nil' if opts.getopts(:out).nil?
        @work_dir = work_dir
        @executable = executable
        @opts = opts

        pars = opts.getopt(:parameters, :default => [])
        if opts.has_key?(:password) && opts.has_key?(:username) && opts.has_key?(:source)
          @authenticate = true
          @username = opts.getopt(:username)
          @password = opts.getopt(:password)
          @source = opts.getopt(:source)
        else
          @authenticate = false
        end
        @parameters = [%W{install #{opts.getopt(:pkgcfg)} -OutputDirectory #{opts.getopt(:out)}}, pars.to_a].flatten
      end

      def execute
        if @authenticate
          # omg haxxx ;) - feature request to the NuGet team: consume ENV variables
          # so I can avoid hacking like this.
          system make_command_e(
                  @executable,
                  %W[sources remove -name #{@source.name} -source #{@source.uri}]),
            :verbose => true
          system make_command_e(
                  @executable, 
                  %W[sources add -name #{@source.name} 
                     -source #{@source.uri}
                     -user #{@username}
                     -password #{@password}
                  ]), 
            :ensure_success => true
        else
          debug 'nuget in non-authenticated mode'
        end
        sh @work_dir, make_command
      end
    end
    
    # Public: Configure 'nuget.exe install' -- nuget restore.
    #
    # work_dir - optional
    # exe - required NuGet.exe path
    # out - required location of 'packages' folder
    class Config
      include CmdConfig # => :exe, :work_dir, @parameters, #add_parameter
      include NugetsAuthentication # => :username, :password
      include Logging

      OFFICIAL_REPO = 'https://nuget.org/api/v2/'

      def initialize
        @include_official = false
      end

      # the output directory passed to nuget when restoring the nugets
      attr_writer :out
    
      # nuget source, when other than MSFT source
      attr_accessor :source

      def packages
        list_spec = File.join '**', 'packages.config'
        # it seems FileList doesn't care about the curr dir
        in_work_dir do FileList[Dir.glob(list_spec)] end
      end

      # whether to include the official
      # defaults to true
      attr_accessor :include_official

      def opts_for_pkgcfg pkg
        pars = parameters.to_a
        debug "include_official nuget repo: #{include_official}"
        pars << %W[-source #{OFFICIAL_REPO}] if include_official
        
        map = Map.new({ :pkgcfg     => Albacore::Paths.normalize_slashes(pkg),
                        :out        => @out,
                        :parameters => pars })

        if username && password && source
          map.set :username, username
          map.set :password, password
          map.set :source, source
        end 
        map
      end
    end

    class Task
      def initialize command_line
        @command_line = command_line
      end
      def execute
        @command_line.execute
      end
    end
  end
end
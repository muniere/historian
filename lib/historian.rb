require 'date'
require 'open3'
require 'parallel'

#
# Extended hash
#
class Hash

  #
  # Get value from self
  #
  def get(key)
    return self[key]
  end

  #
  # Set value and return self (for method chain)
  #
  def set(key, value)
    self[key] = value
    return self
  end
end

#
# History collector
#
class Historian
  attr_accessor :verbose

  class Collector

    #
    # Initialize collector with remote hosts
    #
    # @param {Array.<String>} hosts
    # @constructor
    #
    def initialize(hosts: [], verbose: true)
      @hosts = hosts
      @verbose = verbose
    end

    #
    # Collect histories from remote hosts
    #
    # @param {Time=} start
    # @param {Time=} finish
    # @return {Array.<Historian::Entry>}
    #
    def collect(start: Date.today.to_time, finish: Date.today.next_day.to_time)
      histories = []

      unless @hosts.empty?
        banner(['target hosts:'].concat(@hosts.map{ |host| " - #{host}" }).join("\n"))
      end

      debug("collect histories between (%{start_s}, %{finish_s})" % {
        start_s:  start.strftime('%Y-%m-%d %H:%M:%S'),
        finish_s: finish.strftime('%Y-%m-%d %H:%M:%S')
      })

      if @hosts.empty?
        bash_history = File.open(File.expand_path('~/.bash_history')).read
        histories.concat(parse_bash_history(bash_history, start: start, finish: finish))

        zsh_history = File.open(File.expand_path('~/.zsh_history')).read
        histories.concat(parse_zsh_history(zsh_history, start: start, finish: finish))

        return histories
      end

      q = Queue.new
      t = Thread.new do
        while message = q.pop
          if message.is_a?(Exception)
            error(message.message.red)
          else
            debug(message)
          end
        end
      end

      Parallel.each(@hosts, in_threads: 5) do |host|
        q.push("start collect from #{host}")

        bash_history, message, status = Open3.capture3("ssh #{host} 'cat $HOME/.bash_history'")

        if status.success?
          histories.concat(parse_bash_history(bash_history, host: host, start: start, finish: finish))
        else
          q.push(Exception.new(message.strip))
        end

        q.push("finish collect from #{host}")
      end

      Thread::kill(t)

      return histories
    end

    private

    #
    # Parse bash history string
    #
    # @param {String} history
    # @param {String} host
    # @param {Time} start
    # @param {Time} finish
    # @return {Array.<Historian::Entry>}
    #
    def parse_bash_history(history, host: 'localhost', start:, finish:)

      histories = []

      lines = history.lines.map{ |line| line.scrub('?').strip }

      until lines.empty? do
        next unless (time_s = lines.shift) =~ /^#\d+$/

        time = time_s.tr('#', '').to_i

        next unless time.between?(start.to_i, finish.to_i)

        cmd = lines.shift.strip

        histories.push(Entry.new(host: host, cmd: cmd, time: time))
      end

      return histories
    end

    #
    # Parse bash history string
    #
    # @param {String} history
    # @param {String} host
    # @param {Time} start
    # @param {Time} finish
    # @return {Array.<Historian::Entry>}
    #
    def parse_zsh_history(history, host: 'localhost', start:, finish:)

      histories = []

      lines = history.lines.map{ |line| line.scrub('?').strip }

      until lines.empty? do
        matched = /\D*(?<time>\d+)[^;]+;(?<cmd>.*)/.match(lines.shift)

        next if matched.nil?

        time = matched[:time].to_i

        next unless time.between?(start.to_i, finish.to_i)

        cmd = matched[:cmd].strip

        histories.push(Entry.new(host: host, cmd: cmd, time: time))
      end

      return histories
    end

    #
    # Show banner with message
    #
    # @param {String} message
    #
    def banner(message) 
      return unless @verbose

      Util.show_banner(message)
    end

    #
    # Show debug message in line
    #
    # @param {String} message
    #
    def debug(message) 
      return unless @verbose

      Util.show_line(message, level: 'debug', color: :green)
    end

    #
    # Show error message in line
    #
    # @param {String} message
    #
    def error(message)
      Util.show_line(message, level: 'erorr', color: :red)
    end

  end

  class Entry
    attr_reader :host, :time, :cmd

    #
    # Initialize a history entry
    #
    # @param {String} cmd
    # @param {Integer} time
    # @param {String} host
    # @constructor
    #
    def initialize(host: '', time: 0, cmd: '')
      @cmd = (cmd.is_a?(String)) ? cmd : ''
      @time = (time.is_a?(Time)) ? time :
        (time.is_a?(Integer) and time > 0) ? Time.at(time) : Time.now
      @host = (host.is_a?(String)) ? host : ''
    end

    #
    # Compare with another entry
    #
    # @param {Historian::Entry} another
    # @return {Integer}
    #
    def <=>(another)
      return  1 if @time > another.time
      return -1 if @time < another.time
      return  1 if @host > another.host
      return -1 if @host < another.host
      return  1 if @cmd  > another.cmd
      return -1 if @cmd  < another.cmd
      return 0
    end

    #
    # Convert to string
    #
    def to_s
      return "[#{host}] (#{time}) #{cmd}"
    end
  end

  class Formatter
    attr_accessor :template

    COLORS = [
      :magenta, :cyan, :yellow, :green, :blue, 
      :light_magenta, :light_cyan, :light_yellow, :light_green, :light_blue
    ]

    #
    # Initialize a formatter.
    #
    # @param {Array.<String>} hosts
    # @param {String} template
    # @constructor
    #
    def initialize(hosts: [], template: nil)
      @host_colors = hosts.each_with_index.reduce({}) do |map, (host, index)|
        map.set(host, COLORS[index % COLORS.length])
      end
      @host_width = hosts.map{ |host| host.length }.max || 0

      @template = template || '[%{chost}] (%{ctime}) %{cmd}'
    end

    #
    # Format a history
    #
    # @param {Historian::Entry} history
    # @param {Boolean=} colorize
    # @return {String} formatted string
    #
    def format(history, colorize: true) 
      hcolor = @host_colors[history.host] || :green

      return @template % {
        host:  history.host,
        chost: history.host.ljust(@host_width).colorize(hcolor),
        time:  history.time.strftime('%Y-%m-%d %H:%M:%S'),
        ctime: history.time.strftime('%Y-%m-%d %H:%M:%S').colorize(hcolor),
        cmd:   history.cmd,
        ccmd:  history.cmd.colorize(hcolor)
      }
    end
  end

  module Util

    #
    # Extract ssh host from command string
    #
    # @param {Historian::Entry} history
    # @return {String} host
    #
    def self.ssh_host(history)
      return nil if history.cmd !~ /^ssh/

      args = history.cmd.split[1..-1]

      while (arg = args.shift) != nil
        # argv
        return arg if arg !~ /^-/

        # long option (--hoge-foo=bar)
        next if arg =~ /^--.+=.*/

        # verbose option
        next if arg =~ /^-v/

        # long option (--foo bar)
        # short option (-f bar)
        args.shift
        next
      end
    end

    #
    # Show progress message in banner
    #
    # @param {String} message
    #
    def self.show_banner(message, color: :cyan) 
      lines = message.lines.map{ |line| "=====> #{line}".strip }
      width = lines.map{ |line| line.length }.max

      deco = '=' * width
      body = lines.join("\n")

      STDERR.puts(deco.colorize(color))
      STDERR.puts(body.colorize(color))
      STDERR.puts(deco.colorize(color))
    end

    #
    # Show progress message in line
    #
    # @param {String} message
    # @param {String} level
    #
    def self.show_line(message, level:, color: :green) 
      STDERR.puts("=====> [#{level.upcase.ljust(6)}] {#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}} #{message}".colorize(color))
    end
  end
end

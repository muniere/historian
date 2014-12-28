require 'open3'

#
# Constants
#
VERBOSE = true
NOOP = false

SRC_DIR = File.join(Dir.pwd, 'bin')
DST_DIR = File.join(ENV['HOME'], '.bin')
LOCK_FILE = 'PREFIX.lock'

#
# Extended String
#
class String
  def red;     "\033[31m#{self}\033[0m"; end
  def green;   "\033[32m#{self}\033[0m"; end
  def yellow;  "\033[33m#{self}\033[0m"; end
  def blue;    "\033[34m#{self}\033[0m"; end
  def magenta; "\033[35m#{self}\033[0m"; end
  def cyan;    "\033[36m#{self}\033[0m"; end
  def gray;    "\033[37m#{self}\033[0m"; end
end

#
# Helper functions
#
class Helper

  #
  # output info
  #
  def self.info(message)
    STDERR.puts "[INFO] #{message}".cyan if VERBOSE
  end

  #
  # output warn
  #
  def self.warn(message)
    STDERR.puts "[WARN] #{message}".yellow if VERBOSE
  end

  #
  # list files in directory
  #
  def self.lsdir(dir)
    return Dir.entries(dir) - ['.', '..']
  end

  #
  # make directory recursively
  #
  def self.mkdir_p(dir)
    return self.exec("mkdir -p #{dir}")
  end

  #
  # remove file
  #
  def self.rm(file)
    return self.exec("rm #{file}")
  end

  #
  # create symlink 
  #
  def self.symlink(src, dst)

    if !File.exists?(src)
      self.warn("File NOT FOUND: #{src}")
      return false
    end

    if File.symlink?(dst)
      self.info("File already exists: #{dst}")
      return true
    end

    return self.exec("ln -sf #{src} #{dst}")
  end

  #
  # unlink file
  #
  def self.unlink(target)

    if !File.exists?(target) and !File.symlink?(target)
      self.info("File already removed: #{target}")
      return true
    end

    if !File.symlink?(target)
      self.warn("File is NOT LINK: #{target}")
      return false
    end

    return self.rm(target)
  end

  #
  # install bundles
  #
  def self.bundle
    return self.exec('bundle install')
  end

  #
  # exec shell command
  #
  def self.exec(command, options={})
    verbose = !options[:verbose].nil? ? options[:verbose] : VERBOSE
    noop = !options[:noop].nil? ? options[:noop] : NOOP

    if verbose
      STDERR.puts "[EXEC] #{command}".green 
    end

    return true if noop

    Process.waitpid(Process.spawn(command))

    return $?.success?
  end
end

#
# Tasks
#
desc 'install'
task :install do
  src_d = SRC_DIR
  dst_d = DST_DIR

  if !ENV['PREFIX'].nil?
    dst_d = ENV['PREFIX']
    File.write(LOCK_FILE, ENV['PREFIX'])
  end

  Helper.bundle

  Helper.lsdir(src_d).each do |bin|
    Helper.symlink(File.join(src_d, bin), File.join(dst_d, bin))
  end
end

desc 'uninstall'
task :uninstall do
  src_d = SRC_DIR
  dst_d = DST_DIR

  if File.exists?(LOCK_FILE)
    dst_d = File.read(LOCK_FILE)
  end

  Helper.lsdir(src_d).each do |bin|
    Helper.unlink(File.join(dst_d, bin))
  end
end

desc 'show status'
task :status do
  src_d = SRC_DIR
  dst_d = DST_DIR

  if File.exists?(LOCK_FILE)
    dst_d = File.read(LOCK_FILE)
  end

  if !(bins = (Helper.lsdir(src_d) & Helper.lsdir(dst_d)).map{ |bin| File.join(dst_d, bin) }).empty?
    Helper.exec("ls -lFG #{bins.join(' ')}", verbose: false, noop: false)
  end
end

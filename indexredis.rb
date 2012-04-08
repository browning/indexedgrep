#!/usr/bin/ruby
require 'rubygems'
require 'optparse'
require 'find'
require 'redis'


ALLOWED_EXTENSIONS = [".c", ".h"]

# 
# Indexes the directory and subdirectories
#
def do_index(start_dir)
  redis = Redis.new
  redis = Redis.new(:host => "127.0.0.1", :port => 6379)
  counter = 0
  Find.find(start_dir) do |file|
    next unless ALLOWED_EXTENSIONS.include? File.extname(file)
    dupe_check = Hash.new
    redis.multi do
      redis.set(counter, file) 
      
      f = File.open(file, 'rb')
      code = f.read
      f.close
      puts "Indexing #{file}"
      # Index the N-Grams where N = 2
      for i in 0..code.length-3 do
        gram = code[i,3]
#        gram.downcase!
        r = /\s\s\s/
        x = r =~ gram
        if dupe_check[gram] or not x.nil? then
          # do nothing
        else
          redis.sadd gram, counter
          dupe_check[gram] = true
        end
      end
    end
    counter = counter + 1
  end
end


options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: indexgrep.rb -i <directory>"

  opts.on("-i", "--index", "Generate the index") do |i|
    options[:index] = i
  end
end.parse!

if options[:index] then
  start_dir = ARGV[0]
  do_index(start_dir)
else
  # do the grep
  regex = ARGV[0]
  searchterm = `hackedgrep/grep -E \"#{regex}\"`
  puts "Regex: #{searchterm}"
   redis = Redis.new
  redis = Redis.new(:host => "127.0.0.1", :port => 6379)
  puts "Connected to redis"
  filename_list = ""
  gramlist = []
  for i in 0..searchterm.length-3 do
    gramlist << searchterm[i,3]
  end
  gramlist.each { |g|
	print "|#{g}|"
	}
  puts " "
 
  res = redis.sinter(*gramlist)
  flist = 0
  res.each {|r|
    filename = redis.get r
    filename_list = filename_list + " " + filename
    if flist >= 2000 then
      system("grep -E -H \"#{regex}\" #{filename_list}")
      flist = 0
      filename_list = ""
    end
    flist = flist + 1
  }
  system("grep -E -H \"#{regex}\" #{filename_list}")
  #system("echo starting...")
  
  #puts cmd
  #exec "grep", "\"hello world\" #{filename_list}"
end




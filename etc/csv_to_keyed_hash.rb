#!/usr/bin/env ruby
require 'optparse'
require 'pathname'
require 'csv'
require 'pp'

file, key, modname, constname = ""

TEMPL_RUBY = <<-RUBY
#!/usr/bin/env ruby
module %MODNAME%
  %CONSTNAME% = %OUTPUT%
end
RUBY

OptionParser.new do |opts|

  opts.banner = "Usage: #{$0} [options] > outputfile.rb"
  
  opts.on("-f", "--file FILE", "Source CSV file") do |v|
    file = v
  end

  opts.on("-k", "--key KEYNAME", "Name of field to key on") do |v|
    key = v
  end

  opts.on("-m", "--modname MODNAME", "Name of Module to create") do |v|
    modname = v
  end

  opts.on("-c", "--constname CONSTNAME", "Name of constant to write result to") do |v|
   constname = v
  end
  
end.parse!

raise ArgumentError, "Must supply input file" if file.strip == ""
raise ArgumentError, "Supplied file does not exist." unless Pathname.new(file).exist?
raise ArgumentError, "Must supply key name" if key.strip == ""
raise ArgumentError, "Must supply module name" if modname.strip == ""
raise ArgumentError, "Must supply constant name" if constname.strip == ""

key = key.to_sym

res = {}

dat = File.open(file).read
csv = CSV.new(dat, :headers => true, :header_converters => :symbol)
csv.to_a.map {|row| row.to_hash}.each do |row|
  res[ row[key] ] = row
end

output = TEMPL_RUBY.
  gsub("%MODNAME%", modname).
  gsub("%CONSTNAME%", constname).
  gsub("%KEYNAME%", key.to_s).
  gsub("%OUTPUT%", res.pretty_inspect)

print output

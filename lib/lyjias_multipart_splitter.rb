require "lyjias_multipart_splitter/version"
require "pathname"
require "securerandom"
# test with:
#     p LyjiasMultipartSplitter.split_multipart( IO.binread( "sample/sample.txt" ) )
# in bin/console

begin
  gem "zog", "= 0.4.2"
  require "zog"
rescue Gem::LoadError
  if __FILE__==$0
    $stderr.puts("Logging requires the 'zog' gem.")
  end
end

module LyjiasMultipartSplitter

    LINEFEED = "\r\n"
  
    # Splits a text stream in multipart/form-data format into a useful hash
    def self.split_multipart(inputtext)
        self.log("Got: '#{inputtext[0..50]}...'")



        part = {filename: nil, name: nil, contenttype: nil, content: nil}
        parts = {}

        mdata = inputtext
        mlines = mdata.split(LINEFEED)
        results = []

        self.log("Input contains #{mlines.length} lines.")

        #check that its multipart
        unless mdata[0...2] == "--"
          raise ArgumentError, "Included data does not contain the necessary header"
        end

        #read the first line and get the boundary string
        splitline = mlines[0]
        self.log("Boundary string is: '#{splitline}'")

        starts = mdata.enum_for(:scan, /#{splitline}/n).map { Regexp.last_match.begin(0) }

        self.log("Start points at: #{starts}")

        starts.each_index do |i|
          next if i == (starts.length - 1) #skip last one as it is the payload footer

          start = starts[i] + splitline.length + LINEFEED.length
          thenext = starts[i+1] - LINEFEED.length

          chunk = mdata[start..thenext] #read our chunk

          res = self.get_file(chunk) #get its data
          results << res
        end

        return results

    end

    def self.split_multipart_to_hash(inputtext, key_by = :filename)
      
      pres = self.split_multipart(inputtext)
      res = {}

      pres.each do |pre|
        res[ pre[key_by] ] = pre
      end

      return res

    end

    def self.split_multipart_to_files(inputtext, **opts)
      key_by = opts[:key_by] || :filename
      dest_path = Pathname.new(opts[:dest_path]) rescue Pathname.new("/tmp")
      purge_content = opts[:purge_content] || false
      uuid_filename = opts[:uuid_filename] || false

      pres = self.split_multipart_to_hash(inputtext, key_by)

      pres.each_key do |k|

        pre = pres[k]

        if uuid_filename
          filename = SecureRandom.uuid
        else
          filename = pre[:filename]
        end

        path = File.join(dest_path, filename)

        File.open( path, "wb") do |fil|
          fil.write(pre[:content])
          pres[k][:saved_as] = path
        end

        if purge_content
          pres[k][:content] = nil
        end

      end

      return pres

    end

    private

    # Breaks up snippets with files in them from split_multipart
    def self.get_file(snippet)
      self.log("Got: '#{snippet[0...20]}..#{snippet[-20...-1]}'")
      res = {}

      # get offsets for header lines and content start
      lineindices = snippet.enum_for(:scan, /#{LINEFEED}/n).map { Regexp.last_match.begin(0) }
      li = lineindices
      self.log("lineindices are: #{li}")
      headers = [
          snippet[ 0... li[0]  ],
          snippet[ (li[0]+LINEFEED.length)... li[1] ]
      ]
      contentstart = li[2] + LINEFEED.length
      p headers

      self.log("content starts at: #{contentstart}")

      # read content
      content = snippet[contentstart...-1]
      res[:content] = content

      # read headers
      if headers[0] =~ /\AContent-Disposition: form-data/i

        parts = headers[0].split(";").map{ |x| x.strip }

        parts.each_index do |i|

          next if i==0
          pt = parts[i]

          frag = pt.split("=")
          name = frag[0].to_sym
          val = frag[1].tr('"', '')

          res[name] = val

        end

      else
        raise ArgumentError, "Input snippet does not appear to be a fragment from a multipart/form-data payload"
      end

      if headers[1] =~ /\AContent-Type/i
        frag = headers[1].split(":")
        val = frag[1].strip
        res[:contenttype] = val
      else
        raise ArgumentError, "Input snippet is missing Content-Type"
      end

      return res

    end

    def self.log(msg)
      Zog.debug(msg) if defined? Zog
    end

end

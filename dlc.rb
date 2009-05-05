# = The DLC API in ruby!
# Visit http://jdownloader.org for more information on why this might be useful!
#
# My thanks go out to the JDownloader staff for making such an excellent application. I've spoken with them and this script is now available for download at http://projects.kedakai.co.uk/rubydlc/dlc.rb I hope you enjoy it.
# == How to Use
# You can use this library from the irb, or in any script you like. Examples below are for irb, I'm sure people using this as a 
# library will be able to figure out how to use it in that way.
# === Set Up
# You'll need to set the settings file before you do anything else. Open up irb in the directory where this file is located:
#   >> require 'dlc'
#   => true
#   >> s = DLC::Settings.new
#   No settings file exists. You should set them with the follwing in irb:
#    require 'dlc'
#    s = DLC::Settings.new
#    s.name = "Your Name"
#    s.url = "http://yourdomain.com"
#    s.email = "your.name@yourdomain.com"
#   You need to specify a name, url and email for the DLC generator. See the documentation
#   => 
#   >> s.name = "Your Name"
#   => "Your Name"
#   >> s.url = "http://your.domain.com"
#   => "http://your.domain.com"
#   >> s.email = "your.name@your.domain.com"
#   => "your.name@your.domain.com"
#
# Now your settings file has been created you can go about making DLCs!
#
# === Creating a Package and DLC
# The following irb example shows the variety of options you have while creating a package
#   >> p = DLC::Package.new
#   => Unnamed package (0 links, 0 passwords)
#   >> p.name = "My Package"
#   => "My Package"
#   >> p.comment = "An exciting package!"
#   => "An exciting package!"
#   >> p.category = "Nothing useful"
#   => "Nothing useful"
#   >> p.add_link("http://google.com/")
#   => true
#   >> p.add_link(["http://bbc.co.uk","http://slashdot.org"])
#   => true
#   >> p.add_password("I don't really need one of these")
#   => true
#   >> p p
#   "My Package" (3 links, 1 passwords)
#    # An exciting package!
#   => nil
#   >> p.dlc
#
# That final command will give you the string for your DLC. If you want to put it into a file you should do:
#   open("my_dlc.dlc","w") do |f|
#     f.write p.dlc
#   end
#
# This will ensure the file gets closed after you've written your DLC to it.
#
# == More Information
# I'm JP, you can find my things at http://kedakai.co.uk. Any questions can be sent to me via twitter: @jphastings.
#
# I did this entirely for fun, please take that into account if/when you ask for help or before you get in touch. If you have any code improvements
# please do let me know! I hope you enjoy this!

require 'yaml'
require 'time'
require 'net/http'
require 'digest/md5'

require 'rubygems'
require 'builder'
require 'ruby-aes'

# A hack to make the AES module accept string keys when they look like hex!
def Aes.check_iv(iv)
  return iv
end

# The DLC module, this is the container for the Settings and Package classes. It also contains some private helper functions
module DLC
  Api = {
    :version => 1.0,
    :pair_expires_after => 3600,
    :service_urls => ["http://service.jdownloader.org/dlcrypt/service.php"],
  }
  
  # Settings is a class that deals with information about the group using the DLC api.
  #
  # The class contains code to write its own settings file. Before using this ruby DLC api
  # you should require it in irb and set the details:
  #   require 'dlc'
  #   s = DLC::Settings.new
  #   s.name = "Your name"
  #   s.email = "you@yourdomain.com"
  #   s.url = "http://yourdomain.com/why_i_use_dlc.html"
  #   p s
  class Settings
    attr_accessor :email,:name,:url
    
    # I may allow this to be changed in later versions
    Settings = "settings.yml"
    
    def initialize
      if File.exists? Settings
        begin
          s = YAML.load(open(Settings))
          @email = s[:email]
          @name = s[:name]
          @url = s[:url]
          @keycache = (s[:keycache][:expires].nil? or s[:keycache][:expires] < Time.now.to_i) ? {} : s[:keycache]
        rescue
          raise SettingsNotValidError, "Your settings file is not valid. Please remove it."
        end
      else
        $stderr.puts "No settings file exists. Read the documentation to find out how to make one."
        @keycache = {}
      end
    end
    
    # Validate email address entry
    def email=(email)
      if email =~ /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}\b/i
        @email = email
        write_settings
      else
        $stderr.puts "That is an invalid email address"
      end
    end
    # Must have a Name to make DLCs
    def name=(name)
      if not name.nil? and name.length != 0
        @name = name
        write_settings
      else
        $stderr.puts "You must use a full name"
      end
    end
    # Must have a URL (starting in http:// or https://) to make DLCs
    def url=(url)
      if url =~ /^http(s?)\:\/\//i
        @url = url
        write_settings
      else
        $stderr.puts "Please include a leading http://"
      end
    end
    
    # Allows the cache of the key/encoded key pairs
    def set_keycache(key,encoded_key,expires = 3600)
      @keycache = {
        :expires     => Time.now.to_i + expires,
        :key         => key,
        :encoded_key => encoded_key
      }
      write_settings
    end
    
    # Retrieve the key from the cache, if there is one there.
    # This will raise a +NoKeyCachedError+ if there is no key.
    def get_keycache
      if @keycache[:expires].nil? or @keycache[:expires] < Time.now.to_i
        @keycache = {}
        raise NoKeyCachedError, "There is no key in the cache"
      else
        return @keycache[:key],@keycache[:encoded_key]
      end
    end
    
    # A helper for irb people, and hands-on developlers
    def inspect
      if @name.nil? or @email.nil? or @url.nil?
        $stderr.puts "You need to specify a name, url and email for the DLC generator. See the documentation"
        return nil
      end
      "DLC API owner: #{@name} <#{@email}> (#{@url})"
    end
    
    private
    def write_settings
      open(Settings,"w") do |f|
        p @keycache
        f.write YAML.dump({:name => @name, :email => @email, :url => @url,:keycache => @keycache})
      end
    end
  end
  
  # The DLC package handler class. Make a new one of these for each package you want to create.
  class Package
    attr_reader :links,:passwords
    attr_accessor :comment, :name, :category
    
    # Makes sure all the defaults are set (this would make a valid, if useless, package)
    def initialize
      @links = []
      @passwords = []
      @category = "various"
      @comment = ""
    end
      
    # Adds a link to the package
    # Will take an array of links too
    # I will, at some point, include the ability to specify filename and size.
    def add_link(url)
      if url.is_a?(Array)
        url.each do |u|
          self.add_link(u)
        end
        return true
      end
      if url.is_a?(String) and url =~ /^http(s)?\:\/\//
        @links.push({:url=>url,:filename=>nil,:size=>0})
        return true
      end
      $stderr.puts "Invalid URL: #{url}"
      return false
    end
    
    # Adds a password to the package
    # Also accepts an array of passwords
    def add_password(password)
      if password.is_a?(Array)
        password.each do |p|
          self.add_password(p)
        end
        return true
      end
      if password.is_a?(String)
        @passwords.push(password)
        return true
      end
      $stderr.puts "Invalid password: #{password}"
      return false
    end
    
    # Gives you the DLC of the package you've created. First run (every hour) will take longer than the others while
    # the jdownloader service is queried for information.
    def dlc
      settings = DLC::Settings.new
      if settings.inspect.nil?
        raise NoGeneratorDetailsError, "You must enter a name, url and email for the generator. See the documentation."
      end
      
      xml = Builder::XmlMarkup.new(:indent=>0)
      xml.dlc {
        xml.header {
          xml.generator {
            xml.app(DLC.encode("Ruby DLC API (kedakai)"))
            xml.version(DLC.encode(DLC::Api[:version]))
            xml.url(DLC.encode(settings.url))
          }
          xml.tribute {
            xml.name(DLC.encode(settings.name))
          }
          xml.dlcxmlversion(DLC.encode('20_02_2008'))
        }
        xml.content {
          package = {:name => DLC.encode(@name)}
          package[:passwords] = DLC.encode(@passwords.collect{|pw| "\"#{pw}\""}.join(",")) if @passwords.length != 0
          package[:comment] = DLC.encode(@comment) if @comment != ""
          package[:category] = DLC.encode(@category) if @category != ""
          xml.package(package) {
            @links.each do |link|
              xml.file {
                xml.url(DLC.encode(link[:url]))
                xml.filename(DLC.encode(link[:filename]))
                xml.size(DLC.encode(link[:size]))
              }
            end
          }
        }
      }
      
      # Lets get a key/encoded key pair
      begin
        key, encoded_key = settings.get_keycache
      rescue NoKeyCachedError
        # Generate a key
        expires = 3600
        key = Digest::MD5.hexdigest(Time.now.to_i.to_s+"salty salty"+rand(100000).to_s)[0..15]
        begin
          if Net::HTTP.post_form(URI.parse(DLC::Api[:service_urls][rand(DLC::Api[:service_urls].length)]),{
            :data    => key, # A random key
            :lid     => DLC.encode([settings.url,settings.email,expires].join("_")), # Details about the generator of the DLC
            :version => DLC::Api[:version],
            :client  => "rubydlc"
          }).body =~ /^<rc>(.+)<\/rc><rcp>(.+)<\/rcp>$/
            encoded_key = $1
            # What is the second part?!
            settings.set_keycache(key, encoded_key, expires)
          else
            raise ServerNotRespondingError
          end
        rescue
          raise ServerNotRespondingError, "The DLC service is not responding in the expected way. Try again later."
        end
      end

      b64 = DLC.encode(xml.target!)
      DLC.encode(Aes.encrypt_buffer(128,"CBC",key,key,b64.ljust((b64.length/16).ceil*16,"\000")))+encoded_key
    end
    
    # Gives some useful information when people use the library from irb
    def inspect
      ((@name.nil?) ? "Unnamed package" : "\"#{@name}\"" )+" (#{@links.length} links, #{@passwords.length} passwords)"+((@comment == "") ? "" : "\n# #{@comment}")
    end
  end
  
  # For when the settings file is invalid
  class SettingsNotValidError < StandardError; end
  # For when a DLC is requested without settings set
  class NoGeneratorDetailsError < StandardError; end
  # For when the keycache is accessed and no valid key is available
  class NoKeyCachedError < StandardError; end
  # For when the service is not responding in the expectde manner
  class ServerNotRespondingError < StandardError; end  
  
  private
  def self.encode(string)
    string = "n.A." if string.nil?
    return [string.to_s].pack("m").gsub("\n","")
  end
end
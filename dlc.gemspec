spec = Gem::Specification.new do |s| 
  s.name = "dlc"
  s.version = "1.0.2"
  s.author = "JP Hastings-Spital"
  s.email = "rubydlc@projects.kedakai.co.uk"
  s.homepage = "http://projects.kedakai.co.uk/rubydlc/"
  s.platform = Gem::Platform::RUBY
  s.description = "Allows the generation of DLC container files (of JDownloader fame) from ruby"
  s.summary = "Allows the generation of DLC container files (of JDownloader fame) from ruby"
  s.files = ["dlc.rb"]
  s.require_paths = ["."]
  s.add_dependency("builder")
  s.has_rdoc = true
end

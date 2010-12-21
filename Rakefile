require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "dlc"
    gem.description = "Allows the generation of DLC container files (of JDownloader fame) from ruby"
    gem.summary = "Allows the generation of DLC container files (of JDownloader fame) from ruby"
    gem.email = "jphastings@gmail.com"
    gem.homepage = "http://github.com/jphastings/ruby-DLC"
    gem.authors = ["JP Hastings-Spital"]
    gem.add_dependency "openssl"
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: sudo gem install jeweler"
end

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

begin
  require 'rcov/rcovtask'
  Rcov::RcovTask.new do |test|
    test.libs << 'test'
    test.pattern = 'test/**/test_*.rb'
    test.verbose = true
  end
rescue LoadError
  task :rcov do
    abort "RCov is not available. In order to run rcov, you must: sudo gem install spicycode-rcov"
  end
end

task :test => :check_dependencies

task :default => :test
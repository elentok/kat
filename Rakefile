require 'bundler/gem_tasks'
require 'rake/testtask'

task :default => :test

Rake::TestTask.new do |t|
  t.libs.push 'lib'
  t.test_files = FileList['test/kat/test_*.rb']
end

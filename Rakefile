# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"
require "standard/rake"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/unit/**/*_test.rb"]
end

Rake::TestTask.new(:test_integration) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/integration/**/*_test.rb"]
end

Rake::TestTask.new(:test_all) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

task :check_permissions do
  spec = Gem::Specification.load("activerecord-health.gemspec")
  files = spec.files.select { |path| File.file?(path) }

  unreadable = files.filter_map do |path|
    mode = File.stat(path).mode & 0o777
    next if (mode & 0o004) != 0

    "#{path} (#{format("%o", mode)})"
  end

  if unreadable.any?
    warn "Non-world-readable files detected:"
    unreadable.sort.each { |entry| warn "  - #{entry}" }
    abort "Fix permissions (chmod o+r) before release."
  end
end

task default: %i[test standard check_permissions]

if Rake::Task.task_defined?("release")
  Rake::Task["release"].enhance(%i[default])
end

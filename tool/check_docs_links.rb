#!/usr/bin/env ruby
# frozen_string_literal: true

require 'pathname'
require 'shellwords'

ROOT = Pathname.new(__dir__).parent.expand_path
SKIP_DIRS = %w[.dart_tool .git build dist].freeze
LINK_PATTERN = /\[[^\]]+\]\(([^)\s]+)(?:\s+"[^"]*")?\)/

def skipped?(path)
  path.each_filename.any? { |part| SKIP_DIRS.include?(part) }
end

def local_target?(href)
  return false if href.empty? || href.start_with?('#')
  return false if href.match?(/\A[a-z][a-z0-9+.-]*:/i)

  true
end

def strip_anchor(href)
  href.split('#', 2).first
end

failures = []

ROOT.glob('**/*.md').sort.each do |file|
  rel = file.relative_path_from(ROOT)
  next if skipped?(rel)

  file.read.scan(LINK_PATTERN) do |match|
    href = match.first
    target = strip_anchor(href)
    next unless local_target?(target)

    absolute = (file.dirname + target).cleanpath
    next if absolute.exist?

    failures << "#{rel}: missing link target #{href.shellescape}"
  end
end

if failures.empty?
  puts 'Markdown links OK'
else
  warn failures.join("\n")
  exit 1
end

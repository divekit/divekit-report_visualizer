# This file is executed from a macro `app.cr`.
# It returns all files in the directory given as the first argument.
# These files can then be used to automate rendering the template.
#
# WARNING: If any files in the template directory contain the newline character ('\n'), this will break.

directory = Path[ARGV[0]]
Dir.each_child(directory) do |path|
  puts path if File.file?(directory/path)
end

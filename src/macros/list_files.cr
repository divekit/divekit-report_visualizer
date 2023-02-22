directory = Path[ARGV[0]]
Dir.each_child(directory) do |path|
  puts path if File.file?(directory/path)
end

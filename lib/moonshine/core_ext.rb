# These extensions to Pathname let us use Pathname with puppet more easily
# ie exec "blah", :cwd => Pathname.new('/etc')
Pathname.class_eval do
  def =~(pattern)
    to_s =~ pattern
  end

  def gsub(*args)
    to_s.gsub(*args)
  end
  
end

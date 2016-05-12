class Canvas

  attr_reader :width, :height, :pixels
  attr_writer :pixels
  
  def initialize(args={})
    @width  = args.fetch(:width)
    @height = args.fetch(:height)
    @pixels = fill(default_color) 
  end

  def fill(color)
    self.pixels = Array.new(height) { Array.new(width, color) }
  end

  def default_color
    [0, 0, 0]
  end

end

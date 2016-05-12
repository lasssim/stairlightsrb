placeholder  :dimensions do
  match /(\d+)x(\d+)/ do |width, height|
    OpenStruct.new(width: width.to_i, height: height.to_i)
  end
end



module RedColorSteps
  step "there is a canvas of :dimensions pixels" do |dimensions|
    @canvas = Canvas.new(
      width:  dimensions.width, 
      height: dimensions.height
    )
  end

  step "a User selects the color red" do
    color = [255, 0, 0]
    @canvas.fill(color)
  end

  step 'all pixels should be set to red' do
    @canvas.pixels.each do |line|
      expect(line).to all(be == [255, 0, 0])
    end
  end
end

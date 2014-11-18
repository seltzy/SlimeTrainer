x = 10
y = 10
function love.draw()
love.graphics.setColor(0, 150, 0);
love.graphics.circle( "fill", x, y, 20, 20 )
love.graphics.setColor(150, 200, 150);
love.graphics.circle( "fill", x-4, y-4, 5, 20 )
end

function love.load()
    love.window.setMode(800, 600, {resizable=true, vsync=false, minwidth=400, minheight=300})
end

val = 0   -- establish a variable for later use
function love.update(dt)
	if love.mouse.isDown("r") then
	
	if x < love.mouse.getX() then
    x = x + love.mouse.getX()*dt
	else
	x = x - love.mouse.getX()*dt
	end
	
	if y < love.mouse.getY() then
    y = y + love.mouse.getY()*dt
	else
	y = y - love.mouse.getY()*dt
	end
	
	end
end
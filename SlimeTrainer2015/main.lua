x = 25
y = 25
xGoal = 25
yGoal = 25

function love.draw()
love.graphics.setColor(0, 150, 0);
love.graphics.circle( "fill", x, y, 20, 20 )
love.graphics.setColor(150, 200, 150);
love.graphics.circle( "fill", x-4, y-4, 5, 20 )
end

function love.load()
    love.window.setMode(800, 600, {resizable=true, vsync=false, minwidth=400, minheight=300})
end

function love.update(dt)
	if love.mouse.isDown("l") then
		xGoal = love.mouse.getX()
		yGoal = love.mouse.getY()
	end
	
	ratio = math.pow(math.pow(math.abs(x - xGoal),2)+math.pow(math.abs(y - yGoal),2),.5)
	
	
	if x < xGoal then
    x = x + 100*dt*(math.abs(x - xGoal)/ratio)
	elseif x > xGoal then
	x = x - 100*dt*(math.abs(x - xGoal)/ratio)
	end
	if y < yGoal then
    y = y + 100*dt*(math.abs(y - yGoal)/ratio)
	elseif y > yGoal then
	y = y - 100*dt*(math.abs(y - yGoal)/ratio)
	end
	
	if math.abs(x - xGoal) < 2 then
	x = xGoal
	end
	if math.abs(y - yGoal) < 2 then
	y = yGoal
	end
end
-- Game constants
local GAME_WIDTH = 200
local GAME_HEIGHT = 125

-- Game variables

-- Assets
local spriteSheet

function love.load()
  -- Set default filter to nearest to allow crisp pixel art
  love.graphics.setDefaultFilter('nearest', 'nearest')

  -- Load assets
  -- spriteSheet = love.graphics.newImage('img/sprite-sheet.png')
end

function love.update(dt)
end

-- Renders the game
function love.draw()
  -- Clear the screen
  love.graphics.clear(247 / 255, 247 / 255, 247 / 255)
  love.graphics.setColor(1, 1, 1)
end

-- Draw a sprite from the sprite sheet to the screen
function drawSprite(sx, sy, sw, sh, x, y, flipHorizontal, flipVertical, rotation)
  local width, height = spriteSheet:getDimensions()
  return love.graphics.draw(spriteSheet,
    love.graphics.newQuad(sx, sy, sw, sh, width, height),
    x + sw / 2, y + sh / 2,
    rotation or 0,
    flipHorizontal and -1 or 1, flipVertical and -1 or 1,
    sw / 2, sh / 2)
end

-- Determine whether two rectangles are overlapping
function rectsOverlapping(x1, y1, w1, h1, x2, y2, w2, h2)
  return x1 + w1 > x2 and x2 + w2 > x1 and y1 + h1 > y2 and y2 + h2 > y1
end

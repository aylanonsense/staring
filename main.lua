-- Assets
local spriteSheet

-- Game variables
local entities = {}
local players = {}
local eyebaddies = {}

-- Entity classes
local ENTITY_CLASSES = {
  player = {
    group = players,
    width = 10,
    height = 10,
    update = function(self, dt)
      -- Check inputs
      local isPressingUp = love.keyboard.isDown('up') or love.keyboard.isDown('w')
      local isPressingLeft = love.keyboard.isDown('left') or love.keyboard.isDown('a')
      local isPressingDown = love.keyboard.isDown('down') or love.keyboard.isDown('s')
      local isPressingRight = love.keyboard.isDown('right') or love.keyboard.isDown('d')
      local moveX = (isPressingRight and 1 or 0) - (isPressingLeft and 1 or 0)
      local moveY = (isPressingDown and 1 or 0) - (isPressingUp and 1 or 0)
      -- Adjust velocity
      local speed = 50 * ((moveX == 0 or moveY == 0) and 1.000 or 0.707)
      self.vx = 0.7 * self.vx + 0.3 * moveX * speed
      self.vy = 0.7 * self.vy + 0.3 * moveY * speed
      -- Apply velocity
      self:applyVelocity(dt)
    end
  },
  eyebaddie = {
    group = eyebaddies,
    width = 12,
    height = 12,
    anim = 'passive',
    animTime = 0.00,
    staringTarget = nil,
    update = function(self, dt)
      self.animTime = self.animTime + dt
    end,
    draw = function(self)
      love.graphics.setColor(74 / 255, 74 / 255, 74 / 255)
      love.graphics.rectangle('fill', self.x, self.y, self.width, self.height)
      if self.anim == 'staring' then
        local x1, y1 = self.x + self.width / 2, self. y + self.height / 2
        local x2, y2 = self.staringTarget.x + self.staringTarget.width / 2, self.staringTarget. y + self.staringTarget.height / 2
        love.graphics.setColor(1, 0, 0)
        drawPixelatedLine(x1, y1, x2, y2)
      end
    end,
    startStaring = function(self, target)
      self.anim = 'staring'
      self.animTime = 0.00
      self.staringTarget = target
    end
  }
}

function love.load()
  -- Set default filter to nearest to allow crisp pixel art
  love.graphics.setDefaultFilter('nearest', 'nearest')
  -- Load assets
  spriteSheet = love.graphics.newImage('img/sprite-sheet.png')
  -- Spawn entities
  spawnEntity('player', { x = 30, y = 30 })
  for i = 1, 50 do
    spawnEntity('eyebaddie', { x = math.random(0, 225 - 12), y = math.random(0, 225 - 12) })
  end
  eyebaddies[1]:startStaring(players[1])
end

function love.update(dt)
  -- Update entities
  for _, entity in ipairs(entities) do
    entity:update(dt)
  end
end

function love.draw()
  -- Clear the screen
  love.graphics.clear(247 / 255, 247 / 255, 247 / 255)
  -- Draw entities
  for _, entity in ipairs(entities) do
    love.graphics.setColor(1, 1, 1)
    entity:draw()
  end
end

-- Spawns a new game entity
function spawnEntity(className, params)
  -- Create a default entity
  local entity = {
    type = className,
    x = 0,
    y = 0,
    width = 25,
    height = 25,
    vx = 0,
    vy = 0,
    init = function(self) end,
    update = function(self, dt)
      self:applyVelocity(dt)
    end,
    applyVelocity = function(self, dt)
      self.x = self.x + self.vx * dt
      self.y = self.y + self.vy * dt
    end,
    draw = function(self)
      love.graphics.setColor(74 / 255, 74 / 255, 74 / 255)
      love.graphics.rectangle('fill', self.x, self.y, self.width, self.height)
    end,
    addToGame = function(self)
      table.insert(entities, self)
      if self.group then
        table.insert(self.group, self)
      end
    end,
    removeFromGame = function(self)
      for i = 1, #entities do
        if entities[i] == self then
          table.remove(entities, i)
          break
        end
      end
      if self.group then
        for i = 1, #self.group do
          if self.group[i] == self then
            table.remove(self.group, i)
            break
          end
        end
      end
    end
  }
  -- Add properties from the class
  for k, v in pairs(ENTITY_CLASSES[className]) do
    entity[k] = v
  end
  -- Add properties that were passed into the method
  for k, v in pairs(params) do
    entity[k] = v
  end
  -- Add it to the game, initialize it, and return it
  entity:addToGame()
  entity:init()
  return entity
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

-- Draws a line by drawing little pixely squares
function drawPixelatedLine(x1, y1, x2, y2)
  local dx, dy = math.abs(x2 - x1), math.abs(y2 - y1)
  if dx > dy then
    local minX, maxX = math.floor(math.min(x1, x2)), math.ceil(math.max(x1, x2))
    for x = minX, maxX do
      local y = math.floor(y1 + (y2 - y1) * (x - x1) / (x2 - x1) + 0.5)
      love.graphics.rectangle('fill', x, y, 1, 1)
    end
  else
    local minY, maxY = math.floor(math.min(y1, y2)), math.ceil(math.max(y1, y2))
    for y = minY, maxY do
      local x = math.floor(x1 + (x2 - x1) * (y - y1) / (y2 - y1) + 0.5)
      love.graphics.rectangle('fill', x, y, 1, 1)
    end
  end
end

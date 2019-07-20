-- Constants
local COLORS = {
  BLACK = { 11 / 255, 11 / 255, 4 / 255 },
  DARK_GREY = { 80 / 255, 79 / 255, 68 / 255 },
  PURPLE = { 157 / 255, 52 / 255, 204 / 255 },
  RED = { 253 / 255, 42 / 255, 4 / 255 },
  PURE_WHITE = { 1, 1, 1 }
}

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
    radius = 5,
    state = 'default',
    stateTime = 0.00,
    timeSinceLastDash = 0.00,
    facingX = 1,
    facingY = 0,
    stareX = nil,
    stareY = nil,
    stareTarget = nil,
    update = function(self, dt)
      -- Update timers
      self.stateTime = self.stateTime + dt
      self.timeSinceLastDash = self.timeSinceLastDash + dt
      -- Transition states
      if self.state == 'dashing' and self.stateTime > 0.30 then
        self:setState('default')
      elseif self.state == 'staring' and self.stateTime > 0.20 and not love.keyboard.isDown('space') then 
        self:setState('default')
      end
      self:updateFacing()
      -- Degrade velocity while dashing or staring
      if self.state == 'dashing' or self.state == 'staring' then
        self.vx = self.vx * 0.85
        self.vy = self.vy * 0.85
      -- Control velocity with inputs
      elseif self.state == 'default' then
        local dirX, dirY = self:getInputDirection()
        self.vx = 0.7 * self.vx + 0.3 * dirX * 65
        self.vy = 0.7 * self.vy + 0.3 * dirY * 65
      end
      -- Apply velocity
      self:applyVelocity(dt)
      -- Check for collisions
      for _, eyebaddie in ipairs(eyebaddies) do
        handleCollision(self, eyebaddie)
      end
      -- Update the point the player is staring at
      self.stareX = nil
      self.stareY = nil
      self.stareTarget = nil
      if self.state == 'staring' then
        self.stareX = self.x + 999 * self.facingX
        self.stareY = self.y + 999 * self.facingY
        local stareSquareDist = nil
        for _, eyebaddie in ipairs(eyebaddies) do
          local isIntersecting, xIntersect, yIntersect, intersectSquareDist = calcCircleLineIntersection(self.x, self.y, self.stareX, self.stareY, eyebaddie.x, eyebaddie.y, eyebaddie.radius)
          if isIntersecting and (not stareSquareDist or stareSquareDist > intersectSquareDist) then
            self.stareX = xIntersect
            self.stareY = yIntersect
            self.stareTarget = eyebaddie
            stareSquareDist = intersectSquareDist
          end
        end
      end
    end,
    draw = function(self)
      love.graphics.setColor(COLORS.PURPLE)
      love.graphics.circle('fill', self.x, self.y, self.radius)
      if self.stareX and self.stareY then
        love.graphics.setColor(COLORS.RED)
        drawPixelatedLine(self.x, self.y, self.stareX, self.stareY)
      end
    end,
    keypressed = function(self, key)
      if key == 'space' then
        self:startStaring()
      elseif key == 'lshift' then
        self:dash()
      end
    end,
    getInputDirection = function(self)
      local isPressingUp = love.keyboard.isDown('up') or love.keyboard.isDown('w')
      local isPressingLeft = love.keyboard.isDown('left') or love.keyboard.isDown('a')
      local isPressingDown = love.keyboard.isDown('down') or love.keyboard.isDown('s')
      local isPressingRight = love.keyboard.isDown('right') or love.keyboard.isDown('d')
      local dirX = (isPressingRight and 1 or 0) - (isPressingLeft and 1 or 0)
      local dirY = (isPressingDown and 1 or 0) - (isPressingUp and 1 or 0)
      if dirX ~= 0 and dirY ~= 0 then
        dirX = dirX * 0.707
        dirY = dirY * 0.707
      end
      return dirX, dirY
    end,
    updateFacing = function(self)
      local dirX, dirY = self:getInputDirection()
      if dirX ~= 0 or dirY ~= 0 then
        self.facingX = dirX
        self.facingY = dirY
      end
    end,
    dash = function(self)
      if (self.state == 'default' or self.state == 'staring') and self.timeSinceLastDash > 0.40 then
        local dirX, dirY = self:getInputDirection()
        if dirX ~= 0 or dirY ~= 0 then
          self.vx = 400 * dirX
          self.vy = 400 * dirY
          self.timeSinceLastDash = 0.00
          self:setState('dashing')
        end
      end
    end,
    startStaring = function(self)
      self:setState('staring')
    end,
    setState = function(self, state)
      self.state = state
      self.stateTime = 0.00
    end
  },
  eyebaddie = {
    group = eyebaddies,
    size = 1,
    radius = 0,
    isStationary = true,
    state = 'default',
    stateTime = 0.00,
    stareTarget = nil,
    eyeWhiteDist = 1,
    eyeWhiteAngle = 0,
    timeUntilUpdateEyeWhite = 0.00,
    pupilDist = 1,
    pupilAngle = 0,
    timeUntilUpdatePupil = 0.00,
    init = function(self)
      self.radius = 5 + 2 * self.size
    end,
    update = function(self, dt)
      self.stateTime = self.stateTime + dt
      self.timeUntilUpdateEyeWhite = self.timeUntilUpdateEyeWhite - dt
      self.timeUntilUpdatePupil = self.timeUntilUpdatePupil - dt
      if self.stareTarget then
        local dx = self.stareTarget.x - self.x
        local dy = self.stareTarget.y - self.y
        local dist = math.sqrt(dx * dx + dy * dy)
        local angle = math.atan2(dy, dx)
        if self.timeUntilUpdatePupil < 0 then
          self.timeUntilUpdatePupil = 0.05 + 0.20 * math.random()
          self.pupilDist = 0.3 + math.min(dist / 100, 0.7)
          self.pupilAngle = angle
        end
        if self.timeUntilUpdateEyeWhite < 0 then
          self.timeUntilUpdateEyeWhite = 0.10 + 0.30 * math.random()
          self.eyeWhiteDist = 0.6 + math.min(dist / 200, 0.4)
          self.eyeWhiteAngle = angle
        end
      end
    end,
    draw = function(self)
      local eyeWhiteX = self.eyeWhiteDist * 0.25 * self.radius * math.cos(self.eyeWhiteAngle)
      local eyeWhiteY = self.eyeWhiteDist * 0.35 * self.radius * math.sin(self.eyeWhiteAngle)
      local pupilX = self.pupilDist * 0.35 * self.radius * math.cos(self.pupilAngle)
      local pupilY = self.pupilDist * 0.25 * self.radius * math.sin(self.pupilAngle)
      local pupilSize = self.size > 2 and 3 or 2
      love.graphics.setColor(COLORS.PURE_WHITE)
      -- Draw ball
      drawSprite(1 + 30 * (4 - self.size), 1, 29, 29, self.x - 14.5, self.y - 14.5)
      -- Draw white of eyes
      drawSprite(1 + 20 * (4 - self.size), 31, 19, 20, self.x + eyeWhiteX - 9.5, self.y + eyeWhiteY - 10)
      -- Draw pupil
      love.graphics.setColor(COLORS.DARK_GREY)
      love.graphics.rectangle('fill', self.x + eyeWhiteX + pupilX - pupilSize / 2, self.y + eyeWhiteY + pupilY - pupilSize / 2, pupilSize, pupilSize)
    end,
    startStaring = function(self, target)
      self:setState('staring')
      self.stareTarget = target
    end,
    setState = function(self, state)
      self.state = state
      self.stateTime = 0.00
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
  for i = 1, 30 do
    spawnEntity('eyebaddie', { x = math.random(20, 205), y = math.random(20, 205), size = math.random(1, 4) })
    eyebaddies[i]:startStaring(players[1])
  end
  -- Move the eyebaddies so they aren't overlapping
  for iteration = 1, 3 do
    for i = 1, #eyebaddies do
      for j = i + 1, #eyebaddies do
        handleCollision(eyebaddies[i], eyebaddies[j])
      end
    end
  end
end

function love.update(dt)
  -- Update entities
  for _, entity in ipairs(entities) do
    entity:update(dt)
  end
end

function love.draw()
  -- Clear the screen
  love.graphics.clear(COLORS.BLACK)
  -- Draw entities
  for _, entity in ipairs(entities) do
    love.graphics.setColor(1, 1, 1)
    entity:draw()
  end
end

function love.keypressed(...)
  for _, entity in ipairs(entities) do
    entity:keypressed(...)
  end
end

-- Spawns a new game entity
function spawnEntity(className, params)
  -- Create a default entity
  local entity = {
    type = className,
    x = 0,
    y = 0,
    radius = 10,
    vx = 0,
    vy = 0,
    isStationary = false,
    init = function(self) end,
    update = function(self, dt)
      self:applyVelocity(dt)
    end,
    applyVelocity = function(self, dt)
      self.x = self.x + self.vx * dt
      self.y = self.y + self.vy * dt
    end,
    draw = function(self)
      love.graphics.setColor(COLORS.DARK_GREY)
      love.graphics.circle('fill', self.x, self.y, self.radius)
    end,
    keypressed = function(self, key) end,
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

-- Moves two circular entities apart so they're not overlapping
function handleCollision(entity1, entity2)
  -- Figure out how far apart the entities are
  local dx = entity2.x - entity1.x
  local dy = entity2.y - entity1.y
  if dx == 0 and dy == 0 then
    dy = 0.1
  end
  local squareDist = dx * dx + dy * dy
  local sumRadii = entity1.radius + entity2.radius
  -- If the entities are close enough, they're colliding
  if squareDist < sumRadii * sumRadii then
    local dist = math.sqrt(squareDist)
    local pushAmount = sumRadii - dist
    -- Push one away from the other
    if entity2.isStationary and not entity1.isStationary then
      entity1.x = entity1.x - pushAmount * dx / dist
      entity1.y = entity1.y - pushAmount * dy / dist
    elseif entity1.isStationary and not entity2.isStationary then
      entity2.x = entity2.x + pushAmount * dx / dist
      entity2.y = entity2.y + pushAmount * dy / dist
    -- Push them both away from each other
    else
      entity1.x = entity1.x - (pushAmount / 2) * dx / dist
      entity1.y = entity1.y - (pushAmount / 2) * dy / dist
      entity2.x = entity2.x + (pushAmount / 2) * dx / dist
      entity2.y = entity2.y + (pushAmount / 2) * dy / dist
    end
    return true
  -- If the entities are far from one another, they're not colliding
  else
    return false
  end
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

function calcCircleLineIntersection(x1, y1, x2, y2, cx, cy, r)
  local dx = x2 - x1
  local dy = y2 - y1
  local A = dx * dx + dy * dy
  local B = 2 * (dx * (x1 - cx) + dy * (y1 - cy))
  local C = (x1 - cx) * (x1 - cx) + (y1 - cy) * (y1 - cy) - r * r
  local det = B * B - 4 * A * C
  if det >= 0 then
    local rootDet = math.sqrt(det)
    local t1 = (-B + rootDet) / (2 * A)
    local t2 = (-B - rootDet) / (2 * A)
    local xIntersection1 = x1 + t1 * dx
    local yIntersection1 = y1 + t1 * dy
    local xIntersection2 = x1 + t2 * dx
    local yIntersection2 = y1 + t2 * dy
    local squareDist1 = (xIntersection1 - x1) * (xIntersection1 - x1) + (yIntersection1 - y1) * (yIntersection1 - y1)
    local squareDist2 = (xIntersection2 - x1) * (xIntersection2 - x1) + (yIntersection2 - y1) * (yIntersection2 - y1)
    local xMin = math.min(x1, x2)
    local xMax = math.max(x1, x2)
    local yMin = math.min(y1, y2)
    local yMax = math.max(y1, y2)
    if squareDist1 < squareDist2 and xMin - 1 < xIntersection1 and xIntersection1 < xMax + 1 and yMin - 1 < yIntersection1 and yIntersection1 < yMax + 1 then
      return true, xIntersection1, yIntersection1, squareDist1
    elseif xMin - 1 < xIntersection2 and xIntersection2 < xMax + 1 and yMin - 1 < yIntersection2 and yIntersection2 < yMax + 1 then
      return true, xIntersection2, yIntersection2, squareDist2
    else
      return false
    end
  end
  return false
end

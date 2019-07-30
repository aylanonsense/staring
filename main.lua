-- Constants
local GAME_WIDTH = 300
local GAME_HEIGHT = 175
local GAME_OFFSET_X = 5
local GAME_OFFSET_Y = 20
local COLORS = {
  WHITE = { 243 / 255, 241 / 255, 241 / 255 }, -- #f3f1f1
  PURE_WHITE = { 1, 1, 1 } -- #ffffff
}

-- Assets
local spriteSheet

-- Game variables
local entities = {}
local newEntities = {}

-- Entity classes
local ENTITY_CLASSES = {}

function love.load()
  -- Set default filter to nearest to allow crisp pixel art
  love.graphics.setDefaultFilter('nearest', 'nearest')
  -- Load assets
  spriteSheet = love.graphics.newImage('img/sprite-sheet.png')
  -- Spawn entities
  addNewEntitiesToGame()
end

function love.update(dt)
  -- Update entities
  for _, entity in ipairs(entities) do
    entity.framesAlive = entity.framesAlive + 1
    entity.timeAlive = entity.timeAlive + dt
    entity:update(dt)
  end
  -- Add newly spawned entities to the game
  addNewEntitiesToGame()
  -- Remove dead entities from the game
  removeDeadEntitiesFromGame()
end

function love.draw()
  -- Clear the screen
  love.graphics.clear(COLORS.WHITE)
  -- Draw the game
  love.graphics.push()
  love.graphics.translate(GAME_OFFSET_X, GAME_OFFSET_Y)
  love.graphics.setScissor(GAME_OFFSET_X, GAME_OFFSET_Y, GAME_WIDTH, GAME_HEIGHT)
  -- Draw entities
  for _, entity in ipairs(entities) do
    love.graphics.setColor(COLORS.PURE_WHITE)
    entity:draw()
  end
  love.graphics.pop()
end

function love.mousepressed(...) end
function love.keypressed(...) end
function love.joystickadded(joystick) end
function love.joystickpressed(...) end
function love.joystickreleased(...) end

-- Spawns a new game entity
function spawnEntity(className, params)
  -- Create a default entity
  local entity = {
    type = className,
    isAlive = true,
    framesAlive = 0,
    timeAlive = 0.00,
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
    end,
    destroy = function(self)
      self.isAlive = false
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
  -- Add it to the list of entities to be added, initialize it, and return it
  table.insert(newEntities, entity)
  entity:init()
  return entity
end

-- Add any entities that were spawned this frame to the game
function addNewEntitiesToGame()
  for _, entity in ipairs(newEntities) do
    entity:addToGame()
  end
  newEntities = {}
end

-- Removes any entities that destroyed this frame from the game
function removeDeadEntitiesFromGame()
  for i = #entities, 1, -1 do
    if not entities[i].isAlive then
      entities[i]:removeFromGame()
    end
  end
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
function handleCircleToCircleCollision(entity1, entity2)
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
function drawPixelatedLine(x1, y1, x2, y2, thickness, gaps, dashes)
  thickness = thickness or 1
  gaps = gaps or 0
  dashes = dashes or (gaps == 0 and 1 or gaps)
  local dx, dy = math.abs(x2 - x1), math.abs(y2 - y1)
  if dx > dy then
    local i = x1 < x2 and 0 or dx
    local minX, maxX = math.floor(math.min(x1, x2) + 0.5), math.floor(math.max(x1, x2) + 0.5)
    for x = minX, maxX do
      if i % (gaps + dashes) < dashes then
        local y = math.floor(y1 + (y2 - y1) * (x - x1) /(x1 == x2 and 1 or x2 - x1) + 0.5)
        love.graphics.rectangle('fill', x - thickness / 2, y - thickness / 2, thickness, thickness)
      end
      i = i + (x1 < x2 and 1 or -1)
    end
  else
    local i = y1 < y2 and 0 or dy
    local minY, maxY = math.floor(math.min(y1, y2) + 0.5), math.floor(math.max(y1, y2) + 0.5)
    for y = minY, maxY do
      if i % (gaps + dashes) < dashes then
        local x = math.floor(x1 + (x2 - x1) * (y - y1) / (y1 == y2 and 1 or y2 - y1) + 0.5)
        love.graphics.rectangle('fill', x - thickness / 2, y - thickness / 2, thickness, thickness)
      end
      i = i + (y1 < y2 and 1 or -1)
    end
  end
end

-- Calculates the intersection between a line segment and a circle
function calcCircleLineIntersection(x1, y1, x2, y2, cx, cy, r)
  -- If the start point is within the circle, return the start point
  if (cx - x1) * (cx - x1) + (cy - y1) * (cy - y1) < r * r then
    return true, x1, y1, 0
  else
    local dx = x2 - x1
    local dy = y2 - y1
    local A = dx * dx + dy * dy
    local B = 2 * (dx * (x1 - cx) + dy * (y1 - cy))
    local C = (x1 - cx) * (x1 - cx) + (y1 - cy) * (y1 - cy) - r * r
    local det = B * B - 4 * A * C
    -- There are no valid intersections
    if det < 0 then
      return false
    else
      -- There is an intersection on the line, but maybe not on the line segment
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
      -- There is an intersection on the line segment
      if squareDist1 < squareDist2 and xMin - 1 < xIntersection1 and xIntersection1 < xMax + 1 and yMin - 1 < yIntersection1 and yIntersection1 < yMax + 1 then
        return true, xIntersection1, yIntersection1, squareDist1
      elseif xMin - 1 < xIntersection2 and xIntersection2 < xMax + 1 and yMin - 1 < yIntersection2 and yIntersection2 < yMax + 1 then
        return true, xIntersection2, yIntersection2, squareDist2
      -- The intersection is not on the line segment
      else
        return false
      end
    end
  end
end

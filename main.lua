-- Constants
local GAME_WIDTH = 300
local GAME_HEIGHT = 175
local COLORS = {
  BLACK = { 11 / 255, 11 / 255, 4 / 255 },
  DARK_GREY = { 66 / 255, 64 / 255, 55 / 255 },
  PURPLE = { 157 / 255, 52 / 255, 204 / 255 },
  GREEN = { 46 / 255, 106 / 255, 39 / 255 },
  RED = { 253 / 255, 42 / 255, 4 / 255 },
  WHITE = { 241 / 255, 241 / 255, 236 / 255 },
  PURE_WHITE = { 1, 1, 1 }
}
local LASER_CHARGE_TIME = 0.75
local PRE_SHOOT_PAUSE_TIME = 0.15
local MORTAR_CHARGE_TIME = 1.50
local PLAYER_RUN_SPEED = 100
local PLAYER_DASH_SPEED = 600
local MAX_PLAYERS = 2
local ENEMY_SPEED = 45
local DEBUG_START_TIME = 0.0

-- Assets
local spriteSheet

-- Game variables
-- local lasersToShoot
-- local timeUntilLaserVolley
-- local timeUntilNextLaser
local levelData
local levelFrame
local joysticks = {}
local entities = {}
local entitiesToBeAdded = {}
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
    facingAngle = 0,
    stareX = nil,
    stareY = nil,
    stareDirX = 1,
    stareDirY = 0,
    stareTarget = nil,
    eyeX = 0,
    eyeY = 0,
    pupilX = 0,
    pupilY = 0,
    health = 100,
    invincibilityFrames = 0,
    isStaring = false,
    update = function(self, dt)
      local joystick = joysticks[self.joystickNum]
      self.invincibilityFrames = math.max(0, self.invincibilityFrames - 1)
      -- Update timers
      self.stateTime = self.stateTime + dt
      self.timeSinceLastDash = self.timeSinceLastDash + dt
      if not self.isStaring and self:shouldBeStaring() then
        self:startStaring()
      end
      -- Transition states
      if self.state == 'dashing' and self.stateTime > 0.30 then
        self:setState('default')
      elseif self.isStaring and self.stateTime > 0.20 and not self:shouldBeStaring() then
        self.isStaring = false
      end
      self:updateFacing()
      self:updateStareDirection()
      -- Degrade velocity while dashing or staring
      if self.state == 'dashing' then
        self.vx = self.vx * 0.85
        self.vy = self.vy * 0.85
      -- Control velocity with inputs
      else
        local dirX, dirY = self:getMoveDirection()
        self.vx = 0.7 * self.vx + 0.3 * dirX * PLAYER_RUN_SPEED
        self.vy = 0.7 * self.vy + 0.3 * dirY * PLAYER_RUN_SPEED
      end
      -- Apply velocity
      self:applyVelocity(dt)
      -- Check for collisions
      for _, eyebaddie in ipairs(eyebaddies) do
        local dx = self.x - eyebaddie.x
        local dy = self.y - eyebaddie.y
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist < eyebaddie.radius + self.radius then
          self:takeDamage()
        end
      end
      -- Update the point the player is staring at
      local oldStareTarget = self.stareTarget
      self.stareX = nil
      self.stareY = nil
      self.stareTarget = nil
      if self.isStaring then
        self.stareX = self.x + 999 * self.stareDirX
        self.stareY = self.y - 2 + 999 * self.stareDirY
        for _, player in ipairs(players) do
          if player ~= self then
            local isIntersecting, xIntersect, yIntersect, intersectSquareDist = calcCircleLineIntersection(self.x, self.y - 2, self.stareX, self.stareY, player.x, player.y, player.radius)
            if isIntersecting then
              self.stareX = xIntersect
              self.stareY = yIntersect
              self.stareTarget = player
              oldStareTarget = nil
            end
          end
        end
        local stareSquareDist = nil
        for _, eyebaddie in ipairs(eyebaddies) do
          local isIntersecting, xIntersect, yIntersect, intersectSquareDist = calcCircleLineIntersection(self.x, self.y - 2, self.stareX, self.stareY, eyebaddie.x, eyebaddie.y, eyebaddie.radius)
          if not isIntersecting and (not oldStareTarget or eyebaddie == oldStareTarget) then
            local dx = eyebaddie.x - self.x
            local dy = eyebaddie.y - self.y
            local dist = math.sqrt(dx * dx + dy * dy)
            isIntersecting, xIntersect, yIntersect, intersectSquareDist = calcCircleLineIntersection(self.x, self.y - 2, self.stareX, self.stareY, eyebaddie.x, eyebaddie.y, eyebaddie.radius + math.min(dist / 4, 15))
          end
          if isIntersecting then
            if eyebaddie == oldStareTarget then
              self.stareTarget = eyebaddie
              break
            end
            if not stareSquareDist or stareSquareDist > intersectSquareDist then
              -- self.stareX = xIntersect
              -- self.stareY = yIntersect
              self.stareTarget = eyebaddie
              stareSquareDist = intersectSquareDist
            end
          end
        end
        if self.stareTarget and self.stareTarget.type ~= 'player' then
          local dx = self.stareTarget.x - self.x
          local dy = self.stareTarget.y - self.y
          local dist = math.sqrt(dx * dx + dy * dy)
          self.stareX = self.x + 999 * dx / dist
          self.stareY = self.y + 999 * dy / dist
        end
      end
      -- Keep player in bounds
      if self.x < self.radius + 5 then
        self.x = self.radius + 5
      elseif self.x > GAME_WIDTH - self.radius - 5 then
        self.x = GAME_WIDTH - self.radius - 5
      end
      if self.y < self.radius + 5 then
        self.y = self.radius + 5
      elseif self.y > GAME_HEIGHT - self.radius - 5 then
        self.y = GAME_HEIGHT - self.radius - 5
      end
      -- Calc eye position
      local pupilOffsetX = 0
      local eyeOffsetX = 0
      if self.facingX > 0.35 then
        eyeOffsetX = 1
      elseif self.facingX < -0.35 then
        eyeOffsetX = -1
      end
      if self.stareDirX > 0.35 then
        pupilOffsetX = 1
      elseif self.stareDirX < -0.35 then
        pupilOffsetX = -1
      end
      if self.vx < -10 then
        eyeOffsetX = eyeOffsetX - 1
      elseif self.vx > 10 then
        eyeOffsetX = eyeOffsetX + 1
      end
      local pupilOffsetY = 0
      local eyeOffsetY = 0
      if self.facingY > 0.35 then
        eyeOffsetY = 1
      elseif self.facingY < -0.35 then
        eyeOffsetY = -1
      end
      if self.stareDirY > 0.35 then
        pupilOffsetY = 1
      elseif self.stareDirY < -0.35 then
        pupilOffsetY = -1
      end
      if self.vy < -10 then
        eyeOffsetY = eyeOffsetY - 1
      elseif self.vy > 10 then
        eyeOffsetY = eyeOffsetY + 1
      end
      self.eyeX, self.eyeY = self.x + eyeOffsetX, self.y - 2 + eyeOffsetY
      self.pupilX, self.pupilY = self.eyeX + pupilOffsetX, self.eyeY + pupilOffsetY
    end,
    draw = function(self)
      local color = self.playerNum == 1 and COLORS.PURPLE or COLORS.GREEN
      local spriteOffset = self.playerNum == 1 and 0 or 18
      -- Draw laser
      love.graphics.setColor(color)
      if self.stareX and self.stareY then
        love.graphics.setColor(color)
        drawPixelatedLine(self.x, self.y - 2, self.stareX, self.stareY)
      end
      if self.invincibilityFrames % 20 < 10 then
        -- Draw body
        love.graphics.setColor(COLORS.PURE_WHITE)
        local speed = math.sqrt(self.vx * self.vx + self.vy * self.vy)
        local frame
        if speed < 20 and self.state ~= 'dashing' then
          frame = 1
        else
          local q = math.floor(8 * (self.facingAngle + math.pi) / (2 * math.pi) + 0.5) % 8
          if q > 4 then
            q = 8 - q
          end
          if q > 2 then
            q = 4 - q
          end
          if q == 0 then
            frame = 3
          elseif q == 1 then
            frame = 2
          else
            frame = 1
          end
          if speed > 1.10 * PLAYER_RUN_SPEED and frame ~= 1 then
            frame = frame + 1
          end
        end
        local flipped = self.facingX < 0
        if self.state == 'dashing' then
          for i = 0, 3 do
            drawSprite(81 + 17 * (frame - 1), 34 + spriteOffset, 16, 17, self.x - (flipped and 10 or 6) - self.vx * i / 60, self.y - 10 - self.vy * i / 60, flipped)
          end
        else
          drawSprite(81 + 17 * (frame - 1), 34 + spriteOffset, 16, 17, self.x - (flipped and 10 or 6), self.y - 10, flipped)
        end
        -- Draw eye
        love.graphics.setColor(COLORS.PURE_WHITE)
        drawSprite(149, 34 + spriteOffset, 8, 8, self.eyeX - 4, self.eyeY - 4)
        love.graphics.setColor(color)
        love.graphics.rectangle('fill', self.pupilX - 1, self.pupilY - 1, 2, 2)
      end
    end,
    keypressed = function(self, key)
      if key == 'lshift' and self.allowKeyboardControls then
        self:dash()
      end
    end,
    joystickpressed = function(self, joystick, btn)
      if joystick == joysticks[self.joystickNum] then
        if btn == 1 or fbtn == 5 or btn == 7 or btn == 6 or btn == 8 then
          self:dash()
        end
      end
    end,
    getMoveDirection = function(self)
      local joystick = joysticks[self.joystickNum]
      if joystick then
        local dirX = joystick:getAxis(1)
        local dirY = joystick:getAxis(2)
        local dist = dirX and dirY and math.sqrt(dirX * dirX + dirY * dirY) or 0.0
        if dist == 0.0 then
          return 0.0, 0.0
        else
          local mag
          if dist < 0.25 then
            mag = 0.0
          elseif dist < 0.7 then
            mag = 0.45
          else
            mag = 1.0
          end
          return mag * dirX / dist, mag * dirY / dist
        end
      elseif self.allowKeyboardControls then
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
      else
        return 0, 0
      end
    end,
    getAimDirection = function(self)
      local joystick = joysticks[self.joystickNum]
      if joystick then
        local dirX = joystick:getAxis(3)
        local dirY = joystick:getAxis(6)
        local dist = dirX and dirY and math.sqrt(dirX * dirX + dirY * dirY) or 0.0
        if dist == 0.0 then
          return 0.0, 0.0
        else
          local mag
          if dist < 0.25 then
            mag = 0.0
          else
            mag = 1.0
          end
          return mag * dirX / dist, mag * dirY / dist
        end
      elseif self.allowMouseControls then
        local mouseX, mouseY = love.mouse.getPosition()
        if mouseX and mouseY then
          mouseY = mouseY - 24
          local dx = mouseX - self.x
          local dy = mouseY - self.y
          local dist = math.sqrt(dx * dx + dy * dy)
          return dx / dist, dy / dist
        else
          return 0.0, 0.0
        end
      else
        return 0.0, 0.0
      end
    end,
    updateFacing = function(self)
      local dirX, dirY = self:getMoveDirection()
      if dirX ~= 0 or dirY ~= 0 then
        self.facingX = dirX
        self.facingY = dirY
        self.facingAngle = math.atan2(dirY, dirX)
      end
    end,
    updateStareDirection = function(self)
      local dirX, dirY = self:getAimDirection()
      if dirX == 0.0 and dirY == 0.0 then
        dirX, dirY = self:getMoveDirection()
      end
      if dirX ~= 0 or dirY ~= 0 then
        self.stareDirX = dirX
        self.stareDirY = dirY
      end
    end,
    dash = function(self)
      if self.timeSinceLastDash > 0.40 then
        local dirX, dirY = self:getMoveDirection()
        if dirX ~= 0 or dirY ~= 0 then
          self.vx = PLAYER_DASH_SPEED * dirX
          self.vy = PLAYER_DASH_SPEED * dirY
          self.timeSinceLastDash = 0.00
          self:setState('dashing')
        end
      end
    end,
    startStaring = function(self)
      self.isStaring = true
    end,
    takeDamage = function(self)
      if self.invincibilityFrames <= 0 and self.state ~= 'dashing' then
        self.health = math.max(0, self.health - 29)
        self.invincibilityFrames = 120
      end
    end,
    shouldBeStaring = function(self)
      local joystick = joysticks[self.joystickNum]
      if joystick then
        local dirX, dirY = self:getAimDirection()
        if dirX ~= 0 or dirY ~= 0 then
          return true
        end
        -- return joystick:isDown(6) or joystick:isDown(8)
      elseif self.allowMouseControls then
        return love.mouse.isDown(1)
      else
        return false
      end
    end,
    setState = function(self, state)
      self.state = state
      self.stateTime = 0.00
    end
  },
  eyebaddie = {
    group = eyebaddies,
    projectileType = 'laser',
    size = 1,
    radius = 0,
    isStationary = true,
    state = 'default',
    stateTime = 0.00,
    intendedStareTarget = nil,
    stareTarget = nil,
    eyeWhiteDist = 0,
    eyeWhiteAngle = 0,
    eyeWhiteX = -999,
    eyeWhiteY = -999,
    timeUntilUpdateEyeWhite = 0.00,
    pupilDist = 0,
    pupilAngle = 0,
    pupilX = -999,
    pupilY = -999,
    timeUntilUpdatePupil = 0.00,
    blinkFrames = 0,
    timeUntilBlink = 0.00,
    staringPlayer = nil,
    timeStaredAt = 0.00,
    shootAngle = nil,
    shootTime = nil,
    init = function(self)
      self.radius = 5 + 2 * self.size
    end,
    update = function(self, dt)
      if self.shootTime then
        self.shootTime = self.shootTime - dt
        if self.shootTime <= 0.00 then
          self.shootTime = nil
          if self.shootAngle then
            self.pupilAngle = self.shootAngle * math.pi / 180 + math.pi
            self.eyeWhiteAngle = self.shootAngle * math.pi / 180 + math.pi
          end
          self:shoot()
        end
      end
      if self.state ~= 'charging' and self.state ~= 'shooting' then
        local closestPlayer = nil
        local closestPlayerSquareDist = 9999
        for _, player in ipairs(players) do
          local dx = player.x - self.x
          local dy = player.y - self.y
          local squareDist = dx * dx + dy * dy
          if not closestPlayer or squareDist < closestPlayerSquareDist then
            closestPlayer = player
            closestPlayerSquareDist = squareDist
          end
        end
        self.intendedStareTarget = closestPlayer
      end
      self.staringPlayer = false
      for _, player in ipairs(players) do
        if player.isStaring and player.stareX and player.stareY then
          local dx = player.x - self.x
          local dy = player.y - self.y
          local dist = math.sqrt(dx * dx + dy * dy)
          local isIntersecting = calcCircleLineIntersection(player.x, player.y - 2, player.stareX, player.stareY, self.x, self.y, self.radius + math.min(dist / 18, 8))
          if isIntersecting then
            self.staringPlayer = player
            break
          end
        end
      end
      if self.staringPlayer then
        self.timeStaredAt = self.timeStaredAt + dt
      else
        self.timeStaredAt = math.max(0.00, self.timeStaredAt - dt / 4)
      end
      self.stateTime = self.stateTime + dt
      self.timeUntilUpdateEyeWhite = self.timeUntilUpdateEyeWhite - dt
      self.timeUntilUpdatePupil = self.timeUntilUpdatePupil - (self.staringPlayer and 5 or 1) * dt
      self.blinkFrames = self.blinkFrames - 1
      self.timeUntilBlink = self.timeUntilBlink - dt
      if self.timeUntilBlink <= 0.00 then
        self.timeUntilBlink = 2.50 + 10.00 * math.random()
        self.blinkFrames = 10
      end
      if self.intendedStareTarget and self.blinkFrames <= 0 then -- TODO blink while laser?
        local changeMult = 1.00
        local distMult = 1.00
        if self.projectileType == 'blast' or self.projectileType == 'laser' then
          if self.state == 'charging' then
            changeMult = math.min(math.max(0.00, 8 * (LASER_CHARGE_TIME - self.stateTime)), 1.00)
          elseif self.state == 'shooting' then
            changeMult = 0.00
          end
        elseif self.projectileType == 'mortar' then
          if self.state == 'charging' then
            distMult = math.max(0.00, 0.50 - self.stateTime)
          elseif self.state == 'shooting' then
            distMult = 0.00
          end
        end
        local dx = self.intendedStareTarget.x - self.x
        local dy = self.intendedStareTarget.y - self.y
        local dist = math.sqrt(dx * dx + dy * dy)
        local angle = math.atan2(dy, dx)
        if self.state == 'charging' and not self.shootAngle then
          self.timeUntilUpdatePupil = 0.00
          if changeMult > 0.00 then
            self.pupilDist = distMult * (0.3 + math.min(dist / 100, 0.7))
          end
          local angleDiff
          if angle - self.pupilAngle > math.pi then
            angleDiff = angle - self.pupilAngle - 2 * math.pi
          elseif angle - self.pupilAngle < -math.pi then
            angleDiff = angle - self.pupilAngle + 2 * math.pi
          else
            angleDiff = angle - self.pupilAngle
          end
          local change = math.min(math.max(-0.035, angleDiff * 0.10), 0.035) * changeMult
          self.pupilAngle = (self.pupilAngle + change) % (2 * math.pi)
        end
        if self.state ~= 'charging' and self.state ~= 'shooting' then
          if self.timeUntilUpdatePupil <= 0 then
            local pupilJitter = self.staringPlayer and 2.0 or 0.2
            self.timeUntilUpdatePupil = 0.05 + 0.20 * math.random()
            self.pupilDist = distMult * (0.3 + math.min(dist / 100, 0.7 - pupilJitter / 5) + pupilJitter / 5 * math.random())
            self.pupilAngle = angle + pupilJitter * math.random() - pupilJitter / 2
          end
          if self.timeUntilUpdateEyeWhite <= 0 then
            self.timeUntilUpdateEyeWhite = 0.20 + 0.30 * math.random()
            if changeMult > 0.00 then
              self.eyeWhiteDist = distMult * (0.55 + math.min(dist / 200, 0.45))
              self.eyeWhiteAngle = angle
            end
          end
        end
      end
      self.eyeWhiteX = self.x + self.eyeWhiteDist * 0.25 * self.radius * math.cos(self.eyeWhiteAngle)
      self.eyeWhiteY = self.y + self.eyeWhiteDist * 0.35 * self.radius * math.sin(self.eyeWhiteAngle)
      self.pupilX = self.eyeWhiteX + self.pupilDist * 0.35 * self.radius * math.cos(self.pupilAngle)
      self.pupilY = self.eyeWhiteY + self.pupilDist * 0.25 * self.radius * math.sin(self.pupilAngle)
      if self.state == 'charging' then
        if self.framesAlive % math.floor(10 - 4 * self.stateTime / LASER_CHARGE_TIME) == 0 and self.stateTime < LASER_CHARGE_TIME then
          local angle
          if self.projectileType == 'blast' or self.projectileType == 'laser' then
            angle = self.eyeWhiteAngle + (3.50 * math.random() - 1.75) * (1.0 - 1.0 * self.stateTime / LASER_CHARGE_TIME)
          else
            angle = 2 * math.pi * math.random()
          end
          local cosAngle = math.cos(angle)
          local sinAngle = math.sin(angle)
          local dist = (math.random(4, 11) + 4 * self.size) * (1.0 + 0.6 * self.stateTime / LASER_CHARGE_TIME)
          spawnEntity('lineparticle', {
            tween = 'out',
            x = self.x + dist * cosAngle,
            y = self.y + dist * sinAngle,
            targetX = self.pupilX,
            targetY = self.pupilY,
            duration = (0.12 + 0.08 * self.size) * (1.00 - 0.75 * math.min(1.00, self.stateTime / LASER_CHARGE_TIME))
          })
        end
      end
      if self.state == 'charging' and self.projectileType == 'mortar' and self.stateTime >= MORTAR_CHARGE_TIME + PRE_SHOOT_PAUSE_TIME then
        self:setState('shooting')
        spawnEntity('mortar', {
          x = self.pupilX,
          y = self.pupilY,
          targetX = self.intendedStareTarget.x + math.random(-30, 30),
          targetY = self.intendedStareTarget.y + math.random(-15, 15)
        })
        local numLineParticles = 6 + 4 * self.size
        for i = 1, numLineParticles do
          local angle = 2 * math.pi * (i / numLineParticles)
          local dist = 20
          local cosAngle = math.cos(angle)
          local sinAngle = math.sin(angle)
          local startDist = 0.2 * self.radius
          local endDist = 2 + 1.2 * self.radius
          spawnEntity('lineparticle', {
            tween = 'in',
            x = self.x + startDist * cosAngle,
            y = self.y - 2 + startDist * sinAngle,
            targetX = self.x + endDist * cosAngle,
            targetY = self.y - 2 + endDist * sinAngle,
            color = COLORS.RED,
            duration = 0.20
          })
        end
      end
      if self.state == 'charging' and self.projectileType == 'blast' and self.stateTime >= LASER_CHARGE_TIME + PRE_SHOOT_PAUSE_TIME then
        self:setState('shooting')
        spawnEntity('blast', {
          x = self.pupilX,
          y = self.pupilY,
          vx = 999 * math.cos(self.pupilAngle),
          vy = 999 * math.sin(self.pupilAngle)
        })
      end
      if self.state == 'charging' and self.projectileType == 'laser' and self.stateTime >= LASER_CHARGE_TIME + PRE_SHOOT_PAUSE_TIME then
        self:setState('shooting')
      end
      if self.timeStaredAt > 0.30 * self.size + 0.40 and self.staringPlayer and self.isAlive then
        self:die()
        -- Spawn some particles
        local dx = self.x - self.staringPlayer.x
        local dy = self.y - self.staringPlayer.y
        local dist = math.sqrt(dx * dx + dy * dy)
        local startAngle = math.pi * math.random()
        local numPoofParticles = math.floor(20 * (self.size + 0.5))
        for i = 1, numPoofParticles do
          local size = math.random(1, 4)
          local speed = math.random(55, 75) * (5 - size) * (1 + self.size)
          local spawnDist = 0.5 + math.random() * (self.radius - 0.5)
          local spawnAngle = startAngle + 2 * math.pi * (i / numPoofParticles) + 0.5 * math.random()
          local spawnCos = math.cos(spawnAngle)
          local spawnSin = math.sin(spawnAngle)
          -- local speedStare
          local speedOutwards = speed * spawnDist / self.radius
          local speedStare = speed
          if i % 10 == 0 then
            speedStare = speedStare / 2
          else
            speedOutwards = speedOutwards / 2
          end
          spawnEntity('poofparticle', {
            x = self.x + spawnDist * spawnCos,
            y = self.y + spawnDist * spawnSin,
            size = size,
            vx = speedOutwards * spawnCos + speedStare * dx / dist,
            vy = speedOutwards * spawnSin + speedStare * dy / dist
          })
        end
        local numLineParticles = 6 + 4 * self.size
        for i = 1, numLineParticles do
          local angle = startAngle + 4 * math.pi * ((i + (i <= numLineParticles / 2 and 0 or 0.5)) / numLineParticles)
          local dist = 30
          local cosAngle = math.cos(angle)
          local sinAngle = math.sin(angle)
          local startDist = (i <= numLineParticles / 2 and 0.2 or 0.3) * self.radius
          local endDist = 20 + (i <= numLineParticles / 2 and 2.0 or 0.6) * self.radius
          spawnEntity('lineparticle', {
            tween = 'in',
            x = self.x + startDist * cosAngle,
            y = self.y + startDist * sinAngle,
            targetX = self.x + endDist * cosAngle,
            targetY = self.y + endDist * sinAngle,
            color = COLORS.WHITE,
            duration = 0.15 + 0.15 * math.random()
          })
        end
      end
      if self.state == 'shooting' and self.stateTime > 0.75 and self.projectileType ~= 'laser' then
        self:setState('default')
      end
      if self.state == 'shooting' and self.projectileType == 'laser' then
        for _, player in ipairs(players) do
          local isIntersecting = calcCircleLineIntersection(self.pupilX, self.pupilY, self.pupilX + 999 * math.cos(self.pupilAngle), self.pupilY + 999 * math.sin(self.pupilAngle), player.x, player.y, player.radius)
          if isIntersecting then
            player:takeDamage()
          end
        end
      end
      self:applyVelocity(dt)
      if self.x < -20 then
        self:die()
      end
    end,
    draw = function(self)
      local offsetX = 0
      local offsetY = 0
      if self.projectileType == 'blast' or self.projectileType == 'laser' then
        if self.state == 'charging' and self.stateTime > LASER_CHARGE_TIME then
          offsetX = offsetX - math.cos(self.pupilAngle)
          offsetY = offsetY - math.sin(self.pupilAngle)
        elseif self.state == 'shooting' then
          offsetX = offsetX + 2 * math.cos(self.pupilAngle)
          offsetY = offsetY + 2 * math.sin(self.pupilAngle)
        end
      end
      if self.projectileType == 'mortar' then
        if self.state == 'charging' and self.stateTime > MORTAR_CHARGE_TIME then
          offsetY = offsetY + 2
        elseif self.state == 'shooting' then
          offsetY = offsetY - 2
        end
      end
      if self.staringPlayer then
        offsetX = offsetX + (0.2 + self.timeStaredAt) * (2 * math.floor((self.framesAlive % 4) / 2) - 1)
      end
      local x = self.x + offsetX
      local y = self.y + offsetY
      local pupilSize = self.size > 2 and 3 or 2
      love.graphics.setColor(COLORS.PURE_WHITE)
      -- Draw ball
      drawSprite(1 + 30 * (4 - self.size), 1, 29, 29, x - 14.5, y - 14.5)
      -- Draw white of eyes
      local frame
      if self.state == 'charging' then
        frame = 6
      elseif self.state == 'shooting' then
        frame = 1
      elseif self.blinkFrames > 0 then
        if self.blinkFrames <= 5 then
          frame = self.blinkFrames
        else
          frame = 11 - self.blinkFrames
        end
      else
        frame = 1
      end
      drawSprite(1 + 20 * (4 - self.size), 31 + 21 * (frame - 1), 19, 20, self.eyeWhiteX + offsetX - 9.5, self.eyeWhiteY + offsetY - 10)
      -- Draw pupil
      love.graphics.setColor((self.state == 'charging' or self.state == 'shooting') and COLORS.RED or COLORS.DARK_GREY)
      love.graphics.rectangle('fill', self.pupilX + offsetX - pupilSize / 2, self.pupilY + offsetY - pupilSize / 2, pupilSize, pupilSize)
      -- Draw laser
      if self.state == 'charging' and (self.projectileType == 'blast' or self.projectileType == 'laser') then
        drawPixelatedLine(self.pupilX, self.pupilY, self.pupilX + 999 * math.cos(self.pupilAngle), self.pupilY + 999 * math.sin(self.pupilAngle), 1, 4, 1)
      end
      if self.state == 'shooting' and self.projectileType == 'laser' then
        drawPixelatedLine(self.pupilX, self.pupilY, self.pupilX + 999 * math.cos(self.pupilAngle), self.pupilY + 999 * math.sin(self.pupilAngle), 2)
      end
    end,
    shoot = function(self)
      self:setState('charging')
    end,
    setState = function(self, state)
      self.state = state
      self.stateTime = 0.00
    end
  },
  poofparticle = {
    isRed = false,
    radius = 0,
    size = 1,
    timeToShrink = 0.00,
    init = function(self)
      self.radius = self.size
      self.timeToShrink = 0.10 + 0.10 * math.random()
    end,
    update = function(self, dt)
      self.timeToShrink = self.timeToShrink - dt
      if self.timeToShrink <= 0.00 then
        self.timeToShrink = 0.10 + 0.10 * math.random()
        if self.size > 1 then
          self.size = self.size - 1
        else
          self:die()
        end
      end
      self.vx = self.vx * 0.91
      self.vy = self.vy * 0.91
      self:applyVelocity(dt)
      -- if self.x < self.radius then
      --   self.x = self.radius
      --   self.vx = math.abs(self.vx)
      -- elseif self.x > GAME_WIDTH - self.radius then
      --   self.x = GAME_WIDTH - self.radius
      --   self.vx = -math.abs(self.vx)
      -- end
      -- if self.y < self.radius then
      --   self.y = self.radius
      --   self.vy = math.abs(self.vy)
      -- elseif self.y > GAME_HEIGHT - self.radius then
      --   self.y = GAME_HEIGHT - self.radius
      --   self.vy = -math.abs(self.vy)
      -- end
    end,
    draw = function(self)
      drawSprite(121 + 11 * (4 - self.size), self.isRed and 12 or 1, 10, 10, self.x - 5, self.y - 5)
    end
  },
  lineparticle = {
    color = COLORS.RED,
    tween = 'out',
    init = function(self)
      self.prevX = self.x
      self.prevY = self.y
      self.startX = self.x
      self.startY = self.y
    end,
    update = function(self, dt)
      local t = math.min(math.max(0.00, self.timeAlive / self.duration), 1.00)
      local p
      if self.tween == 'out' then
        p = t * t
      elseif self.tween == 'in' then
        p = math.pow(t, 1 / 3)
      else
        p = t
      end
      self.prevX = self.x
      self.prevY = self.y
      self.x = self.targetX * p + self.startX * (1 - p)
      self.y = self.targetY * p + self.startY * (1 - p)
      if self.timeAlive >= self.duration then
        self:die()
      end
    end,
    draw = function(self)
      love.graphics.setColor(self.color)
      drawPixelatedLine(self.prevX, self.prevY, self.x, self.y)
    end
  },
  blast = {
    color = COLORS.RED,
    init = function(self)
      self.startX = self.x
      self.startY = self.y
      self.tailX = self.x
      self.tailY = self.y
      -- self.dx = self.targetX - self.x
      -- self.dy = self.targetY - self.y
      -- self.laserLength = math.sqrt(self.dx * self.dx + self.dy * self.dy)
      -- for i = 1, self.laserLength > 75 and 3 or 1 do
      --   local distFromLaser = math.random(1, 2) * (i % 2 == 0 and -1 or 1)
      --   local x = self.x + distFromLaser * self.dy / self.laserLength
      --   local y = self.y - distFromLaser * self.dx / self.laserLength
      --   local startDist = 15 * (i - 0.5) + math.random(-5, 5)
      --   spawnEntity('lineparticle', {
      --      x = x + startDist * self.dx / self.laserLength,
      --      y = y + startDist * self.dy / self.laserLength,
      --      tween = 'in',
      --      targetX = x + (startDist + 10) * self.dx / self.laserLength,
      --      targetY = y + (startDist + 10) * self.dy / self.laserLength,
      --      duration = 0.10,
      --      color = COLORS.RED
      --   })
      -- end
    end,
    update = function(self, dt)
      -- if self.timeAlive > 0.25 then
      --   self:die()
      -- end
      self:applyVelocity(dt)
      local dx = self.startX - self.x
      local dy = self.startY - self.y
      local dist = math.sqrt(dx * dx + dy * dy)
      local length = math.min(dist, 100)
      self.tailX = self.x - length * dx / dist
      self.tailY = self.y - length * dy / dist
    end,
    draw = function(self)
      love.graphics.setColor(self.color)
      -- local startDist = math.min(math.max(0.00, 2000 * (self.timeAlive - 0.12)), self.laserLength)
      -- local endDist = math.min(2000 * self.timeAlive, self.laserLength)
      -- local startX = self.x + startDist * self.dx / self.laserLength
      -- local startY = self.y + startDist * self.dy / self.laserLength
      -- local endX = self.x + endDist * self.dx / self.laserLength
      -- local endY = self.y + endDist * self.dy / self.laserLength
      drawPixelatedLine(self.tailX, self.tailY, self.x, self.y, 3)
    end
  },
  mortar = {
    z = 5.0,
    vz = 1.75,
    init = function(self)
      self.vx = (self.targetX - self.x) / 1.5
      self.vy = (self.targetY - self.y) / 1.5
    end,
    update = function(self, dt)
      self.vz = self.vz - 2.35 * dt
      self.z = math.max(0.00, self.z + self.vz)
      self:applyVelocity(dt)
      if self.timeAlive > 1.50 then
        self:die()
        for _, player in ipairs(players) do
          local dx = player.x - self.x
          local dy = player.y - self.y
          local dist = math.sqrt(dx * dx + 4 * dy * dy)
          if dist < 32 then
            player:takeDamage()
          end
        end
        local startAngle = math.pi * math.random()
        local numPoofParticles = 60
        for i = 1, numPoofParticles do
          local size = math.random(1, 4)
          local speed = math.random(85, 125) * (5 - size)
          local spawnDist = 0.5 + math.random()
          local spawnAngle = startAngle + 2 * math.pi * (i / numPoofParticles) + 0.5 * math.random()
          local spawnCos = math.cos(spawnAngle)
          local spawnSin = math.sin(spawnAngle)
          spawnEntity('poofparticle', {
            isRed = true,
            x = self.x + spawnDist * spawnCos,
            y = self.y + spawnDist * spawnSin / 2,
            size = size,
            vx = speed * spawnCos,
            vy = speed * spawnSin / 2 + (i % 5 == 0 and -175 or 0)
          })
        end
      end
    end,
    drawBackground = function(self)
      love.graphics.setColor(COLORS.PURE_WHITE)
      drawSprite(165, 1, 66, 35, self.targetX - 33, self.targetY - 17.5)
    end,
    draw = function(self)
      love.graphics.setColor(COLORS.PURE_WHITE)
      drawSprite(121, 12, 10, 10, self.x - 5, self.y - 5 - self.z)
      love.graphics.setColor(COLORS.RED)
      drawPixelatedLine(self.x, self.y, self.x, self.y - self.z, 1, 4, 1)
    end
  }
}

function love.load()
  levelFrame = DEBUG_START_TIME * 60
  levelData = generateLevelData()
  -- lasersToShoot = 0
  -- timeUntilLaserVolley = 1.00
  -- timeUntilNextLaser = 0.00
  -- Set default filter to nearest to allow crisp pixel art
  love.graphics.setDefaultFilter('nearest', 'nearest')
  -- Load assets
  spriteSheet = love.graphics.newImage('img/sprite-sheet.png')
  -- Spawn entities
  spawnEntity('player', { x = 102, y = 112, playerNum = 1, joystickNum = 2, allowKeyboardControls = true, allowMouseControls = true })
  spawnEntity('player', { x = 123, y = 112, playerNum = 2, joystickNum = 1 })
  -- for i = 1, 10 do
  --   spawnEntity('eyebaddie', {
  --     x = math.random(20, 205),
  --     y = math.random(20, 205),
  --     size = math.random(1, 4)
  --   })
  -- end
  addEntitiesToGame()
  -- Move the eyebaddies so they aren't overlapping
  -- for iteration = 1, 3 do
  --   for i = 1, #eyebaddies do
  --     for j = i + 1, #eyebaddies do
  --       handleCollision(eyebaddies[i], eyebaddies[j])
  --     end
  --   end
  -- end
end

function love.update(dt)
  levelFrame = levelFrame + 1
  local frame = 0
  for _, entry in ipairs(levelData) do
    if type(entry) == 'number' then
      frame = frame + math.floor(60 * entry + 0.5)
    else
      local amount = entry.amount or 1
      local timeBetween = math.floor(60 * (entry.timeBetween or 1 / 6) + 0.5)
      if levelFrame >= frame and (levelFrame - frame) % timeBetween == 0 then
        local n = math.floor((levelFrame - frame) / timeBetween)
        if n < amount then
          local x = entry.x or (GAME_WIDTH + 15)
          local y = entry.y or math.random(7, GAME_HEIGHT - 7)
          local vx = entry.vx or -ENEMY_SPEED
          local vy = entry.vy or 0
          local size = entry.size or math.random(1, 4)
          local shootAngle = entry.shootAngle
          local shootTime = nil
          if entry.shoot ~= false then
            shootTime = entry.shootTime or 0.65
          end
          spawnEntity('eyebaddie', {
            x = x + (entry.dx or 0) * n,
            y = y + (entry.dy or 0) * n,
            size = size + (entry.dsize or 0) * n,
            vx = vx + (entry.dvx or 0) * n,
            vy = vy + (entry.dvy or 0) * n,
            shootAngle = shootAngle and (shootAngle + (entry.dShootAngle or 0) * n) or nil,
            shootTime = shootTime and (shootTime + (entry.dShootTime or 0) * n) or nil
          })
        end
      end
    end
  end
  -- Update entities
  for _, entity in ipairs(entities) do
    entity.framesAlive = entity.framesAlive + 1
    entity.timeAlive = entity.timeAlive + dt
    entity:update(dt)
  end
  addEntitiesToGame()
  removeEntitiesFromGame()
  for i, player in ipairs(players) do
    for j, other in ipairs(players) do
      if i < j and player.stareTarget == other and other.stareTarget == player then
        player.health = math.min(100, player.health + 15 * dt)
        other.health = math.min(100, other.health + 15 * dt)
      end
    end
  end
  -- timeUntilLaserVolley = timeUntilLaserVolley - dt
  -- if timeUntilLaserVolley <= 0.00 then
  --   lasersToShoot = 3
  --   timeUntilLaserVolley = 3.00
  --   timeUntilNextLaser = 0.00
  -- end
  -- if lasersToShoot > 0 then
  --   timeUntilNextLaser = timeUntilNextLaser - dt
  --   if timeUntilNextLaser <= 0.00 then
  --     lasersToShoot = lasersToShoot - 1
  --     timeUntilNextLaser = 0.30
  --     local offset = math.random(1, #eyebaddies)
  --     for i = 1, #eyebaddies do
  --       local eyebaddie = eyebaddies[(i + offset - 1) % #eyebaddies + 1]
  --       if eyebaddie.state ~= 'charging' and eyebaddie.state ~= 'shooting' then
  --         eyebaddie:shoot()
  --         break
  --       end
  --     end
  --   end
  -- end
end

function love.draw()
  -- Clear the screen
  love.graphics.clear(COLORS.BLACK)
  love.graphics.push()
  love.graphics.translate(0, 24)
  love.graphics.setScissor(0, 24, GAME_WIDTH, GAME_HEIGHT)
  -- Draw entities
  for _, entity in ipairs(entities) do
    love.graphics.setColor(COLORS.PURE_WHITE)
    entity:drawBackground()
  end
  for _, entity in ipairs(entities) do
    love.graphics.setColor(COLORS.PURE_WHITE)
    entity:draw()
  end
  love.graphics.pop()
  -- Draw ui
  love.graphics.setScissor()
  if players[1] then
    love.graphics.setColor(COLORS.PURE_WHITE)
    drawSprite(160, 35, 7, 6, 10, 5)
    love.graphics.setColor(COLORS.PURPLE)
    love.graphics.rectangle('fill', 20, 5, 70, 6)
    love.graphics.setColor(COLORS.BLACK)
    love.graphics.rectangle('fill', 21, 6, 68, 4)
    love.graphics.setColor(COLORS.PURPLE)
    love.graphics.rectangle('fill', 20, 5, 70 * players[1].health / 100, 6)
  end
  if players[2] then
    love.graphics.setColor(COLORS.PURE_WHITE)
    drawSprite(160, 53, 7, 6, 10, 15)
    love.graphics.setColor(COLORS.GREEN)
    love.graphics.rectangle('fill', 20, 15, 70, 6)
    love.graphics.setColor(COLORS.BLACK)
    love.graphics.rectangle('fill', 21, 16, 68, 4)
    love.graphics.setColor(COLORS.GREEN)
    love.graphics.rectangle('fill', 20, 15, 70 * players[2].health / 100, 6)
  end
end

function love.mousepressed(...)
  for _, entity in ipairs(entities) do
    entity:mousepressed(...)
  end
end


function love.keypressed(...)
  for _, entity in ipairs(entities) do
    entity:keypressed(...)
  end
end

function love.joystickadded(joystick)
  for i = 1, MAX_PLAYERS do
    if not joysticks[i] then
      joysticks[i] = joystick
      break
    end
  end
end

function love.joystickpressed(...)
  for _, entity in ipairs(entities) do
    entity:joystickpressed(...)
  end
end

function love.joystickreleased(...)
  for _, entity in ipairs(entities) do
    entity:joystickreleased(...)
  end
end

function generateLevelData()
  local minY = 7
  local maxY = GAME_HEIGHT - 7
  local centerY = GAME_HEIGHT / 2
  return {
    0.5,
    -- Random small eyes
    { size = 1, shoot = false, amount = 5, timeBetween = 1.5 }, 7.5,
    { size = 1, shoot = false, amount = 5, timeBetween = 1.0 }, 5,
    -- Eye lines
    { size = 1, y = math.random(minY, maxY), shoot = false, amount = 6, timeBetween = 0.4 }, 3,
    { size = 1, y = math.random(minY, maxY), shoot = false, amount = 6, timeBetween = 0.4 }, 3,
    { size = 1, y = math.random(minY, maxY), shoot = false, amount = 6, timeBetween = 0.4 }, 3,
    -- Shootin lasers
    { size = 1, shootAngle = 0, amount = 5, timeBetween = 1.2 }, 7,
    { size = 1, y = math.random(minY, maxY - 100), shootAngle = 0, amount = 5, dy = 10, timeBetween = 0.4 }, 4,
    { size = 1, y = math.random(minY + 100, maxY), shootAngle = 0, amount = 5, dy = -10, timeBetween = 0.4 }, 3,
    -- Vertical lasers,
    { size = 2, y = minY + 5, shootAngle = -90, amount = 3, timeBetween = 2.8 }, 1.4,
    { size = 2, y = maxY - 5, shootAngle = 90, amount = 3, timeBetween = 2.8 }, 11,
    -- Speedy small ones
    { size = 1, vx = -100, shoot = false, amount = 60, timeBetween = 0.12 }, 1,
    { size = 2, vx = -100, shoot = false, amount = 5, timeBetween = 1.00 }, 8,
    -- Diagonals
    { size = 2, vx = -75, y = centerY + 15, shootAngle = 45, amount = 5, timeBetween = 1.6 }, 0.8,
    { size = 2, vx = -75, y = centerY - 15, shootAngle = -45, amount = 5, timeBetween = 1.6 }, 8,
    -- Shooty lines
    { size = 1, vx = -75, y = math.random(centerY + 20, maxY), shootAngle = 90, amount = 6, timeBetween = 0.15 }, 3,
    { size = 1, vx = -75, y = math.random(minY, centerY - 20), shootAngle = -90, amount = 6, timeBetween = 0.15 }, 3,
    { size = 1, vx = -75, y = math.random(centerY + 20, maxY), shootAngle = 90, amount = 6, timeBetween = 0.15 }, 3,
    { size = 1, vx = -75, y = math.random(minY, centerY - 20), shootAngle = -90, amount = 6, timeBetween = 0.15 }, 3,
  }
end

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
    drawBackground = function(self) end,
    draw = function(self)
      love.graphics.setColor(COLORS.DARK_GREY)
      love.graphics.circle('fill', self.x, self.y, self.radius)
    end,
    mousepressed = function(self, x, y) end,
    keypressed = function(self, key) end,
    joystickpressed = function(self, joystick, btn) end,
    joystickreleased = function(self, joystick, btn) end,
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
    die = function(self)
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
  table.insert(entitiesToBeAdded, entity)
  entity:init()
  return entity
end

function addEntitiesToGame()
  for _, entity in ipairs(entitiesToBeAdded) do
    entity:addToGame()
  end
  entitiesToBeAdded = {}
end

function removeEntitiesFromGame()
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

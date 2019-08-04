local Controllers = require('src/Controller.lua')

-- Constants
local DEBUG_MODE = false
local COLOR = {
  LIGHT_GREY = { 191 / 255, 190 / 255, 190 / 255 }, -- #bfbebe
  DARK_GREY = { 78 / 255, 74 / 255, 73 / 255 }, -- #4e4a49
  WHITE = { 243 / 255, 241 / 255, 241 / 255 }, -- #f3f1f1
  RED = { 239 / 255, 34 / 255, 9 / 255 }, -- #ef2209
  PURPLE = { 181 / 255, 115 / 255, 229 / 255 }, -- #b573e5
  GREEN = { 115 / 255, 177 / 255, 72 / 255 }, -- #73b148
  PURE_WHITE = { 1, 1, 1 }, -- #ffffff
  DEBUG_GREEN = { 0, 1, 0 }, -- #00ff00
  DEBUG_BLUE = { 0, 0, 1 } -- #0000ff
}
local GAME_X = 23
local GAME_Y = 64
local GAME_WIDTH = 254
local GAME_HEIGHT = 105
local PLAYER_MOVE_SPEED = 60
local PLAYER_DASH_SPEED = 600
local PLAYER_DASH_FRICTION = 0.15
local PLAYER_DASH_DURATION = 0.25
local PLAYER_DASH_COOLDOWN = 0.10
local LASER_MARGIN = {
  TOP = 24,
  SIDE = 12,
  BOTTOM = 12
}
local BADDIE_SPRITES = {
  { x = -2, y = 13 },
  { x = 0, y = 5 },
  { x = 0, y = 22 },
  { x = 0, y = 7 },
  { x = 0, y = 3 },
  { x = -1, y = 9 },
  { x = 4, y = 12 },
  { x = 1, y = 13 },
  { x = -1, y = 19 },
  { x = 0, y = -2 },
  { x = 0, y = 8 },
  { x = 0, y = 14 }
}
local SEATS = {
  { x = 4, y = -6, priority = 1, isSeated = true },
  { x = 23, y = -6, priority = 1, isSeated = true },

  { x = 46, y = 3, priority = 2 },
  { x = 65, y = 3, priority = 2 },

  { x = 88, y = -6, priority = 1, isSeated = true },
  { x = 107, y = -6, priority = 1, isSeated = true },
  { x = 127, y = -6, priority = 1, isSeated = true },
  { x = 147, y = -6, priority = 1, isSeated = true },
  { x = 166, y = -6, priority = 1, isSeated = true },

  { x = 189, y = 3, priority = 2 },
  { x = 208, y = 3, priority = 2 },

  { x = 231, y = -6, priority = 1, isSeated = true },
  { x = 250, y = -6, priority = 1, isSeated = true },

  { x = 4, y = 107, priority = 1, isSeated = true },
  { x = 23, y = 107, priority = 1, isSeated = true },

  { x = 46, y = 100, priority = 2 },
  { x = 65, y = 100, priority = 2 },

  { x = 88, y = 107, priority = 1, isSeated = true },
  { x = 107, y = 107, priority = 1, isSeated = true },
  { x = 127, y = 107, priority = 1, isSeated = true },
  { x = 147, y = 107, priority = 1, isSeated = true },
  { x = 166, y = 107, priority = 1, isSeated = true },

  { x = 189, y = 100, priority = 2 },
  { x = 208, y = 100, priority = 2 },

  { x = 231, y = 107, priority = 1, isSeated = true },
  { x = 250, y = 107, priority = 1, isSeated = true },

  { x = 7, y = 24, priority = 3 },
  { x = 7, y = 51, priority = 3 },
  { x = 7, y = 78, priority = 3 },

  { x = 247, y = 24, priority = 3 },
  { x = 247, y = 51, priority = 3 },
  { x = 247, y = 78, priority = 3 },

  { x = 67, y = 51, priority = 4 },
  { x = 127, y = 51, priority = 4 },
  { x = 187, y = 51, priority = 4 },

  { x = 37, y = 24, priority = 4 },
  { x = 97, y = 24, priority = 4 },
  { x = 157, y = 24, priority = 4 },
  { x = 217, y = 24, priority = 4 },

  { x = 37, y = 78, priority = 4 },
  { x = 97, y = 78, priority = 4 },
  { x = 157, y = 78, priority = 4 },
  { x = 217, y = 78, priority = 4 },
}

-- Assets
local spriteSheet

-- Input variables
local blankController
local mouseAndKeyboardController
local joystickControllers
local playerControllers

-- Game variables
local levelNumber
local levelPhase
local levelFrame
local numPassengersLeftToBoard

-- Entity variables
local entities
local newEntities

-- Entity groups
local players = {}
local baddies = {}
local obstacles = {}

-- Entity classes
local ENTITY_CLASSES = {
  player = {
    groups = { players, obstacles },
    health = 100,
    eyeRadius = 5,
    radius = 6,
    facingX = 1.0,
    facingY = 0.0,
    aimX = 1.0,
    aimY = 0.0,
    aimAngle = 0,
    isDashing = false,
    dashDuration = 0.00,
    dashCooldown = 0.00,
    isAiming = false,
    target = nil,
    targetX = nil,
    targetY = nil,
    eyeWhiteOffsetX = 0,
    eyeWhiteOffsetY = 0,
    pupilOffsetX = 0,
    pupilOffsetY = 0,
    update = function(self, dt)
      local controller = self:getController()
      -- Calculate player facing
      local moveX, moveY, moveMagnitude = controller:getMoveDirection()
      if moveMagnitude >= 0.0 then
        self.facingX = moveX
        self.facingY = moveY
      end
      -- Handle dashes
      self.dashCooldown = math.max(0.00, self.dashCooldown - dt)
      if self.dashDuration > 0.00 then
        self.dashDuration = math.max(0.00, self.dashDuration - dt)
        if self.dashDuration <= 0.00 then
          self.isDashing = false
        end
      end
      if controller:justStartedDashing() and self.dashCooldown <= 0.00 then
        self.isAiming = false
        self.isDashing = true
        self.dashDuration = PLAYER_DASH_DURATION
        self.dashCooldown = PLAYER_DASH_DURATION + PLAYER_DASH_COOLDOWN
        self.vx = PLAYER_DASH_SPEED * self.facingX
        self.vy = PLAYER_DASH_SPEED * self.facingY
      end
      -- Determine whether the player is aiming
      self.isAiming = controller:isAiming() and not self.isDashing
      -- Move the player
      if self.isDashing then
        self.vx = self.vx * (1 - PLAYER_DASH_FRICTION)
        self.vy = self.vy * (1 - PLAYER_DASH_FRICTION)
      else
        local speed = self.isAiming and 0 or PLAYER_MOVE_SPEED
        self.vx = speed * moveX * moveMagnitude
        self.vy = speed * moveY * moveMagnitude
      end
      self:applyVelocity(dt)
      -- Check for collisions
      for _, obstacle in ipairs(obstacles) do
        if obstacle ~= self then
          handleCircleToCircleCollision(self, obstacle)
        end
      end
      -- Keep player in bounds
      self.x = math.min(math.max(self.radius, self.x), GAME_WIDTH - self.radius)
      self.y = math.min(math.max(self.radius, self.y), GAME_HEIGHT - self.radius)
      -- Figure out what the player is aiming at
      local aimX, aimY, aimMagnitude = controller:getAimDirection(self.x + GAME_X, self.y + GAME_Y)
      if aimMagnitude > 0.0 and self.isAiming then
        self.aimX = aimX
        self.aimY = aimY
      elseif moveMagnitude > 0.0 then
        self.aimX = moveX
        self.aimY = moveY
      end
      if not self.isAiming then
        self.target = nil
        self.targetX = nil
        self.targetY = nil
      else
        self.target = nil
        self.targetX = self.x + 999 * self.aimX
        self.targetY = self.y + 999 * self.aimY
        -- See if the we're aiming at anything
        for _, obstacle in ipairs(obstacles) do
          if obstacle ~= self then
            local eyeX, eyeY = self:getEyePosition()
            local obstacleEyeX, obstacleEyeY = obstacle:getEyePosition()
            local dx = eyeX - obstacleEyeX
            local dy = eyeY - obstacleEyeY
            local dist = math.sqrt(dx * dx + dy * dy)
            local fudgeRadius = math.min(math.max(0, dist / 15 - 1.5), 10)
            local isIntersecting, x, y = calcCircleLineIntersection(self.x, self.y, self.targetX, self.targetY, obstacleEyeX, obstacleEyeY, obstacle.eyeRadius + fudgeRadius)
            if isIntersecting then
              self.target = obstacle
              self.targetX = x
              self.targetY = y
            end
          end
        end
        if self.target then
          self.targetX, self.targetY = self.target:getEyePosition()
        else
          -- Keep target in bounds
          if self.targetX < -LASER_MARGIN.SIDE then
            self.targetX = -LASER_MARGIN.SIDE
            self.targetY = self.y + self.aimY / self.aimX * (-LASER_MARGIN.SIDE - self.x)
          end
          if self.targetX > GAME_WIDTH + LASER_MARGIN.SIDE then
            self.targetX = GAME_WIDTH + LASER_MARGIN.SIDE
            self.targetY = self.y + self.aimY / self.aimX * (GAME_WIDTH + LASER_MARGIN.SIDE - self.x)
          end
          if self.targetY < -LASER_MARGIN.TOP then
            self.targetX = self.x + self.aimX / self.aimY * (-LASER_MARGIN.TOP - self.y)
            self.targetY = -LASER_MARGIN.TOP
          end
          if self.targetY > GAME_HEIGHT + LASER_MARGIN.BOTTOM then
            self.targetX = self.x + self.aimX / self.aimY * (GAME_HEIGHT + LASER_MARGIN.BOTTOM - self.y)
            self.targetY = GAME_HEIGHT + LASER_MARGIN.BOTTOM
          end
        end
      end
      -- Update eye
      if not self.isAiming then
        self.eyeWhiteOffsetX = self.aimX
        self.eyeWhiteOffsetY = self.aimY
      end
      self.pupilOffsetX = self.aimX
      self.pupilOffsetY = self.aimY
    end,
    draw = function(self, renderLayer)
      if renderLayer == 1 then
        -- Draw shadow
        local shadowSprite = 5
        drawSprite(100 + 20 * (shadowSprite - 1), 185, 19, 7, self.x - 9.5, self.y - 1)
      elseif renderLayer == 3 then
        -- Draw body
        love.graphics.setColor(COLOR.PURE_WHITE)
        drawSprite(1, self.color == COLOR.PURPLE and 341 or 360, 23, 18, self.x - 12.5, self.y - 11)
        if DEBUG_MODE then
          love.graphics.setColor(COLOR.DEBUG_BLUE)
          love.graphics.circle('line', self.x, self.y, self.radius)
        end
      elseif renderLayer == 4 then
        -- Draw laser
        if self.isAiming then
          local pupilX, pupilY = self:getPupilPosition()
          love.graphics.setColor(self.color)
          drawPixelatedLine(pupilX, pupilY, self.targetX, self.targetY)
        end
      elseif renderLayer == 5 then
        -- Draw eye
        love.graphics.setColor(COLOR.PURE_WHITE)
        local eyeWhiteX, eyeWhiteY = self:getEyeWhitePosition()
        local eyeFrame = 3
        drawSprite(56 + 11 * (eyeFrame - 1), 185, 10, 7, eyeWhiteX - 5, eyeWhiteY - 3)
        local pupilX, pupilY = self:getPupilPosition()
        love.graphics.setColor(self.color)
        love.graphics.rectangle('fill', pupilX - 0.5, pupilY - 0.5, 1, 1)
        if DEBUG_MODE then
          local eyeX, eyeY = self:getEyePosition()
          love.graphics.setColor(COLOR.DEBUG_GREEN)
          love.graphics.circle('line', eyeX, eyeY, self.eyeRadius)
        end
      end
    end,
    getController = function(self)
      return playerControllers[self.playerNum] or blankController
    end,
    getEyePosition = function(self)
      return self.x, self.y - 2
    end,
    getEyeWhitePosition = function(self)
      local x, y = self:getEyePosition()
      return x + self.eyeWhiteOffsetX, y + self.eyeWhiteOffsetY
    end,
    getPupilPosition = function(self)
      local x, y = self:getEyeWhitePosition()
      return x + self.pupilOffsetX, y + self.pupilOffsetY
    end
  },
  baddie = {
    groups = { baddies, obstacles },
    radius = 5,
    eyeRadius = 5,
    eyeOffsetX = 0,
    eyeOffsetY = 0,
    eyeWhiteOffsetX = 0,
    eyeWhiteOffsetY = 0,
    timeUntilEyeWhiteUpdate = 0.00,
    pupilOffsetX = 0,
    pupilOffsetY = 0,
    timeUntilPupilUpdate = 0.00,
    timeUntilBlink = 0.00,
    blinkFrames = 0,
    isPushable = false,
    isBeingTargeted = false,
    attackPhase = nil,
    attackPhaseFrames = 0,
    timeUntilNextAttackPhase = 0.00,
    attackAngle = 0,
    targetX = nil,
    targetY = nil,
    init = function(self)
      self.bodyFlipped = math.random() < 0.5
      self.bodySprite = math.random(1, 12)
      self.eyeOffsetX = (self.bodyFlipped and -1 or 1) * BADDIE_SPRITES[self.bodySprite].x
      self.eyeOffsetY = -BADDIE_SPRITES[self.bodySprite].y
    end,
    update = function(self, dt)
      -- Advance attack stages
      if self.attackPhase then
        self.attackPhaseFrames = self.attackPhaseFrames + 1
        self.timeUntilNextAttackPhase = self.timeUntilNextAttackPhase - dt
        if self.timeUntilNextAttackPhase <= 0.00 then
          self.attackPhaseFrames = 0
          if self.attackPhase == 'aiming' then
            self.attackPhase = 'charging'
            self.timeUntilNextAttackPhase = 0.25
          elseif self.attackPhase == 'charging' then
            self.attackPhase = 'shooting'
            self.timeUntilNextAttackPhase = 2.00
          elseif self.attackPhase == 'shooting' then
            self.attackPhase = 'cooldown'
            self.timeUntilNextAttackPhase = 0.10
          elseif self.attackPhase == 'cooldown' then
            self.attackPhase = 'pausing'
            self.timeUntilNextAttackPhase = 0.75
          elseif self.attackPhase == 'pausing' then
            self.attackPhase = nil
          end
        end
      end
      -- Figure out which player is closest, giving priority to players staring at the baddie
      local closestPlayer = self:getClosestPlayer()
      self.isBeingTargeted = (closestPlayer.target == self)
      -- Jitter eye (especially while targeted)
      local eyeWhiteJitterMult
      local pupilJitterMult
      if self.isBeingTargeted then
        eyeWhiteJitterMult = 1.0
        pupilJitterMult = 1.0
      elseif self.attackPhase then
        eyeWhiteJitterMult = 0.25
        pupilJitterMult = 0.25
      else
        eyeWhiteJitterMult = 0.0
        pupilJitterMult = 0.3
      end
      local eyeWhiteJitterX = eyeWhiteJitterMult * (0.5 * math.random() - 0.25)
      local eyeWhiteJitterY = eyeWhiteJitterMult * (0.5 * math.random() - 0.25)
      local pupilJitterX = pupilJitterMult * (1.5 * math.random() - 0.75)
      local pupilJitterY = pupilJitterMult * (1.5 * math.random() - 0.75)
      -- Update eye
      if self.attackPhase then
        -- Update eye position
        if self.attackPhase == 'aiming' then
          self:setEyeWhiteAngle(self.attackAngle, 0.5)
          self:setPupilAngle(self.attackAngle, 0.5)
        elseif self.attackPhase == 'charging' then
          self:setEyeWhiteAngle(self.attackAngle, 0.3)
          self:setPupilAngle(self.attackAngle, 0.5)
        elseif self.attackPhase == 'shooting' then
          self:setEyeWhiteAngle(self.attackAngle, 0.9)
          self:setPupilAngle(self.attackAngle, 0.7)
        elseif self.attackPhase == 'cooldown' then
          self:setEyeWhiteAngle(self.attackAngle, 0.7)
          self:setPupilAngle(self.attackAngle, 0.6)
        elseif self.attackPhase == 'pausing' then
          self:setEyeWhiteAngle(self.attackAngle, 0.4)
          self:setPupilAngle(self.attackAngle, 0.4)
        end
        self.eyeWhiteOffsetX = self.eyeWhiteOffsetX + eyeWhiteJitterX
        self.eyeWhiteOffsetY = self.eyeWhiteOffsetY + eyeWhiteJitterY
        self.pupilOffsetX = self.pupilOffsetX + pupilJitterX
        self.pupilOffsetY = self.pupilOffsetY + pupilJitterY
        self:calculateTarget()
      else
        local eyeX, eyeY = self:getEyePosition()
        local playerEyeX, playerEyeY = closestPlayer:getEyePosition()
        local dx = playerEyeX - eyeX
        local dy = playerEyeY - eyeY
        local dist = math.sqrt(dx * dx + dy * dy)
        local angle = math.atan2(dy, dx)
        local distMult = math.min(1.0, 0.35 + dist / 200)
        -- Update eye white offset
        self.timeUntilEyeWhiteUpdate = self.timeUntilEyeWhiteUpdate - dt
        if self.timeUntilEyeWhiteUpdate <= 0.00 or self.isBeingTargeted then
          self.timeUntilEyeWhiteUpdate = 0.3 + 0.2 * math.random()
          self:setEyeWhiteAngle(angle, distMult)
          self.eyeWhiteOffsetX = self.eyeWhiteOffsetX + eyeWhiteJitterX
          self.eyeWhiteOffsetY = self.eyeWhiteOffsetY + eyeWhiteJitterY
        end
        -- Update pupil offset
        self.timeUntilPupilUpdate = self.timeUntilPupilUpdate - dt
        if self.timeUntilPupilUpdate <= 0.00 or self.isBeingTargeted then
          self.timeUntilPupilUpdate = 0.1 + 0.2 * math.random()
          self:setPupilAngle(angle, distMult)
          self.pupilOffsetX = self.pupilOffsetX + pupilJitterX
          self.pupilOffsetY = self.pupilOffsetY + pupilJitterY
        end
        -- Blink every so often
        self.blinkFrames = self.blinkFrames - 1
        self.timeUntilBlink = self.timeUntilBlink - dt
        if self.timeUntilBlink <= 0.00 then
          self.timeUntilBlink = 2.00 + 5.00 * math.random()
          self.blinkFrames = 11
        end
      end
    end,
    draw = function(self, renderLayer)
      if renderLayer == 1 then
        if not self.seat.isSeated then
          -- Draw shadow
          local shadowSprite = 5
          drawSprite(100 + 20 * (shadowSprite - 1), 185, 19, 7, self.x - 9.5, self.y - 2)
        end
      elseif renderLayer == 3 then
        -- Draw body
        drawSprite(24 * (self.bodySprite - 1) + 1, 193, 23, 36, self.x - 11.5, self.y - 28, self.bodyFlipped)
        if DEBUG_MODE then
          love.graphics.setColor(COLOR.DEBUG_BLUE)
          love.graphics.circle('line', self.x, self.y, self.radius)
        end
      elseif renderLayer == 4 then
        local pupilX, pupilY = self:getPupilPosition()
        local eyeWhiteX, eyeWhiteY = self:getEyeWhitePosition()
        -- Draw eye white
        local eyeFrame = 3
        if self.attackPhase == 'charging' then
          eyeFrame = 4
        elseif self.attackPhase == 'shooting' then
          eyeFrame = 2
        elseif self.blinkFrames > 0 then
          -- local b = math.abs(math.ceil(self.blinkFrames / 2) - 3) -- 2 to 0 to 2
          eyeFrame = 6 - math.abs(math.ceil(self.blinkFrames / 2) - 3)
        end
        drawSprite(11 * (eyeFrame - 1) + 1, 185, 10, 7, eyeWhiteX - 5, eyeWhiteY - 3.5)
        -- Draw pupil
        local pupilColor
        local pupilSize = 1.5
        if self.attackPhase and self.attackPhase ~= 'pausing' then
          pupilColor = COLOR.RED
        else
          pupilColor = COLOR.DARK_GREY
        end
        love.graphics.setColor(pupilColor)
        love.graphics.rectangle('fill', pupilX - pupilSize / 2, pupilY - pupilSize / 2, pupilSize, pupilSize)
        if DEBUG_MODE then
          local eyeX, eyeY = self:getEyePosition()
          love.graphics.setColor(COLOR.DEBUG_GREEN)
          love.graphics.circle('line', eyeX, eyeY, self.eyeRadius)
        end
      elseif renderLayer == 5 then
        -- Draw laser
        local pupilX, pupilY = self:getPupilPosition()
        if self.attackPhase and self.targetX and self.targetY then
          love.graphics.setColor(COLOR.RED)
          if self.attackPhase == 'aiming' then
            drawPixelatedLine(pupilX, pupilY, self.targetX, self.targetY, 1, 4, 4)
          elseif (self.attackPhase == 'charging' and self.attackPhaseFrames % 6 < 2) or self.attackPhase == 'cooldown' then
            drawPixelatedLine(pupilX, pupilY, self.targetX, self.targetY, 1)
          elseif self.attackPhase == 'shooting' then
            drawPixelatedLine(pupilX, pupilY, self.targetX, self.targetY, 2)
          end
        end
      end
    end,
    getEyePosition = function(self)
      local x, y = self.x, self.y
      return x + self.eyeOffsetX, y + self.eyeOffsetY
    end,
    getEyeWhitePosition = function(self)
      local x, y = self:getEyePosition()
      return x + self.eyeWhiteOffsetX, y + self.eyeWhiteOffsetY
    end,
    getPupilPosition = function(self)
      local x, y = self:getEyeWhitePosition()
      return x + self.pupilOffsetX, y + self.pupilOffsetY
    end,
    getClosestPlayer = function(self)
      local closestPlayer
      local closestPlayerSquareDist
      local closestPlayerIsTargeting = false
      for _, player in ipairs(players) do
        local dx = player.x - self.x
        local dy = player.y - self.y
        local squareDist = dx * dx + dy * dy
        if (not closestPlayer or squareDist < closestPlayerSquareDist or (not closestPlayerIsTargeting and player.target == self)) and (not closestPlayerIsTargeting or player.target == self) then
          closestPlayer = player
          closestPlayerSquareDist = squareDist
          closestPlayerIsTargeting = (player.target == self)
        end
      end
      return closestPlayer
    end,
    attack = function(self, angleOrX, y)
      self.timeUntilBlink = 0.00
      self.blinkFrames = 0
      self.attackPhase = 'aiming'
      self.attackPhaseFrames = 0
      self.timeUntilNextAttackPhase = 1.00
      local pupilX, pupilY = self:getPupilPosition()
      if angleOrX and y then
        local dx = angleOrX - pupilX
        local dy = y - pupilY
        self.attackAngle = math.atan2(dy, dx)
      elseif angleOrX and not y then
        self.attackAngle = angleOrX
      else
        local target = self:getClosestPlayer()
        local dx = target.x - pupilX
        local dy = target.y - pupilY
        self.attackAngle = math.atan2(dy, dx)
      end
      self:calculateTarget()
    end,
    setEyeWhiteAngle = function(self, angle, distMult)
      self.eyeWhiteOffsetX = 2.0 * distMult * math.cos(angle)
      self.eyeWhiteOffsetY = 2.0 * distMult * math.sin(angle)
    end,
    setPupilAngle = function(self, angle, distMult)
      local angleMult = ((2 * angle / math.pi) + 1) % 2
      if angleMult > 1 then
        angleMult = 2 - angleMult
      end
      angleMult = math.max(0.2, angleMult)
      self.pupilOffsetX = 3.0 * (0.5 + 0.5 * angleMult) * distMult * math.cos(angle)
      self.pupilOffsetY = 3.0 * (0.5 + 0.5 * angleMult) * distMult * math.sin(angle)
    end,
    calculateTarget = function(self)
      local pupilX, pupilY = self:getPupilPosition()
      local aimX = math.cos(self.attackAngle)
      local aimY = math.sin(self.attackAngle)
      -- Figure out where the laser ends
      self.targetX = pupilX + 999 * aimX
      self.targetY = pupilY + 999 * aimY
      -- Keep target in bounds
      if self.targetX < -LASER_MARGIN.SIDE then
        self.targetX = -LASER_MARGIN.SIDE
        self.targetY = pupilY + aimY / aimX * (-LASER_MARGIN.SIDE - pupilX)
      end
      if self.targetX > GAME_WIDTH + LASER_MARGIN.SIDE then
        self.targetX = GAME_WIDTH + LASER_MARGIN.SIDE
        self.targetY = pupilY + aimY / aimX * (GAME_WIDTH + LASER_MARGIN.SIDE - pupilX)
      end
      if self.targetY < -LASER_MARGIN.TOP then
        self.targetX = pupilX + aimX / aimY * (-LASER_MARGIN.TOP - pupilY)
        self.targetY = -LASER_MARGIN.TOP
      end
      if self.targetY > GAME_HEIGHT + LASER_MARGIN.BOTTOM then
        self.targetX = pupilX + aimX / aimY * (GAME_HEIGHT + LASER_MARGIN.BOTTOM - pupilY)
        self.targetY = GAME_HEIGHT + LASER_MARGIN.BOTTOM
      end
    end
  }
}

function love.load()
  levelNumber = 3
  levelPhase = 'doors-opening'
  levelFrame = 0
  -- Set default filter to nearest to allow crisp pixel art
  love.graphics.setDefaultFilter('nearest', 'nearest')
  -- Load assets
  spriteSheet = love.graphics.newImage('img/sprite-sheet.png')
  -- Create controllers
  blankController = Controllers.BlankController:new()
  mouseAndKeyboardController = Controllers.MouseAndKeyboardController:new()
  joystickControllers = {}
  playerControllers = { mouseAndKeyboardController, nil }
  -- Spawn entities
  entities = {}
  newEntities = {}
  spawnEntity('player', {
    playerNum = 1,
    color = COLOR.PURPLE,
    x = GAME_WIDTH / 2 - 25,
    y = GAME_HEIGHT / 2
  })
  spawnEntity('player', {
    playerNum = 2,
    color = COLOR.GREEN,
    x = GAME_WIDTH / 2 + 25,
    y = GAME_HEIGHT / 2
  })
  addNewEntitiesToGame()
end

function love.update(dt)
  -- Update level phase
  levelFrame = levelFrame + 1
  if levelPhase == 'doors-opening' and levelFrame > 60 then
    levelPhase = 'passengers-boarding'
    levelFrame = 0
    numPassengersLeftToBoard = 10
    for _, seat in ipairs(SEATS) do
      seat.passenger = nil
    end
  elseif levelPhase == 'passengers-boarding' and numPassengersLeftToBoard <= 0 then
    levelPhase = 'doors-closing'
    levelFrame = 0
  elseif levelPhase == 'doors-closing' and levelFrame > 60 then
    levelNumber = levelNumber + 1
    levelPhase = 'traveling'
    levelFrame = 0
  end
  -- Spawn passengers
  if levelPhase == 'passengers-boarding' and levelFrame % 10 == 0 and numPassengersLeftToBoard > 0 then
    -- Select a random seat
    local maxPriority = 1
    for attempt = 1, 100 do
      maxPriority = maxPriority + 0.3
      local seatNum = math.random(1, #SEATS)
      local seat = SEATS[seatNum]
      local priority = seat.priority
      if seatNum > 1 and SEATS[seatNum - 1].passenger then
        priority = priority + 2
      end
      if seatNum < #SEATS and SEATS[seatNum + 1].passenger then
        priority = priority + 2
      end
      if not seat.passenger and priority <= maxPriority then
        -- Spawn a passenger in that seat
        numPassengersLeftToBoard = numPassengersLeftToBoard - 1
        seat.passenger = spawnEntity('baddie', {
          x = seat.x,
          y = seat.y,
          seat = seat
        })
        break
      end
    end
  end
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
  -- Update controllers
  mouseAndKeyboardController:update(dt)
  for i = #joystickControllers, 1, -1 do
    local controller = joystickControllers[i]
    if not controller:isActive() then
      table.remove(joystickControllers, i)
    else
      controller:update(dt)
    end
  end
  -- Try switching controllers after controller disconnects
  if playerControllers[1] and not playerControllers[1]:isActive() then
    if playerControllers[2] == mouseAndKeyboardController then
      playerControllers[2] = nil
    end
    playerControllers[1] = mouseAndKeyboardController
  end
  if playerControllers[2] and not playerControllers[2]:isActive() then
    if playerControllers[1] == mouseAndKeyboardController then
      playerControllers[2] = nil
    else
      playerControllers[2] = mouseAndKeyboardController
    end
  end
end

function love.draw()
  local isAtStop = (levelPhase == 'doors-opening' or levelPhase == 'passengers-boarding' or levelPhase == 'doors-closing')
  local playerMissingHealth = (players[1].health < 90 or players[2].health < 90)
  local shouldDrawHealthBars = playerMissingHealth and (isAtStop or levelFrame % 280 > 140)
  -- Clear the screen
  love.graphics.clear(COLOR.WHITE)
  -- Draw the background
  drawSprite(1, 1, 300, 183, 0, 9)
  -- Draw player health
  if shouldDrawHealthBars then
    drawSprite(196, 379, 90, 11, 106, 12)
    love.graphics.setColor(players[1].color)
    love.graphics.rectangle('fill', 117, 17, math.ceil(30 * players[1].health / 100), 5)
    love.graphics.setColor(players[2].color)
    love.graphics.rectangle('fill', 165, 17, math.ceil(30 * players[2].health / 100), 5)
  -- Draw stop display
  else
    love.graphics.setColor(COLOR.LIGHT_GREY)
    love.graphics.rectangle('fill', 116, 20, 71, 1)
    love.graphics.setColor(COLOR.PURE_WHITE)
    for i = 1, 8 do
      local x = 103 + 10 * i
      local y = 17
      local stopFrame
      if i < levelNumber then
        stopFrame = 3
      elseif i > levelNumber then
        stopFrame = 1
      else
        stopFrame = 2
      end
      drawSprite(240 + 8 * (stopFrame - 1), 185, 7, 7, x, y)
      if i == levelNumber and (not isAtStop or levelFrame % 60 < 40) then
        drawSprite(isAtStop and 286 or 264, 185, 21, 7, x - 7, y - 7)
      end
    end
  end
  -- Draw doors
  local doorSprite
  if levelPhase == 'doors-opening' then
    doorSprite = math.min(math.max(1, math.ceil(levelFrame / 7)), 5)
  elseif levelPhase == 'passengers-boarding' then
    doorSprite = 5
  elseif levelPhase == 'doors-closing' then
    doorSprite = math.min(math.max(0, 6 - math.ceil(levelFrame / 7)), 5)
  else
    doorSprite = 0
  end
  if doorSprite > 0 then
    love.graphics.setColor(COLOR.PURE_WHITE)
    local sx = 1 + 39 * (doorSprite - 1)
    drawSprite(sx, 379, 38, 33, 60, 32)
    drawSprite(sx, 379, 38, 33, 202, 32, true)
    -- drawSprite(sx, 413, 38, 19, 60, 168)
    -- drawSprite(sx, 413, 38, 19, 202, 168, true)
  end
  -- Draw the game state
  love.graphics.push()
  love.graphics.translate(GAME_X, GAME_Y)
  if DEBUG_MODE then
    love.graphics.setColor(COLOR.DEBUG_BLUE)
    love.graphics.rectangle('line', 0, 0, GAME_WIDTH, GAME_HEIGHT)
  end
  -- Draw entities
  for renderLayer = 1, 6 do
    for _, entity in ipairs(entities) do
      if not entity.renderLayer or entity.renderLayer == renderLayer then
        love.graphics.setColor(COLOR.PURE_WHITE)
        entity:draw(renderLayer)
      end
    end
  end
  love.graphics.pop()
end

-- Assign controllers as they're added
function love.joystickadded(joystick)
  local controller = Controllers.JoystickController:new(joystick)
  table.insert(joystickControllers, controller)
  if not playerControllers[1] or playerControllers[1] == mouseAndKeyboardController then
    playerControllers[1] = controller
    playerControllers[2] = mouseAndKeyboardController
  elseif not playerControllers[2] or playerControllers[2] == mouseAndKeyboardController then
    playerControllers[2] = controller
  end
end

-- Pass input callbacks to the controllers
function love.joystickpressed(...)
  for _, controller in ipairs(joystickControllers) do
    controller:joystickpressed(...)
  end
end
function love.mousepressed(...)
  mouseAndKeyboardController:mousepressed(...)
end
function love.keypressed(...)
  mouseAndKeyboardController:keypressed(...)
end

-- Spawns a new game entity
function spawnEntity(className, params)
  -- Create a default entity
  local entity = {
    type = className,
    isAlive = true,
    framesAlive = 0,
    timeAlive = 0.00,
    radius = 5,
    x = 0,
    y = 0,
    vx = 0,
    vy = 0,
    isPushable = true,
    init = function(self) end,
    update = function(self, dt)
      self:applyVelocity(dt)
    end,
    applyVelocity = function(self, dt)
      self.x = self.x + self.vx * dt
      self.y = self.y + self.vy * dt
    end,
    draw = function(self, renderLayer)
      love.graphics.setColor(COLOR.LIGHT_GREY)
      love.graphics.circle('fill', self.x, self.y, self.radius)
    end,
    addToGame = function(self)
      table.insert(entities, self)
      if self.groups then
        for _, group in ipairs(self.groups) do
          table.insert(group, self)
        end
      end
    end,
    removeFromGame = function(self)
      for i = 1, #entities do
        if entities[i] == self then
          table.remove(entities, i)
          break
        end
      end
      if self.groups then
        for _, group in ipairs(self.groups) do
          for i = 1, #group do
            if group[i] == self then
              table.remove(group, i)
              break
            end
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
    if entity1.isPushable and not entity2.isPushable then
      entity1.x = entity1.x - pushAmount * dx / dist
      entity1.y = entity1.y - pushAmount * dy / dist
    elseif entity2.isPushable and not entity1.isPushable then
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

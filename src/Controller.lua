local INPUT_BUFFER_FRAMES = 4

local BlankController = {}
function BlankController:new()
  return {
    type = 'blank-controller',
    getMoveDirection = function(self)
      return 0.0, 0.0, 0.0
    end,
    getAimDirection = function(self, offsetX, offsetY)
      return 0.0, 0.0, 0.0
    end,
    justStartedDashing = function(self)
      return false
    end,
    isDashing = function(self)
      return false
    end,
    isAiming = function(self)
      return false
    end,
    isActive = function(self)
      return true
    end
  }
end

local MouseAndKeyboardController = {}
function MouseAndKeyboardController:new()
  return {
    type = 'mouse-and-keyboard-controller',
    _framesSinceDash = 0,
    update = function(self, dt)
      self._framesSinceDash = math.max(0, self._framesSinceDash - 1)
    end,
    keypressed = function(self, btn)
      if btn == 'lshift' or btn == 'rshift' then
        self._framesSinceDash = INPUT_BUFFER_FRAMES
      end
    end,
    mousepressed = function(self, x, y, btn) end,
    getMoveDirection = function(self)
      local isPressingUp = love.keyboard.isDown('up') or love.keyboard.isDown('w')
      local isPressingLeft = love.keyboard.isDown('left') or love.keyboard.isDown('a')
      local isPressingDown = love.keyboard.isDown('down') or love.keyboard.isDown('s')
      local isPressingRight = love.keyboard.isDown('right') or love.keyboard.isDown('d')
      local dirX = (isPressingRight and 1.0 or 0.0) - (isPressingLeft and 1.0 or 0.0)
      local dirY = (isPressingDown and 1.0 or 0.0) - (isPressingUp and 1.0 or 0.0)
      if dirX == 0.0 and dirY == 0.0 then
        return 0.0, 0.0, 0.0
      elseif dirX == 0.0 or dirY == 0.0 then
        return dirX, dirY, 1.0
      else
        return 0.707 * dirX, 0.707 * dirY, 1.0
      end
    end,
    getAimDirection = function(self, offsetX, offsetY)
      local mouseX, mouseY = love.mouse.getPosition()
      if not mouseX or not mouseY then
        return 0.0, 0.0, 0.0
      else
        mouseX = mouseX - (offsetX or 0)
        mouseY = mouseY - (offsetY or 0)
        local dist = math.sqrt(mouseX * mouseX + mouseY * mouseY)
        if dist <= 0.0 then
          return 0.0, 0.0, 0.0
        else
          return mouseX / dist, mouseY / dist, 1.00
        end
      end
    end,
    justStartedDashing = function(self)
      return self._framesSinceDash > 0
    end,
    isDashing = function(self)
      return love.keyboard.isDown('lshift') or love.keyboard.isDown('rshift')
    end,
    isAiming = function(self)
      return love.mouse.isDown(1)
    end,
    isActive = function(self)
      return true
    end
  }
end

local JoystickController = {}
function JoystickController:new(joystick)
  return {
    type = 'joystick-controller',
    _joystick = joystick,
    _framesSinceDash = 0,
    update = function(self, dt)
      self._framesSinceDash = math.max(0, self._framesSinceDash - 1)
    end,
    joystickpressed = function(self, joystick, btn)
      if joystick == self._joystick then
        if btn == 5 or btn == 7 then
          self._framesSinceDash = INPUT_BUFFER_FRAMES
        end
      end
    end,
    getMoveDirection = function(self)
      local dirX = self._joystick:getAxis(1)
      local dirY = self._joystick:getAxis(2)
      if not dirX or not dirY then
        return 0.0, 0.0, 0.0
      else
        local squareDist = dirX * dirX + dirY * dirY
        if squareDist <= 0 then
          return 0.0, 0.0, 0.0
        else
          local dist = math.sqrt(squareDist)
          local mag
          if dist < 0.25 then
            mag = 0.0
          elseif dist < 0.65 then
            mag = 0.5
          else
            mag = 1.0
          end
          return dirX / dist, dirY / dist, mag
        end
      end
    end,
    getAimDirection = function(self, offsetX, offsetY)
      local dirX = joystick:getAxis(3)
      local dirY = joystick:getAxis(6)
      if not dirX or not dirY then
        return 0.0, 0.0, 0.0
      else
        local squareDist = dirX * dirX + dirY * dirY
        if squareDist <= 0 then
          return 0.0, 0.0, 0.0
        else
          local dist = math.sqrt(squareDist)
          local mag
          if dist < 0.25 then
            mag = 0.0
          else
            mag = 1.0
          end
          return dirX / dist, dirY / dist, mag
        end
      end
    end,
    justStartedDashing = function(self)
      return self._framesSinceDash > 0
    end,
    isDashing = function(self)
      return self._joystick:isDown(5) or self._joystick:isDown(7)
    end,
    isAiming = function(self)
      local aimX, aimY, aimMult = self:getAimDirection()
      return aimMult > 0.0
    end,
    isActive = function(self)
      return self._joystick:isConnected()
    end
  }
end

return {
  BlankController = BlankController,
  MouseAndKeyboardController = MouseAndKeyboardController,
  JoystickController = JoystickController
}

local config = {
  title = 'NIGHTSHIFT',
  mph = false,
  scale = 1,
  rightMargin = 24,
  bottomMargin = 26,
  fallbackLimiter = 8000,
}

local ink = rgbm(0.03, 0.045, 0.07, 0.93)
local panel = rgbm(0.08, 0.12, 0.18, 0.97)
local dim = rgbm(0.21, 0.29, 0.39, 1)
local muted = rgbm(0.64, 0.73, 0.83, 1)
local white = rgbm(0.95, 0.98, 1, 1)
local cyan = rgbm(0.24, 0.95, 1, 1)
local pink = rgbm(1, 0.28, 0.52, 1)
local pinkDark = rgbm(0.40, 0.16, 0.27, 1)
local face = ui.DWriteFont('Segoe UI'):weight(ui.DWriteFont.Weight.Bold)
local digits = ui.DWriteFont('Consolas'):weight(ui.DWriteFont.Weight.Bold)
local width, height = 252, 198
local scale = 1

local function point(x, y)
  return vec2(x * scale, y * scale)
end

local function box(x, y, w, h, color, rounding)
  ui.drawRectFilled(point(x, y), point(x + w, y + h), color, rounding * scale)
end

local function label(value, x, y, size, color)
  ui.dwriteDrawText(value, size * scale, point(x, y), color)
end

local function meter(x, y, value, color)
  box(x, y, 95, 4, dim, 2)
  local fill = math.max(0, math.min(value, 1))
  if fill > 0 then box(x, y, 95 * fill, 4, color, 2) end
end

local tach = {}
for i = 0, 39 do
  local angle = math.rad(160 + i / 39 * 220)
  local x, y = math.cos(angle), math.sin(angle)
  tach[i + 1] = { 126 + x * 106, 144 + y * 106, 126 + x * 96, 144 + y * 96 }
end

local function drawHud(player)
  local units = config.mph and 'MPH' or 'KM/H'
  local factor = config.mph and 0.621371 or 1
  local limitKnown = player.rpmLimiter > 500
  local limit = limitKnown and player.rpmLimiter or config.fallbackLimiter
  local fill = math.max(0, math.min(player.rpm / limit, 1))
  local shift = limitKnown and player.rpm >= limit * 0.94 and player.gear > 0
  local gear = player.gear < 0 and 'R' or player.gear == 0 and 'N' or tostring(player.gear)
  local speed = string.format('%03d', math.floor(math.abs(player.speedKmh) * factor + 0.5))

  ui.pushDWriteFont(face)
  box(0, 0, width, height, ink, 12)
  box(8, 8, width - 16, 24, panel, 5)
  box(16, 14, 4, 12, cyan, 1)
  label(config.title, 28, 11, 14, white)

  for i, tick in ipairs(tach) do
    local hot = i > 34
    local lit = i <= math.floor(fill * #tach + 0.5)
    local color = lit and (hot and pink or cyan) or (hot and pinkDark or dim)
    ui.drawLine(point(tick[1], tick[2]), point(tick[3], tick[4]), color, 3 * scale)
  end

  ui.pushDWriteFont(digits)
  label(speed, 61, 73, #speed > 3 and 42 or 51, white)
  box(157, 85, 44, 38, shift and pinkDark or panel, 5)
  label(gear, #gear > 1 and 166 or 171, 88, #gear > 1 and 19 or 26, shift and pink or white)
  ui.popDWriteFont()
  label(units, 64, 124, 13, muted)
  label(shift and 'SHIFT UP' or string.format('%d RPM', math.floor(player.rpm + 0.5)),
    157, 127, 12, shift and pink or muted)

  label('THROTTLE', 24, 155, 11, muted)
  label('BRAKE', 133, 155, 11, muted)
  meter(24, 171, player.gas, cyan)
  meter(133, 171, player.brake, pink)
  if player.turboBoost > 0.01 then
    label(string.format('BOOST %.2f', player.turboBoost), 24, 180, 11, cyan)
  end
  ui.popDWriteFont()
end

function script.drawUI()
  local player, sim = ac.getCar(0), ac.getSim()
  if not player or sim.isInMainMenu or sim.isReplayActive or sim.isPaused
    or (sim.focusedCar >= 0 and sim.focusedCar ~= 0) then return end

  local screen = ac.getUI().windowSize
  scale = math.min(config.scale, screen.x / (width + config.rightMargin * 2),
    screen.y / (height + config.bottomMargin * 2))
  if scale <= 0 then return end

  ui.transparentWindow('nightshift.instrument.hud',
    vec2(screen.x - (width + config.rightMargin) * scale,
      screen.y - (height + config.bottomMargin) * scale),
    point(width, height), true, false, function() drawHud(player) end)
end

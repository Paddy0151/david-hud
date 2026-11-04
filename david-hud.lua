-- david-hud.lua | NO LICENSE | Assetto Corsa CSP online dashboard
local defaults = {
  scale = 100, right = 24, bottom = 26, mph = false, dashboard = true,
  assists = true, shiftLights = true, details = false, alerts = true, theme = 1,
}
local settings = ac.storage(defaults, 'no_license.dashboard.v2.')
local width, height = 444, 190
local rpm, speed, seeded = 0, 0, false
local menuOpen, page = false, 1
local pages = { 'Display', 'Telemetry', 'Status' }
local scale = 1

local black = rgbm(0.038, 0.032, 0.047, 0.94)
local panel = rgbm(0.069, 0.061, 0.081, 0.97)
local track = rgbm(0.16, 0.14, 0.18, 1)
local stroke = rgbm(0.24, 0.21, 0.28, 1)
local dot = rgbm(0.16, 0.12, 0.22, 0.44)
local white = rgbm(0.97, 0.96, 1, 1)
local muted = rgbm(0.69, 0.66, 0.74, 1)
local violet = rgbm(0.68, 0.32, 1, 1)
local lilac = rgbm(0.78, 0.61, 1, 1)
local amber = rgbm(1, 0.71, 0.34, 1)
local red = rgbm(1, 0.28, 0.43, 1)
local green = rgbm(0.47, 0.91, 0.37, 1)
local themes = {
  { name = 'Violet', primary = violet, light = lilac },
  { name = 'Ice', primary = rgbm(0.30, 0.77, 1, 1), light = rgbm(0.63, 0.88, 1, 1) },
  { name = 'Amber', primary = amber, light = rgbm(1, 0.85, 0.56, 1) },
}
local font = ui.DWriteFont('Segoe UI'):weight(ui.DWriteFont.Weight.Bold)

local function saturate(value)
  return math.max(0, math.min(1, value))
end

local function point(x, y)
  return vec2(x * scale, y * scale)
end

local function box(x, y, w, h, color, radius)
  ui.drawRectFilled(point(x, y), point(x + w, y + h), color, radius * scale)
end

local function circle(x, y, r, color)
  ui.drawCircleFilled(point(x, y), r * scale, color, 12)
end

local function label(text, x, y, size, color)
  ui.dwriteDrawText(text, size * scale, point(x, y), color)
end

local function centered(text, x, y, w, h, size, color)
  ui.dwriteDrawTextClipped(text, size * scale, point(x, y), point(x + w, y + h),
    ui.Alignment.Center, ui.Alignment.Center, false, color)
end

local function arc(cx, cy, radius, startAngle, endAngle, fraction, color, thickness)
  if fraction <= 0 then return end
  local segments = math.max(2, math.ceil(48 * fraction))
  for i = 0, segments do
    local angle = math.rad(startAngle + (endAngle - startAngle) * fraction * i / segments)
    ui.pathLineTo(point(cx + radius * math.cos(angle), cy + radius * math.sin(angle)))
  end
  ui.pathStroke(color, false, thickness * scale)
end

local function meter(x, y, fraction, color)
  box(x, y, 79, 3, track, 1)
  if fraction > 0 then box(x, y, 79 * saturate(fraction), 3, color, 1) end
end

local function drawCluster(car)
  local mph = settings.mph
  local factor = mph and 0.621371 or 1
  local knownLimit = car.rpmLimiter > 500
  local limiter = knownLimit and car.rpmLimiter or 8000
  local rev = saturate(rpm / limiter)
  local shift = knownLimit and car.gear > 0 and car.rpm / limiter >= 0.94
  local gear = car.gear < 0 and 'R' or car.gear == 0 and 'N' or tostring(car.gear)
  local shownSpeed = tostring(math.floor(speed * factor + 0.5))

  ui.pushDWriteFont(font)
  box(2, 8, 440, 140, black, 69)
  ui.drawRect(point(2, 8), point(442, 148), stroke, 69 * scale, nil, scale)
  for y = 20, 136, 7 do
    for x = 14, 305, 7 do
      local dx = math.max(72 - x, 0)
      if dx * dx + (y - 78) * (y - 78) < 62 * 62 then circle(x, y, 0.85, dot) end
    end
  end

  arc(73, 79, 53, 132, 270, 1, track, 7)
  ui.drawLine(point(73, 26), point(302, 26), track, 7 * scale)
  local arcShare = 0.36
  local revColor = shift and red or violet
  arc(73, 79, 53, 132, 270, saturate(rev / arcShare), revColor, 7)
  if rev > arcShare then
    ui.drawLine(point(73, 26), point(73 + 229 * (rev - arcShare) / (1 - arcShare), 26),
      revColor, 7 * scale)
  end

  centered(gear, 27, 43, 94, 73, #gear > 1 and 42 or 61, shift and red or white)
  if settings.shiftLights then
    for i = 1, 9 do
      local lit = rev >= 0.55 + (i - 1) * 0.05
      circle(145 + (i - 1) * 14, 48, 3.3, lit and (i >= 8 and red or lilac) or track)
    end
  end
  centered(shift and 'SHIFT UP' or 'RPM', 131, 61, 140, 19, 12, shift and red or muted)
  centered(tostring(math.floor(rpm + 0.5)), 131, 79, 140, 34, 29, white)
  centered('NO LICENSE', 131, 114, 140, 15, 10, lilac)

  local speedFill = saturate(speed / 360)
  arc(369, 79, 49, 122, 418, 1, track, 7)
  arc(369, 79, 49, 122, 418, speedFill, violet, 7)
  centered(mph and 'MPH' or 'KM/H', 324, 51, 90, 20, 13, muted)
  centered(shownSpeed, 316, 71, 106, 42, #shownSpeed > 3 and 25 or 35, white)

  if settings.assists or settings.details then
    box(75, 145, 294, 32, panel, 15)
    if settings.assists then
      local abs = car.physicsAvailable and car.absInAction
      local tc = car.physicsAvailable and car.tractionControlInAction
      label('ABS', 91, 154, 12, abs and amber or muted)
      circle(122, 161, 3.1, abs and amber or track)
      label('TC', 138, 154, 12, tc and violet or muted)
      circle(159, 161, 3.1, tc and violet or track)
    end
    if settings.details then
      local detail = string.format('FUEL %.1f L', math.max(0, car.fuel))
      if car.turboBoost > 0.01 then detail = detail .. string.format('   BOOST %.2f', car.turboBoost) end
      centered(detail, settings.assists and 172 or 83, 148, settings.assists and 186 or 278, 24, 11, white)
    end
  end
  if settings.details then
    label('THROTTLE', 14, 171, 9, muted)
    meter(14, 184, car.gas, violet)
    label('BRAKE', 351, 171, 9, muted)
    meter(351, 184, car.brake, red)
  end
  ui.popDWriteFont()
end

local function hit(id, x, y, w, h)
  ui.setCursor(vec2(x, y))
  return ui.invisibleButton('##nl_' .. id, vec2(w, h))
end

local function button(id, text, x, y, w, h, active)
  box(x, y, w, h, active and track or panel, 7)
  centered(text, x, y, w, h, 13, active and lilac or white)
  return hit(id, x, y, w, h)
end

local function toggle(key, title, y)
  local enabled = settings[key]
  label(title, 16, y + 7, 14, white)
  box(272, y + 6, 36, 19, enabled and violet or track, 10)
  circle(enabled and 298 or 282, y + 15.5, 6, white)
  if hit(key, 12, y, 300, 31) then settings[key] = not enabled end
end

local function slider(key, title, y, low, high, suffix)
  label(title, 16, y + 5, 13, muted)
  ui.setCursor(vec2(167, y + 2))
  ui.setNextItemWidth(141)
  local value, changed = ui.slider('##nl_' .. key, settings[key], low, high, '%.0f' .. suffix)
  if changed then settings[key] = math.floor(value + 0.5) end
end

local function alertText(car)
  if not settings.alerts then return nil end
  if car.maxFuel > 0 and car.fuel / car.maxFuel < 0.10 then return 'LOW FUEL' end
  if car.isInPitlane then return 'PIT LANE' end
end

local function drawMenu(car, sim, alert)
  box(0, 0, 324, 306, black, 14)
  box(0, 0, 324, 57, panel, 14)
  box(15, 14, 4, 29, violet, 2)
  ui.pushDWriteFont(font)
  label('NO LICENSE', 28, 9, 19, white)
  label('DRIVER DISPLAY', 29, 33, 10, lilac)
  if button('close', 'X', 280, 12, 31, 31, false) then menuOpen = false end

  for i, title in ipairs(pages) do
    if button('tab' .. i, title, 12 + (i - 1) * 101, 66, 98, 32, i == page) then page = i end
  end

  if page == 1 then
    toggle('dashboard', 'Show dashboard', 108)
    toggle('mph', 'Use MPH', 140)
    slider('scale', 'HUD scale', 174, 65, 150, '%%')
    slider('right', 'Right inset', 202, 0, 400, ' px')
    slider('bottom', 'Bottom inset', 230, 0, 300, ' px')
    if button('resetPlacement', 'Reset placement', 12, 266, 145, 28, false) then
      settings.scale, settings.right, settings.bottom = defaults.scale, defaults.right, defaults.bottom
    end
    if button('theme', 'Accent: ' .. (themes[settings.theme] or themes[1]).name, 163, 266, 149, 28, false) then
      settings.theme = settings.theme % #themes + 1
    end
  elseif page == 2 then
    toggle('shiftLights', 'Shift lights', 108)
    toggle('assists', 'ABS and TC indicators', 143)
    toggle('details', 'Fuel, boost and pedal inputs', 178)
    toggle('alerts', 'Pit and low fuel alerts', 213)
    if button('resetAll', 'Restore HUD defaults', 12, 266, 300, 28, false) then
      for key, value in pairs(defaults) do settings[key] = value end
    end
  else
    local connected = sim.isOnlineRace and car.isConnected
    circle(22, 126, 4, connected and green or muted)
    label(connected and 'Connected to server' or 'Offline', 35, 116, 15, white)
    box(12, 147, 300, 51, panel, 7)
    label('VEHICLE STATUS', 24, 153, 10, muted)
    label(alert or (settings.alerts and 'No active alerts' or 'Alerts disabled'), 24, 169, 15, alert and amber or white)
    box(12, 207, 300, 51, panel, 7)
    label('FUEL REMAINING', 24, 214, 10, muted)
    label(car.maxFuel > 0 and string.format('%.1f / %.1f L', car.fuel, car.maxFuel) or 'Unavailable',
      24, 231, 15, white)
    label('NO LICENSE  /  HUD', 16, 274, 11, lilac)
  end
  ui.popDWriteFont()
end

local function drawActionBar(alert)
  box(0, 0, 193, 42, black, 11)
  ui.pushDWriteFont(font)
  if button('status', '!', 4, 4, 36, 34, menuOpen and page == 3) then
    menuOpen, page = not (menuOpen and page == 3), 3
  end
  if alert then circle(32, 12, 3.5, amber) end
  if button('menu', 'NO LICENSE', 45, 4, 144, 34, menuOpen and page ~= 3) then
    menuOpen, page = not (menuOpen and page ~= 3), 1
  end
  ui.popDWriteFont()
end

function script.update(dt)
  local car = ac.getCar(0)
  if not car then return end
  local blend = seeded and 1 - math.exp(-math.max(0, dt) * 18) or 1
  rpm = rpm + (math.max(0, car.rpm) - rpm) * blend
  speed = speed + (math.abs(car.speedKmh) - speed) * blend
  seeded = true
end

function script.drawUI()
  local car, sim = ac.getCar(0), ac.getSim()
  if not car or sim.isInMainMenu or sim.isReplayActive or sim.isPaused
    or (sim.focusedCar >= 0 and sim.focusedCar ~= 0) then return end
  local screen = ac.getUI().windowSize
  if screen.x < 352 or screen.y < 390 then return end
  local theme = themes[settings.theme] or themes[1]
  violet, lilac = theme.primary, theme.light

  if settings.dashboard then
    scale = math.min(settings.scale / 100, (screen.x - 16) / width, (screen.y - 16) / height)
    local x = math.max(8, screen.x - width * scale - settings.right)
    local y = math.max(8, screen.y - height * scale - settings.bottom)
    ui.transparentWindow('no_license.cluster.v2', vec2(x, y), point(width, height),
      true, false, function() drawCluster(car) end)
  end

  scale = 1
  local alert = alertText(car)
  ui.transparentWindow('no_license.action', vec2(screen.x - 217, 24), vec2(193, 42),
    true, true, function() drawActionBar(alert) end)
  if menuOpen then
    ui.transparentWindow('no_license.menu', vec2(screen.x - 348, 74), vec2(324, 306),
      true, true, function() drawMenu(car, sim, alert) end)
  end
end

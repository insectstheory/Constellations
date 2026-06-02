-- Constellations
-- Geometric point System 
-- Insects Theory 2026
--
-- E1: Speed
-- E2: Points
-- E3: Max dixtance trig
-- K2: Regen

local points       = {}
local max_points   = 12
local global_speed = 0.6   -- internal range 0.05 – 3.0
local max_distance = 25
local active_notes   = {}    -- key "i_j" → {note, channel}
local flash_frames   = {}    -- point index → remaining flash frames
local showing_splash = true  -- true while the splash screen is displayed

local midi_out     = nil

local NOTE_NAMES = {"C","C#","D","D#","E","F","F#","G","G#","A","A#","B"}

local SCALES = {
  { name = "chromatic",  intervals = {0,1,2,3,4,5,6,7,8,9,10,11} },
  { name = "major",      intervals = {0,2,4,5,7,9,11} },
  { name = "minor",      intervals = {0,2,3,5,7,8,10} },
  { name = "pentatonic", intervals = {0,2,4,7,9} },
  { name = "blues",      intervals = {0,3,5,6,7,10} },
  { name = "whole tone", intervals = {0,2,4,6,8,10} },
  { name = "phrygian",   intervals = {0,1,3,5,7,8,10} },
  { name = "lydian",     intervals = {0,2,4,6,7,9,11} },
  { name = "dorian",     intervals = {0,2,3,5,7,9,10} },
}

-- -----------------------------------------------------------------
-- Helpers
-- -----------------------------------------------------------------

local function midi_panic()
  for k, data in pairs(active_notes) do
    midi_out:note_off(data.note, 0, data.channel)
  end
  active_notes = {}
end

local function gate_time()
  return util.linlin(0.1, 2.0, 0.5, 0.04, global_speed)
end

local function x_to_note(x)
  local scale  = SCALES[params:get("scale")].intervals
  local root   = params:get("root_note")
  local degree = math.floor(util.linlin(0, 128, 0, #scale * 4, x))
  local octave = math.floor(degree / #scale)
  local step   = degree % #scale + 1
  -- clamp to avoid MIDI notes outside the 0-127 range
  return util.clamp(root + octave * 12 + scale[step], 0, 127)
end

local function y_to_velocity(y)
  return math.floor(util.linlin(0, 64, 110, 35, y))
end

local function dist_to_velocity(dist, v_base)
  local factor = util.linlin(0, max_distance, 1.0, 0.35, dist)
  return math.floor(util.clamp(v_base * factor, 1, 127))
end

local function pair_channel(i, j)
  local ch = params:get("midi_channel")
  if ch == 0 then
    -- multi-channel mode: distribute across channels 1-4
    return ((i + j) % 4) + 1
  else
    return ch
  end
end

-- -----------------------------------------------------------------
-- Points
-- -----------------------------------------------------------------

local function init_point()
  return {
    x  = math.random(2, 126),
    y  = math.random(2, 62),
    dx = (math.random() * 2 - 1),
    dy = (math.random() * 2 - 1),
  }
end

-- -----------------------------------------------------------------
-- Splash screen
-- -----------------------------------------------------------------

local function draw_splash()
  screen.clear()

  -- Connection lines (coordinates scaled to 128x64)
  local function line(x1,y1,x2,y2,lv)
    screen.level(lv)
    screen.move(x1,y1)
    screen.line(x2,y2)
    screen.stroke()
  end

  line(20, 14, 38, 21, 5)
  line(38, 21, 57, 16, 5)
  line(57, 16, 76, 26, 5)
  line(76, 26, 99, 20, 5)
  line(99, 20, 108, 32, 4)
  line(108, 32, 89, 40, 4)
  line(89, 40, 51, 38, 4)
  line(38, 21, 51, 38, 3)
  line(20, 14, 13, 29, 3)
  line(13, 29, 29, 43, 3)
  line(29, 43, 51, 38, 3)
  line(99, 20, 113, 12, 3)
  line(113, 12, 118, 26, 3)
  line(118, 26, 108, 32, 3)

  -- Nodes
  local nodes = {
    {20,14,2},{38,21,2},{57,16,1},{76,26,2},
    {99,20,1},{108,32,2},{89,40,1},{51,38,1},
    {13,29,1},{29,43,1},{113,12,1},{118,26,1},
  }
  for _, n in ipairs(nodes) do
    screen.level(15)
    screen.circle(n[1], n[2], n[3])
    screen.fill()
  end

  -- Trigger ring on the central node
  screen.level(8)
  screen.circle(76, 26, 4)
  screen.stroke()

  -- Script name
  screen.level(15)
  screen.font_face(1)
  screen.font_size(8)
  screen.move(64, 52)
  screen.text_center("Constellations")

  screen.update()
end

-- -----------------------------------------------------------------
-- Init
-- -----------------------------------------------------------------

function init()
  params:add_separator("MIDI")

  params:add {
    type    = "number",
    id      = "midi_device",
    name    = "MIDI device",
    min     = 1, max = 4, default = 1,
    action  = function(v)
      midi_panic()
      midi_out = midi.connect(v)
    end
  }

  params:add {
    type    = "number",
    id      = "midi_channel",
    name    = "MIDI channel (0=multi)",
    min     = 0, max = 16, default = 0,
    action  = function() midi_panic() end
  }

  params:add_separator("SCALE")

  params:add {
    type    = "option",
    id      = "scale",
    name    = "scale",
    options = (function()
      local t = {}
      for _, s in ipairs(SCALES) do t[#t+1] = s.name end
      return t
    end)(),
    default = 2,
    action  = function() midi_panic() end
  }

  params:add {
    type    = "number",
    id      = "root_note",
    name    = "root note",
    min     = 24, max = 72, default = 48,
    formatter = function(param)
      local v = param:get()
      local name = NOTE_NAMES[(v % 12) + 1]
      local oct  = math.floor(v / 12) - 1
      return name .. oct
    end,
    action  = function() midi_panic() end
  }

  params:add_separator("VISUAL")

  params:add {
    type    = "option",
    id      = "node_flash",
    name    = "node flash on trigger",
    options = {"off", "on"},
    default = 1   -- off by default
  }

  midi_out = midi.connect(params:get("midi_device"))

  screen.aa(0)

  -- Show splash for 2.5 seconds, then start the sequencer
  draw_splash()
  clock.run(function()
    clock.sleep(2.5)
    showing_splash = false
  end)

  for i = 1, max_points do
    table.insert(points, init_point())
  end

  local m = metro.init()
  m.time  = 1 / 30
  m.event = function()
    update_points()
    redraw()
  end
  m:start()
end

-- -----------------------------------------------------------------
-- Update
-- -----------------------------------------------------------------

function update_points()
  if showing_splash then return end

  -- Sync point count (add)
  while #points < max_points do
    table.insert(points, init_point())
  end

  -- Sync point count (remove)
  -- close active notes involving the points being removed,
  -- then remove points one at a time from the end
  while #points > max_points do
    local n = #points
    for k, data in pairs(active_notes) do
      -- extract both indices from the key string
      local si, sj = k:match("^(%d+)_(%d+)$")
      local pi, pj = tonumber(si), tonumber(sj)
      if pi == n or pj == n then
        midi_out:note_off(data.note, 0, data.channel)
        active_notes[k] = nil
      end
    end
    table.remove(points)
  end

  -- Move points
  for _, p in ipairs(points) do
    p.x = p.x + p.dx * global_speed
    p.y = p.y + p.dy * global_speed
    if p.x <= 0  or p.x >= 128 then p.dx = -p.dx end
    if p.y <= 0  or p.y >= 64  then p.dy = -p.dy end
    p.x = util.clamp(p.x, 0, 128)
    p.y = util.clamp(p.y, 0, 64)
  end

  -- Check connections → note on/off
  for i = 1, #points do
    for j = i + 1, #points do
      local k   = i .. "_" .. j
      local p1  = points[i]
      local p2  = points[j]
      local dist = math.sqrt((p1.x - p2.x)^2 + (p1.y - p2.y)^2)

      if dist < max_distance then
        if not active_notes[k] then
          local note    = x_to_note((p1.x + p2.x) / 2)
          local vel_raw = y_to_velocity((p1.y + p2.y) / 2)
          local vel     = dist_to_velocity(dist, vel_raw)
          local ch      = pair_channel(i, j)

          midi_out:note_on(note, vel, ch)
          active_notes[k] = { note = note, channel = ch }

          -- Flash both nodes (only if enabled in params)
          if params:get("node_flash") == 2 then
            flash_frames[i] = 3
            flash_frames[j] = 3
          end

          local gt = gate_time()
          clock.run(function()
            clock.sleep(gt)
            -- check the note is still the one we launched,
            -- to avoid a double note_off if the else branch already closed it
            local entry = active_notes[k]
            if entry and entry.note == note and entry.channel == ch then
              midi_out:note_off(note, 0, ch)
              active_notes[k] = nil
            end
          end)
        end
      else
        if active_notes[k] then
          midi_out:note_off(active_notes[k].note, 0, active_notes[k].channel)
          active_notes[k] = nil
        end
      end
    end
  end
end

-- -----------------------------------------------------------------
-- Encoders
-- -----------------------------------------------------------------

function enc(n, d)
  if n == 1 then
    -- fixed small step to avoid positive feedback (d * speed)
    global_speed = util.clamp(global_speed + d * 0.02, 0.05, 3.0)
  elseif n == 2 then
    max_points = util.clamp(max_points + d, 2, 30)
  elseif n == 3 then
    max_distance = util.clamp(max_distance + d, 5, 80)
  end
end

-- -----------------------------------------------------------------
-- Keys
-- -----------------------------------------------------------------

function key(n, z)
  if n == 2 and z == 1 then
    midi_panic()
    for i = 1, #points do points[i] = init_point() end
  end
end

-- -----------------------------------------------------------------
-- Redraw
-- -----------------------------------------------------------------

function redraw()
  if showing_splash then draw_splash() return end

  screen.clear()

  -- Connection lines
  for i = 1, #points do
    for j = i + 1, #points do
      local p1   = points[i]
      local p2   = points[j]
      local dist = math.sqrt((p1.x - p2.x)^2 + (p1.y - p2.y)^2)

      if dist < max_distance then
        local brightness = math.floor(util.linlin(0, max_distance, 10, 1, dist))
        local k = i .. "_" .. j
        if active_notes[k] then brightness = 15 end
        screen.level(brightness)
        screen.move(p1.x, p1.y)
        screen.line(p2.x, p2.y)
        screen.stroke()
      end
    end
  end

  -- Nodes (with optional flash on trigger)
  for idx, p in ipairs(points) do
    local f = flash_frames[idx] or 0
    if f > 0 then
      -- enlarged circle during flash
      screen.level(15)
      screen.circle(math.floor(p.x), math.floor(p.y), 2)
      screen.fill()
      flash_frames[idx] = f - 1
    else
      screen.level(15)
      screen.pixel(math.floor(p.x), math.floor(p.y))
      screen.fill()
    end
  end

  screen.update()
end
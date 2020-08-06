-- Keyboard Mappings for Hyper mode
-- Keycodes: https://www.hammerspoon.org/docs/hs.keycodes.html#map

local log = hs.logger.new('init.lua', 'debug')

local message = require('status-message')

-- {{{ F17 -> Hyper Key

-- A global variable for Hyper Mode
hyperMode = hs.hotkey.modal.new({})

-- Enter Hyper Mode when F17 (right option key) is pressed
pressedF17 = function() hyperMode:enter() end

-- Leave Hyper Mode when F17 (right option key) is released.
releasedF17 = function() hyperMode:exit() end

-- Bind the Hyper key
f17 = hs.hotkey.bind({}, 'F17', pressedF17, releasedF17)

-- }}} F17 -> Hyper Key

-- {{{ Hyper-<key> -> Launch apps
hyperModeAppMappings = {

  { key='/', app='Finder' },
  { key='b', app='Safari' },
  { key='c', app='Slack' },
  { key='f', app='Firefox Nightly' },
  { key='k', app='Calendar' },
  { key='m', app='Mail' },
  { key='r', app='Radar 8' },
  { key='s', app='Spotify' },
  { key='t', app='Kitty' },
  { key='w', app='Workflowy' },
  { key='x', app='Caprine', mods={'alt'} },
  { key='x', app='Messages' },

}
for i, mapping in ipairs(hyperModeAppMappings) do
  hyperMode:bind(mapping.mods, mapping.key, function()
    hs.application.launchOrFocus(mapping.app)
  end)
end
-- }}} Hyper-<key> -> Launch apps

-- {{{ Global microphone muting hotkeys.
local messageMuting = message.new('muted 🎤')
local messageHot = message.new('hot 🎤')

-- Hyper-, -> hold to enable mic (while held), tap to mute.
hyperMode:bind({}, ',', function()
    local device = hs.audiodevice.defaultInputDevice()
    device:setMuted(false)
    messageHot:notify()
    displayStatus()
  end,
  function()
    local device = hs.audiodevice.defaultInputDevice()
    device:setMuted(true)
    messageMuting:notify()
    displayStatus()
  end
)

-- Hyper-. -> tap to unmute mic.
hyperMode:bind({}, '.', function()
  local device = hs.audiodevice.defaultInputDevice()
  device:setMuted(false)
  messageHot:notify()
  displayStatus()
end
)
-- }}} Global microphone muting hotkeys.

-- {{{ Hyper-; -> lock screen
hyperMode:bind({}, ';', hs.caffeinate.lockScreen)
-- }}} Hyper-; -> lock screen

-- {{{ Hyper-⇧-w -> Restart Wi-Fi
hyperMode:bind({'shift'}, 'w', function()
  hs.notify.new({title='Restarting Wi-Fi...', withdrawAfter=3}):send()
  hs.wifi.setPower(false)
  hs.wifi.setPower(true)
end)
-- }}} Hyper-⇧-w -> Restart Wi-Fi

-- {{{ Hyper-d -> Paste today's date.
hyperMode:bind({}, 'd', function()
  local date = os.date("%Y-%m-%d")
  hs.pasteboard.setContents(date)
  hs.eventtap.keyStrokes(date)
end)
-- }}} Hyper-d -> Paste today's date.

-- {{{ Hyper-⌥-m -> Format selected Message ID as link and copy to clipboard.
hyperMode:bind({'shift'}, 'm', function()
  hs.eventtap.keyStroke({'cmd'}, 'c') -- Copy selected email message ID (e.g. from Mail.app).
  -- Allow some time for the command+c keystroke to fire asynchronously before
  -- we try to read from the clipboard
  hs.timer.doAfter(0.2, function()
    -- '<messageID>' -> 'message://%3CmessageID%3E'
    local messageID = hs.pasteboard.getContents()
    -- Remove non-printable and whitespace characters.
    local messageID = messageID:gsub("[%s%G]", "")
    local messageID = messageID:gsub("^<?", "message://%%3C", 1)
    local messageID = messageID:gsub(">?$", "%%3E", 1)
    hs.pasteboard.setContents(messageID)
  end)
end)
-- }}} Hyper-⌥-m -> Format selected Message ID as link and copy to clipboard.

-- {{{ Hyper-⇧-x -> Restart the touch strip.
hyperMode:bind({'shift'}, 'x', function()
  local output, status, _, rc = hs.execute("pkill ControlStrip 2>&1")
  hs.notify.new({title='Restarting ControlStrip...', informativeText=rc.." "..output, withdrawAfter=3}):send()
end)
-- }}} Hyper-⇧-x -> Restart the touch strip.

-- {{{ Hyper-p -> Screenshot of selected area to clipboard.
hyperMode:bind({}, 'p', function()
  hs.eventtap.keyStroke({'cmd', 'ctrl', 'shift'}, '4')
end)
-- }}} Hyper-p -> Screenshot of selected area to clipboard.

-- {{{ Hyper-Enter -> Open clipboard contents.
hyperMode:bind({}, 'return', function()
  local clipboard = hs.pasteboard.getContents()
  local output, status, _, rc = hs.execute("open "..clipboard)
  hs.notify.new({title='Opening Clipboard Contents...', subTitle=clipboard, informativeText=rc.." "..output, withdrawAfter=3}):send()
end)
-- }}} Hyper-Enter -> Open clipboard contents.

-- {{{ Hyper-<mods>-v -> Connect to VPN
local callVpn = function(arg)
  local cmd = os.getenv("HOME").."/bin/vpn "..arg
  local output, status, _, rc = hs.execute(cmd)
  hs.notify.new({title='VPN '..arg..'...', informativeText=rc.." "..output, withdrawAfter=3}):send()
end
hyperMode:bind({}, 'v', function()
  callVpn("corporate")
end)
hyperMode:bind({'shift'}, 'v', function()
  callVpn("off")
end)
hyperMode:bind({'cmd'}, 'v', function()
  callVpn("dc")
end)
-- }}} Hyper-<mods>-v -> Connect to VPN

-- {{{ Hyper-{h,n,e,i} -> Arrow Keys, Hyper-{j,l,u,y} -> Home,PgDn,PgUp,End
local fastKeyStroke = function(modifiers, character, isdown)
  -- log.d('Sending:', modifiers, character, isdown)
  local event = require("hs.eventtap").event
  event.newKeyEvent(modifiers, character, isdown):post()
end

for i, hotkey in ipairs({
  { key='h', direction='left'},
  { key='n', direction='down'},
  { key='e', direction='up'},
  { key='i', direction='right'},
  { key='j', direction='home'},
  { key='l', direction='pagedown'},
  { key='u', direction='pageup'},
  { key='y', direction='end'},
}) do
  for j, mods in ipairs({
    {},
    {'cmd'},
    {'alt'},
    {'ctrl'},
    {'shift'},
    {'cmd', 'shift'},
    {'alt', 'shift'},
    {'ctrl', 'shift'},
  }) do
    -- hs.hotkey.bind(mods, key, message, pressedfn, releasedfn, repeatfn) -> hs.hotkey object
    hyperMode:bind(
      mods,
      hotkey.key,
      function() fastKeyStroke(mods, hotkey.direction, true) end,
      function() fastKeyStroke(mods, hotkey.direction, false) end,
      function() fastKeyStroke(mods, hotkey.direction, true) end
    )
  end
end

-- }}} Hyper-{h,n,e,i} -> Arrow Keys

-- vim: foldmethod=marker

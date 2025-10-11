local isUiOpen         = false
local userTurnedOff    = false
local KVP_OFF_KEY      = "hc_watermark_off"
local KVP_POS_KEY      = "hc_watermark_position"
local _last            = { money=nil, gold=nil, displayId=nil }
local __displayIdFromServer = nil
local MENU_POLL_MS     = 250
local _vorpCountLocal  = 0
local _menuOpenCached  = false
local _lastMenuPoll    = 0

local function _vorpEnabled()
  return (Config and Config.VorpMenu == true)
      or (config and (config.VorpMenu == true or config.vorpMenu == true))
end

AddEventHandler("vorp_menu:openmenu", function() _vorpCountLocal = _vorpCountLocal + 1 end)
AddEventHandler("vorp_menu:closemenu", function() _vorpCountLocal = math.max(0, _vorpCountLocal - 1) end)

AddEventHandler("menuapi:closemenu", function()
  if not _vorpEnabled() then return end
  local ok, ref = pcall(function() return exports["vorp_menu"]:GetMenuData() end)
  if ok and type(ref)=="table" then
    _vorpCountLocal = tonumber(ref._openCount) or 0
  else
    _vorpCountLocal = math.max(0, _vorpCountLocal - 1)
  end
end)

local function _safeGetMenuData()
  if not _vorpEnabled() then return nil end
  local ok, data = pcall(function() return exports["vorp_menu"]:GetMenuData() end)
  if ok and type(data)=="table" then return data end
  return nil
end

local function _anyMenuOpen_cached()
  if not _vorpEnabled() then return false end
  if _vorpCountLocal > 0 then return true end
  local t = GetGameTimer()
  if (t - _lastMenuPoll) >= MENU_POLL_MS then
    _lastMenuPoll = t
    local md = _safeGetMenuData()
    if md then
      local count = tonumber(md._openCount) or 0
      if count <= 0 and type(md.Opened)=="table" then
        for i=1,#md.Opened do if md.Opened[i] ~= nil then count = 1 break end end
        if count == 0 then
          for _, v in pairs(md.Opened) do if v ~= nil then count = 1 break end end
        end
      end
      _menuOpenCached = (count > 0)
    else
      _menuOpenCached = false
    end
  end
  return _menuOpenCached
end

local function _isBlocked()
  return IsPauseMenuActive() or IsScreenFadedOut() or _anyMenuOpen_cached()
end

local VALID_POS = { ["top-right"]=1, ["top-left"]=1, ["bottom-right"]=1, ["bottom-left"]=1 }

local function _getSavedPosition()
  local pos = GetResourceKvpString(KVP_POS_KEY)
  if pos == nil or pos == "" then
    return (config and config.position) or "top-right"
  end
  return pos
end

local function _pad2(n) return string.format("%02d", tonumber(n) or 0) end
local function _fmtGameTime()
  return _pad2(GetClockHours()) .. ":" .. _pad2(GetClockMinutes())
end

local function _readStats()
  local st = LocalPlayer and LocalPlayer.state
  local ch = st and st.Character or nil
  local money  = (type(ch)=="table") and ch.Money or nil
  local gold   = (type(ch)=="table") and ch.Gold  or nil
  local displayId = __displayIdFromServer
  if not (money or gold or displayId) then return nil end
  return { money = money, gold = gold, displayId = displayId }
end

local function _sendStats(force)
  local s = _readStats()
  if not s then return end
  if force or s.money ~= _last.money or s.gold ~= _last.gold or s.displayId ~= _last.displayId then
    _last = { money = s.money, gold = s.gold, displayId = s.displayId }
    SendNUIMessage({ type='SetStats', money=s.money, gold=s.gold, displayId=s.displayId })
  end
end

local function showWM(display)
  local stats = display and _readStats() or nil
  local ok, err = pcall(function()
    SendNUIMessage({ type='DisplayWM', visible=display, position=_getSavedPosition(), stats=stats })
  end)
  if not ok then print("^1[RedM-WM] NUI error: "..tostring(err)) end
  isUiOpen = display
end

CreateThread(function()
  userTurnedOff = (GetResourceKvpInt(KVP_OFF_KEY) == 1)
  while not NetworkIsSessionStarted() do Wait(250) end
  Wait(1000)
  local blocked      = _isBlocked()
  local lastBlocked  = blocked
  local lastMinute   = -1
  local lastStatsTs  = 0
  local visible = (not userTurnedOff) and (not blocked)
  showWM(visible)
  SendNUIMessage({ type='ToggleClock', visible = not blocked })
  if visible then _sendStats(true) end
  TriggerServerEvent("hcwm:requestGameId")

  while true do
    local sleep = 500
    blocked = _isBlocked()
    if blocked ~= lastBlocked then
      lastBlocked = blocked
      local shouldShow = (not userTurnedOff) and (not blocked)
      if shouldShow ~= isUiOpen then
        showWM(shouldShow)
        if shouldShow then _sendStats(true) end
      end
      SendNUIMessage({ type='ToggleClock', visible = not blocked })
    elseif (not blocked) and (not userTurnedOff) and (not isUiOpen) then
      showWM(true)
      SendNUIMessage({ type='ToggleClock', visible = true })
      _sendStats(true)
    end
    local t = GetGameTimer()
    if isUiOpen and not userTurnedOff and (t - lastStatsTs) >= 1000 then
      _sendStats(false)
      lastStatsTs = t
    end
    local minuteNow = (GetClockHours() * 60) + GetClockMinutes()
    if minuteNow ~= lastMinute then
      lastMinute = minuteNow
      SendNUIMessage({ type='SetClock', gameTime=_fmtGameTime() })
    end

    Wait(sleep)
  end
end)

if config and config.framework == 'vorp' then
  AddEventHandler("vorp:SelectedCharacter", function(_)
    SetTimeout(2000, function()
      local blocked = _isBlocked()
      if not userTurnedOff and not blocked then showWM(true) _sendStats(true) end
      TriggerServerEvent("hcwm:requestGameId")
    end)
  end)
elseif config and config.framework == 'rsg' then
  AddEventHandler("RSGCore:Client:OnPlayerLoaded", function(_)
    SetTimeout(2000, function()
      local blocked = _isBlocked()
      if not userTurnedOff and not blocked then showWM(true) _sendStats(true) end
      TriggerServerEvent("hcwm:requestGameId")
    end)
  end)
elseif config and config.framework == 'redemrp' then
  AddEventHandler("redemrp_charselect:SpawnCharacter", function()
    SetTimeout(2000, function()
      local blocked = _isBlocked()
      if not userTurnedOff and not blocked then showWM(true) _sendStats(true) end
      TriggerServerEvent("hcwm:requestGameId")
    end)
  end)
else
  print("^1[RedM-WM] Framework non supportato o config mancante: controlla config.framework")
end

RegisterNetEvent("hcwm:setGameId")
AddEventHandler("hcwm:setGameId", function(displayId, money, gold)
  if displayId and displayId ~= "" then __displayIdFromServer = tostring(displayId) end
  if money ~= nil then _last.money = money end
  if gold  ~= nil then _last.gold  = gold  end
  _sendStats(true)
end)

RegisterNetEvent('DisplayWM')
AddEventHandler('DisplayWM', function(status)
  userTurnedOff = not status
  SetResourceKvpInt(KVP_OFF_KEY, userTurnedOff and 1 or 0)
  local blocked = _isBlocked()
  local visible = status and (not blocked)
  showWM(visible)
  if visible then _sendStats(true) end
end)

RegisterNetEvent('SetWMPosition')
AddEventHandler('SetWMPosition', function(position)
  position = tostring(position or ""):lower()
  if not VALID_POS[position] then
    print("^1[RedM-WM] Posizione non valida: "..position); return
  end
  SetResourceKvpString(KVP_POS_KEY, position)
  SendNUIMessage({ type='SetWMPosition', position=position })
end)

RegisterCommand('watermark', function(_, args)
  if not (config and config.allowoff) and (not args[1] or args[1]=="") then
    TriggerEvent('chat:addMessage', { color={255,0,0}, multiline=false,
      args={"^9[RedM-WM] ^1Questo server ha disabilitato il comando /watermark"} })
    return
  end
  local sub = tostring(args[1] or ""):lower()
  if sub == "pos" then
    TriggerEvent('SetWMPosition', tostring(args[2] or ""):lower())
  else
    TriggerEvent('DisplayWM', not isUiOpen)
  end
end, false)

CreateThread(function()
  local myBag = ("player:%s"):format(tostring(GetPlayerServerId(PlayerId())))
  AddStateBagChangeHandler('Character', nil, function(bagName, _key, _val, _res, _rep)
    if bagName ~= myBag then return end
    _sendStats(true)
  end)
end)

AddEventHandler('onResourceStop', function(res)
  if res ~= GetCurrentResourceName() then return end
  SendNUIMessage({ type='DisplayWM', visible=false })
  SendNUIMessage({ type='ToggleClock', visible=false })
end)
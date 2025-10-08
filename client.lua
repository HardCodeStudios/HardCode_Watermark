local isUiOpen      = false
local userTurnedOff = false
local KVP_OFF_KEY   = "hc_watermark_off"
local KVP_POS_KEY   = "hc_watermark_position"

local _last = { money = nil, gold = nil, displayId = nil }
local __displayIdFromServer = nil

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
    local prev = false
    while true do
        Citizen.Wait(150)
        local blocked = IsRadarHidden() or IsPauseMenuActive()
        if blocked ~= prev then
            prev = blocked
            if not userTurnedOff then showWM(not blocked) end
            SendNUIMessage({ type='ToggleClock', visible=not blocked })
        end
    end
end)

CreateThread(function()
    userTurnedOff = (GetResourceKvpInt(KVP_OFF_KEY) == 1)
    while not NetworkIsSessionStarted() do Citizen.Wait(500) end
    Citizen.Wait(2000)
    showWM(not userTurnedOff)
    if not userTurnedOff then _sendStats(true) end
    TriggerServerEvent("hcwm:requestGameId")
end)

CreateThread(function()
    while true do
        Citizen.Wait(1500)
        if isUiOpen and not userTurnedOff then _sendStats(false) end
    end
end)

CreateThread(function()
    while true do
        Citizen.Wait(1000)
        SendNUIMessage({ type='SetClock', gameTime=_fmtGameTime() })
    end
end)

if config and config.framework == 'vorp' then
    AddEventHandler("vorp:SelectedCharacter", function(_)
        Citizen.SetTimeout(2000, function()
            if not userTurnedOff then showWM(true) _sendStats(true) end
            TriggerServerEvent("hcwm:requestGameId")
        end)
    end)
elseif config and config.framework == 'rsg' then
    AddEventHandler("RSGCore:Client:OnPlayerLoaded", function(_)
        Citizen.SetTimeout(2000, function()
            if not userTurnedOff then showWM(true) _sendStats(true) end
            TriggerServerEvent("hcwm:requestGameId")
        end)
    end)
elseif config and config.framework == 'redemrp' then
    AddEventHandler("redemrp_charselect:SpawnCharacter", function()
        Citizen.SetTimeout(2000, function()
            if not userTurnedOff then showWM(true) _sendStats(true) end
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
    showWM(status)
    if status then _sendStats(true) end
end)

RegisterNetEvent('SetWMPosition')
AddEventHandler('SetWMPosition', function(position)
    position = tostring(position or ""):lower()
    if not ({["top-right"]=1,["top-left"]=1,["bottom-right"]=1,["bottom-left"]=1})[position] then
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
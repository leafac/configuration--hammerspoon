-------------------------------------------------------------------------------
-- WINDOW MANAGEMENT
for key, rect in pairs({
    ["Q"] = {x = 0, y = 0, w = 0.5, h = 0.5},
    ["W"] = {x = 0, y = 0, w = 1, h = 0.5},
    ["E"] = {x = 0.5, y = 0, w = 0.5, h = 0.5},
    ["A"] = {x = 0, y = 0, w = 0.5, h = 1},
    ["S"] = {x = 0, y = 0, w = 1, h = 1},
    ["D"] = {x = 0.5, y = 0, w = 0.5, h = 1},
    ["Z"] = {x = 0, y = 0.5, w = 0.5, h = 0.5},
    ["X"] = {x = 0, y = 0.5, w = 1, h = 0.5},
    ["C"] = {x = 0.5, y = 0.5, w = 0.5, h = 0.5}
}) do
    hs.hotkey.bind({"⌃", "⌥", "⌘"}, key, function()
        hs.window.focusedWindow():move(rect, nil, true)
    end)
end

hs.hotkey.bind({"⌃", "⌥", "⌘"}, "tab", function()
    hs.window.focusedWindow():moveToScreen(
        hs.window.focusedWindow():screen():next(), true, true)
end)

-------------------------------------------------------------------------------
-- MENUBAR

local menubar = hs.menubar.new()
hs.timer.doEvery(1, function() menubar:setTitle(os.date("%Y-%m-%d  %H:%M  %A")) end)

-------------------------------------------------------------------------------
-- STREAMING

local modal = hs.hotkey.modal.new({"⌘", "⇧"}, "2")
modal:bind({"⌘", "⇧"}, "2", function() modal:exit() end)

local obs
local obsCurrentProgramScene
local function obsConnect()
    obs = hs.websocket.new("ws://127.0.0.1:4455/",
                           function(status, messageString)
        print([[OBS: ‘]] .. tostring(status) .. [[’: ‘]] ..
                  tostring(messageString) .. [[’]])
        if status == "received" then
            local message = hs.json.decode(messageString)
            if message.op == 0 then
                obs:send([[
                    {
                        "op": 1,
                        "d": {
                            "rpcVersion": 1
                        }
                    }
                ]], false)
            elseif message.op == 5 then
                if message.d.eventType == "CurrentProgramSceneChanged" then
                    obsCurrentProgramScene = message.d.eventData.sceneName
                end
            elseif message.op == 7 then
                if message.d.requestId == "GetCurrentProgramScene" then
                    obsCurrentProgramScene =
                        message.d.responseData.currentProgramSceneName
                end
            end
        end
    end)
end
for key, sceneName in pairs({
    ["R"] = "STARTING SOON…",
    ["T"] = "WE’LL BE RIGHT BACK…",
    ["Y"] = "THANKS FOR WATCHING",
    ["F"] = "ME",
    ["G"] = "GUEST 1",
    ["H"] = "GUEST 2",
    ["J"] = "GUEST 3",
    ["K"] = "GUEST 4",
    ["V"] = "GRID",
    ["B"] = "SCREEN",
    ["N"] = "DESK",
    ["M"] = "WINDOWS",
    [","] = "GUEST · SKYPE · SCREEN"
}) do
    modal:bind({"⌃", "⌥", "⌘"}, key, function()
        if obs == nil or
            (obs:status() ~= "connecting" and obs:status() ~= "open") then
            obsConnect()
        else
            obs:send([[
                {
                    "op": 6,
                    "d": {
                        "requestType": "SetCurrentProgramScene",
                        "requestId": "SetCurrentProgramScene",
                        "requestData": {
                            "sceneName": "]] .. sceneName .. [["
                        }
                    }
                }
            ]], false)
        end
    end)
end

modal:bind({"⌃", "⌥", "⌘"}, "U", function()
    hs.http.get("http://127.0.0.1:4456/_/SET/TRACK/2/RECARM/-1")
end)

local menubar
local menubarTimer

function modal:entered()
    hs.osascript.applescript(
        [[do shell script "launchctl kickstart -kp system/com.apple.audio.coreaudiod" with administrator privileges]])
    hs.timer.doAfter(5, function()
        hs.screen.mainScreen():setMode(1280, 720, 2, 60, 7)
        hs.screen.mainScreen():setMode(1280, 720, 2, 60, 8)

        hs.wifi.setPower(false)

        local outputDevice = hs.audiodevice.findOutputByName("Computer")
        outputDevice:setDefaultOutputDevice()
        outputDevice:setDefaultEffectDevice()
        local inputDevice = hs.audiodevice.findOutputByName("Call Input")
        inputDevice:setDefaultInputDevice()

        hs.open("/Users/leafac/Videos/STREAM.rpp")
        hs.application.open("EOS Utility 3")
        hs.application.open("OBS")
        hs.application.open("Keycastr")

        hs.timer.doAfter(5, obsConnect)

        menubar = hs.menubar.new()
        menubarTimer = hs.timer.doEvery(1, function()
            local isMicrophoneOn = (tonumber(
                                       hs.fnutils.split(select(2, hs.http
                                                                   .get(
                                                                   "http://127.0.0.1:4456/_/TRACK/2")) or
                                                            "", "\t")[4]) or 0) &
                                       64 ~= 0

            if obs == nil or
                (obs:status() ~= "connecting" and obs:status() ~= "open") then
                obsConnect()
                obsCurrentProgramScene = nil
            else
                obs:send([[
                    {
                        "op": 6,
                        "d": {
                            "requestType": "GetCurrentProgramScene",
                            "requestId": "GetCurrentProgramScene"
                        }
                    }
                ]], false)
            end

            menubar:setTitle((isMicrophoneOn and "🔴" or "⚫️") ..
                                 (type(obsCurrentProgramScene) == "string" and
                                     ([[ ]] .. obsCurrentProgramScene) or ""))
        end)
    end)
end

function modal:exited()
    hs.screen.mainScreen():setMode(1920, 1080, 2, 60, 7)
    hs.screen.mainScreen():setMode(1920, 1080, 2, 60, 8)

    hs.wifi.setPower(true)

    local audioDevice = hs.audiodevice.findOutputByName("Audient iD14")
    audioDevice:setDefaultOutputDevice()
    audioDevice:setDefaultEffectDevice()
    audioDevice:setDefaultInputDevice()

    if obs ~= nil and (obs:status() == "connecting" or obs:status() == "open") then
        obs:close()
    end
    obsCurrentProgramScene = nil

    menubar:delete()
    menubarTimer:stop()
end

--[[
-- https://superuser.com/a/1486266

------------------------------------------------------------------------------------------
-- AUTOSCROLL WITH MOUSE WHEEL BUTTON
-- timginter @ GitHub
------------------------------------------------------------------------------------------

-- id of mouse wheel button
local mouseScrollButtonId = 2

-- scroll speed and direction config
local scrollSpeedMultiplier = 0.1
local scrollSpeedSquareAcceleration = true
local reverseVerticalScrollDirection = false
local mouseScrollTimerDelay = 0.01

-- circle config
local mouseScrollCircleRad = 10
local mouseScrollCircleDeadZone = 5

------------------------------------------------------------------------------------------

local mouseScrollCircle = nil
local mouseScrollTimer = nil
local mouseScrollStartPos = 0
local mouseScrollDragPosX = nil
local mouseScrollDragPosY = nil

overrideScrollMouseDown = hs.eventtap.new({ hs.eventtap.event.types.otherMouseDown }, function(e)
    -- uncomment line below to see the ID of pressed button
    --print(e:getProperty(hs.eventtap.event.properties['mouseEventButtonNumber']))

    if e:getProperty(hs.eventtap.event.properties['mouseEventButtonNumber']) == mouseScrollButtonId then
        -- remove circle if exists
        if mouseScrollCircle then
            mouseScrollCircle:delete()
            mouseScrollCircle = nil
        end

        -- stop timer if running
        if mouseScrollTimer then
            mouseScrollTimer:stop()
            mouseScrollTimer = nil
        end

        -- save mouse coordinates
        mouseScrollStartPos = hs.mouse.getAbsolutePosition()
        mouseScrollDragPosX = mouseScrollStartPos.x
        mouseScrollDragPosY = mouseScrollStartPos.y

        -- start scroll timer
        mouseScrollTimer = hs.timer.doAfter(mouseScrollTimerDelay, mouseScrollTimerFunction)

        -- don't send scroll button down event
        return true
    end
end)

overrideScrollMouseUp = hs.eventtap.new({ hs.eventtap.event.types.otherMouseUp }, function(e)
    if e:getProperty(hs.eventtap.event.properties['mouseEventButtonNumber']) == mouseScrollButtonId then
        -- send original button up event if released within 'mouseScrollCircleDeadZone' pixels of original position and scroll circle doesn't exist
        mouseScrollPos = hs.mouse.getAbsolutePosition()
        xDiff = math.abs(mouseScrollPos.x - mouseScrollStartPos.x)
        yDiff = math.abs(mouseScrollPos.y - mouseScrollStartPos.y)
        if (xDiff < mouseScrollCircleDeadZone and yDiff < mouseScrollCircleDeadZone) and not mouseScrollCircle then
            -- disable scroll mouse override
            overrideScrollMouseDown:stop()
            overrideScrollMouseUp:stop()

            -- send scroll mouse click
            hs.eventtap.otherClick(e:location(), mouseScrollButtonId)

            -- re-enable scroll mouse override
            overrideScrollMouseDown:start()
            overrideScrollMouseUp:start()
        end

        -- remove circle if exists
        if mouseScrollCircle then
            mouseScrollCircle:delete()
            mouseScrollCircle = nil
        end

        -- stop timer if running
        if mouseScrollTimer then
            mouseScrollTimer:stop()
            mouseScrollTimer = nil
        end

        -- don't send scroll button up event
        return true
    end
end)

overrideScrollMouseDrag = hs.eventtap.new({ hs.eventtap.event.types.otherMouseDragged }, function(e)
    -- sanity check
    if mouseScrollDragPosX == nil or mouseScrollDragPosY == nil then
        return true
    end

    -- update mouse coordinates
    mouseScrollDragPosX = mouseScrollDragPosX + e:getProperty(hs.eventtap.event.properties['mouseEventDeltaX'])
    mouseScrollDragPosY = mouseScrollDragPosY + e:getProperty(hs.eventtap.event.properties['mouseEventDeltaY'])

    -- don't send scroll button drag event
    return true
end)

function mouseScrollTimerFunction()
    -- sanity check
    if mouseScrollDragPosX ~= nil and mouseScrollDragPosY ~= nil then
        -- get cursor position difference from original click
        xDiff = math.abs(mouseScrollDragPosX - mouseScrollStartPos.x)
        yDiff = math.abs(mouseScrollDragPosY - mouseScrollStartPos.y)

        -- draw circle if not yet drawn and cursor moved more than 'mouseScrollCircleDeadZone' pixels
        if mouseScrollCircle == nil and (xDiff > mouseScrollCircleDeadZone or yDiff > mouseScrollCircleDeadZone) then
            mouseScrollCircle = hs.drawing.circle(hs.geometry.rect(mouseScrollStartPos.x - mouseScrollCircleRad, mouseScrollStartPos.y - mouseScrollCircleRad, mouseScrollCircleRad * 2, mouseScrollCircleRad * 2))
            mouseScrollCircle:setStrokeColor({["red"]=0.3, ["green"]=0.3, ["blue"]=0.3, ["alpha"]=1})
            mouseScrollCircle:setFill(false)
            mouseScrollCircle:setStrokeWidth(1)
            mouseScrollCircle:show()
        end

        -- send scroll event if cursor moved more than circle's radius
        if xDiff > mouseScrollCircleRad or yDiff > mouseScrollCircleRad then
            -- get real xDiff and yDiff
            deltaX = mouseScrollDragPosX - mouseScrollStartPos.x
            deltaY = mouseScrollDragPosY - mouseScrollStartPos.y

            -- use 'scrollSpeedMultiplier'
            deltaX = deltaX * scrollSpeedMultiplier
            deltaY = deltaY * scrollSpeedMultiplier

            -- square for better scroll acceleration
            if scrollSpeedSquareAcceleration then
                -- mod to keep negative values
                deltaXDirMod = 1
                deltaYDirMod = 1

                if deltaX < 0 then
                    deltaXDirMod = -1
                end
                if deltaY < 0 then
                    deltaYDirMod = -1
                end

                deltaX = deltaX * deltaX * deltaXDirMod
                deltaY = deltaY * deltaY * deltaYDirMod
            end

            -- math.ceil / math.floor - scroll event accepts only integers
             deltaXRounding = math.ceil
             deltaYRounding = math.ceil

             if deltaX < 0 then
                 deltaXRounding = math.floor
             end
             if deltaY < 0 then
                 deltaYRounding = math.floor
             end

             deltaX = deltaXRounding(deltaX)
             deltaY = deltaYRounding(deltaY)

            -- reverse Y scroll if 'reverseVerticalScrollDirection' set to true
            if reverseVerticalScrollDirection then
                deltaY = deltaY * -1
            end

            -- send scroll event
            hs.eventtap.event.newScrollEvent({-deltaX, deltaY}, {}, 'pixel'):post()
        end
    end

    -- restart timer
    mouseScrollTimer = hs.timer.doAfter(mouseScrollTimerDelay, mouseScrollTimerFunction)
end

-- start override functions
overrideScrollMouseDown:start()
overrideScrollMouseUp:start()
overrideScrollMouseDrag:start()

------------------------------------------------------------------------------------------
-- END OF AUTOSCROLL WITH MOUSE WHEEL BUTTON
------------------------------------------------------------------------------------------

--]]

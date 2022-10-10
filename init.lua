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

menubar = hs.menubar.new()
menubarTimer = hs.timer.doEvery(1, function()
    menubar:setTitle(os.date("%Y-%m-%d  %H:%M  %A") ..
                         (type(streamingREAPERMicrophoneEnabled) == "string" and
                             (" · " .. streamingREAPERMicrophoneEnabled) or "") ..
                         (type(streamingOBSCurrentProgramScene) == "string" and
                             (" · " .. streamingOBSCurrentProgramScene) or ""))
end)

-------------------------------------------------------------------------------
-- STREAMING

streamingModal = hs.hotkey.modal.new({"⌘", "⇧"}, "2")
streamingModal:bind({"⌘", "⇧"}, "2", function() streamingModal:exit() end)

streamingMenubarTimer = nil

streamingREAPERMicrophoneEnabled = nil

streamingOBS = nil
streamingOBSCurrentProgramScene = nil

function streamingModal:entered()
    hs.osascript.applescript(
        [[do shell script "launchctl kickstart -kp system/com.apple.audio.coreaudiod" with administrator privileges]])
    hs.timer.doAfter(5, function()
        hs.screen.mainScreen():setMode(1280, 720, 2, 60, 7)
        hs.screen.mainScreen():setMode(1280, 720, 2, 60, 8)

        hs.wifi.setPower(false)

        local inputDevice = hs.audiodevice.findOutputByName("Call Input")
        inputDevice:setDefaultInputDevice()
        local outputDevice = hs.audiodevice.findOutputByName("Computer")
        outputDevice:setDefaultOutputDevice()
        outputDevice:setDefaultEffectDevice()

        hs.open("/Users/leafac/Videos/STREAM.rpp")
        hs.application.open("EOS Utility 3")
        hs.application.open("OBS")

        streamingMenubarTimer = hs.timer.doEvery(1, function()
            local REAPERResponse = select(2, hs.http
                                              .get(
                                              "http://127.0.0.1:4456/_/TRACK/2"))
            streamingREAPERMicrophoneEnabled =
                ((type(REAPERResponse) == "string") and REAPERResponse ~= "") and
                    ((tonumber(hs.fnutils.split(REAPERResponse, "\t")[4]) & 64 ~=
                        0) and "🔴" or "⬛️") or nil

            if streamingOBS == nil or
                (streamingOBS:status() ~= "connecting" and streamingOBS:status() ~=
                    "open") then
                streamingOBSConnect()
            else
                streamingOBS:send([[
                    {
                        "op": 6,
                        "d": {
                            "requestType": "GetCurrentProgramScene",
                            "requestId": "GetCurrentProgramScene"
                        }
                    }
                ]], false)
            end
        end)
    end)
end

function streamingModal:exited()
    hs.screen.mainScreen():setMode(1920, 1080, 2, 60, 7)
    hs.screen.mainScreen():setMode(1920, 1080, 2, 60, 8)

    hs.wifi.setPower(true)

    local audioDevice = hs.audiodevice.findOutputByName("Audient iD14")
    audioDevice:setDefaultInputDevice()
    audioDevice:setDefaultOutputDevice()
    audioDevice:setDefaultEffectDevice()

    streamingMenubarTimer:stop()
    streamingMenubarTimer = nil

    streamingREAPERMicrophoneEnabled = nil

    if streamingOBS ~= nil and
        (streamingOBS:status() == "connecting" or streamingOBS:status() ==
            "open") then
        streamingOBS:close()
        streamingOBS = nil
    end
    streamingOBSCurrentProgramScene = nil
end

streamingModal:bind({"⌃", "⌥", "⌘"}, "U", function()
    hs.http.get("http://127.0.0.1:4456/_/SET/TRACK/2/RECARM/-1")
end)

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
    streamingModal:bind({"⌃", "⌥", "⌘"}, key, function()
        if streamingOBS == nil or
            (streamingOBS:status() ~= "connecting" and streamingOBS:status() ~=
                "open") then
            streamingOBSConnect()
        else
            streamingOBS:send([[
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

streamingModal:bind({"⌃", "⌥", "⌘"}, "space", function()
    if streamingOBS == nil or
        (streamingOBS:status() ~= "connecting" and streamingOBS:status() ~=
            "open") then
        streamingOBSConnect()
    else
        streamingOBS:send([[
                {
                    "op": 6,
                    "d": {
                        "requestType": "GetStreamStatus",
                        "requestId": "GetStreamStatus"
                    }
                }
            ]], false)
        streamingOBS:send([[
                {
                    "op": 6,
                    "d": {
                        "requestType": "GetRecordStatus",
                        "requestId": "GetRecordStatus"
                    }
                }
            ]], false)
    end
end)

function streamingOBSConnect()
    streamingOBSCurrentProgramScene = nil
    streamingOBS = hs.websocket.new("ws://127.0.0.1:4455/",
                                    function(status, messageString)
        print([[OBS: ‘]] .. tostring(status) .. [[’: ‘]] ..
                  tostring(messageString) .. [[’]])
        if status == "received" then
            local message = hs.json.decode(messageString)
            if message.op == 0 then
                streamingOBS:send([[
                    {
                        "op": 1,
                        "d": {
                            "rpcVersion": 1
                        }
                    }
                ]], false)
            elseif message.op == 5 then
                if message.d.eventType == "CurrentProgramSceneChanged" then
                    streamingOBSCurrentProgramScene = message.d.eventData
                                                          .sceneName
                end
            elseif message.op == 7 then
                if message.d.requestId == "GetCurrentProgramScene" then
                    streamingOBSCurrentProgramScene =
                        message.d.responseData.currentProgramSceneName
                elseif message.d.requestId == "GetStreamStatus" or
                    message.d.requestId == "GetRecordStatus" then
                    if message.d.responseData.outputActive then
                        local file = assert(io.open(
                                                "/Users/leafac/Videos/MARKERS.txt",
                                                "a"))
                        file:write(string.sub(
                                       message.d.responseData.outputTimecode, 1,
                                       string.len("00:00:00")) .. "\n")
                        file:close()
                    end
                end
            end
        end
    end)
end

streamShowKeysEventTap = hs.eventtap.new({hs.eventtap.event.types.keyDown},
                                         function(event)
    local showKeys = {}

    local flags = event:getFlags()
    if flags.ctrl then table.insert(showKeys, "^") end
    if flags.alt then table.insert(showKeys, "⌥") end
    if flags.shift then table.insert(showKeys, "⇧") end
    if flags.cmd then table.insert(showKeys, "⌘") end
    if #showKeys == 0 then return end

    -- local character = hs.keycodes.map[event:getKeyCode()]
    -- local specialCharacters = {
    --     ["f1"] = true,
    --     ["f2"] = true,
    --     ["f3"] = true,
    --     ["f4"] = true,
    --     ["f5"] = true,
    --     ["f6"] = true,
    --     ["f7"] = true,
    --     ["f8"] = true,
    --     ["f9"] = true,
    --     ["f10"] = true,
    --     ["f11"] = true,
    --     ["f12"] = true,
    --     ["f13"] = true,
    --     ["f14"] = true,
    --     ["f15"] = true,
    --     ["f16"] = true,
    --     ["f17"] = true,
    --     ["f18"] = true,
    --     ["f19"] = true,
    --     ["f20"] = true,
    --     ["pad"] = true,
    --     ["pad*"] = true,
    --     ["pad+"] = true,
    --     ["pad/"] = true,
    --     ["pad-"] = true,
    --     ["pad="] = true,
    --     ["pad0"] = true,
    --     ["pad1"] = true,
    --     ["pad2"] = true,
    --     ["pad3"] = true,
    --     ["pad4"] = true,
    --     ["pad5"] = true,
    --     ["pad6"] = true,
    --     ["pad7"] = true,
    --     ["pad8"] = true,
    --     ["pad9"] = true,
    --     ["padclear"] = true,
    --     ["padenter"] = true,
    --     ["return"] = true,
    --     ["tab"] = true,
    --     ["space"] = true,
    --     ["delete"] = true,
    --     ["escape"] = true,
    --     ["help"] = true,
    --     ["home"] = true,
    --     ["pageup"] = true,
    --     ["forwarddelete"] = true,
    --     ["end"] = true,
    --     ["pagedown"] = true,
    --     ["left"] = true,
    --     ["right"] = true,
    --     ["down"] = true,
    --     ["up"] = true,
    --     ["shift,"] = true,
    --     ["rightshift,"] = true,
    --     ["cmd,"] = true,
    --     ["rightcmd,"] = true,
    --     ["alt,"] = true,
    --     ["rightalt,"] = true,
    --     ["ctrl,"] = true,
    --     ["rightctrl,"] = true,
    --     ["capslock,"] = true,
    --     ["fn,"] = true
    -- }

    -- if (not flags.shift and not flags.cmd and not flags.alt and not flags.ctrl) then
    -- end

    -- if specialCharacters[character] == nil then
    --     character = event:getCharacters(true)
    --     if flags.shift then character = string.lower(character) end
    -- end

    -- if character == "return" then
    --     character = "⏎"
    -- elseif character == "delete" then
    --     character = "⌫"
    -- elseif character == "escape" then
    --     character = "⎋"
    -- elseif character == "space" then
    --     character = "␣"
    -- elseif character == "up" then
    --     character = "↑"
    -- elseif character == "down" then
    --     character = "↓"
    -- elseif character == "left" then
    --     character = "←"
    -- elseif character == "right" then
    --     character = "→"
    -- end

    hs.alert(table.concat(showKeys, ""))
end):start()

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

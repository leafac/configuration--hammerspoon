-- $ defaults -currentHost write -g AppleFontSmoothing -int 0
-- $ sudo launchctl kickstart -kp system/com.apple.audio.coreaudiod
--
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
-- MOUSE BUTTONS

mouseButtonsEventTap = hs.eventtap.new({
    hs.eventtap.event.types.otherMouseDown, hs.eventtap.event.types.otherMouseUp
}, function(event)
    local type = event:getType()
    local buttonNumber = event:getProperty(
                             hs.eventtap.event.properties.mouseEventButtonNumber)
    local buttonNumberBack = 4
    local buttonNumberForward = 3
    local flags = event:getFlags()
    if type == hs.eventtap.event.types.otherMouseDown then
        if buttonNumber == buttonNumberBack or buttonNumber ==
            buttonNumberForward then return true, {} end
    elseif type == hs.eventtap.event.types.otherMouseUp then
        if buttonNumber == buttonNumberBack then
            if flags.cmd then
                return true, {
                    hs.eventtap.event.newGesture("beginMagnify"),
                    hs.eventtap.event.newGesture("endMagnify", 0.3)
                }
            else
                return true, {
                    hs.eventtap.event.newGesture("beginSwipeRight"),
                    hs.eventtap.event.newGesture("endSwipeRight")
                }
            end
        elseif buttonNumber == buttonNumberForward then
            if flags.cmd then
                return true, {
                    hs.eventtap.event.newGesture("beginMagnify"),
                    hs.eventtap.event.newGesture("endMagnify", -0.3)
                }
            else
                return true, {
                    hs.eventtap.event.newGesture("beginSwipeLeft"),
                    hs.eventtap.event.newGesture("endSwipeLeft")
                }
            end
        end
    end
end):start()

-------------------------------------------------------------------------------
-- KEYBOARD

keyboardEventTap = hs.eventtap.new({
    hs.eventtap.event.types.keyDown, hs.eventtap.event.types.keyUp
}, function(event)
    local type = event:getType()
    local keyCode = event:getKeyCode()
    local keyCodeF4 = 177
    local keyCodeF5 = 176
    local keyCodeF6 = 178
    if type == hs.eventtap.event.types.keyDown then
        if keyCode == keyCodeF4 then
            hs.application.open("Launchpad")
            return true, {}
        elseif keyCode == keyCodeF5 then
            return true, {
                hs.eventtap.event.newSystemKeyEvent("ILLUMINATION_DOWN", true),
                hs.eventtap.event.newSystemKeyEvent("ILLUMINATION_DOWN", false)
            }
        elseif keyCode == keyCodeF6 then
            return true, {
                hs.eventtap.event.newSystemKeyEvent("ILLUMINATION_UP", true),
                hs.eventtap.event.newSystemKeyEvent("ILLUMINATION_UP", false)
            }
        end
    elseif type == hs.eventtap.event.types.keyUp then
        if keyCode == keyCodeF4 or keyCode == keyCodeF5 or keyCode == keyCodeF6 then
            return true, {}
        end
    end
end):start()

hs.hotkey.bind({"⌃", "⌥", "⌘"}, "escape",
               function() disableKeyboardEventTap:start() end)
disableKeyboardEventTap = hs.eventtap.new({
    hs.eventtap.event.types.keyDown, hs.eventtap.event.types.systemDefined
}, function(event)
    local flags = event:getFlags()
    local keyCode = event:getKeyCode()
    if flags.ctrl and flags.alt and flags.cmd and keyCode ==
        hs.keycodes.map.escape then disableKeyboardEventTap:stop() end
    return true, {}
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

streamShowKeysEventTap = nil

streamingMenubarTimer = nil

streamingREAPERMicrophoneEnabled = nil

streamingOBS = nil
streamingOBSCurrentProgramScene = nil

streamingMIDIController = nil

function streamingModal:entered()
    hs.osascript.applescript(
        [[do shell script "launchctl kickstart -kp system/com.apple.audio.coreaudiod" with administrator privileges]])
    hs.timer.doAfter(5, function()
        -- hs.screen.mainScreen():setMode(1280, 720, 2, 60, 7)
        -- hs.screen.mainScreen():setMode(1280, 720, 2, 60, 8)

        -- hs.wifi.setPower(false)

        for _, name in
            pairs({"Computer", "Call Input", "Call Output", "Stream"}) do
            local audioDevice = hs.audiodevice.findDeviceByName(name)
            audioDevice:setInputMuted(false)
            audioDevice:setInputVolume(100)
            audioDevice:setOutputMuted(false)
            audioDevice:setOutputVolume(100)
        end
        local inputAudioDevice = hs.audiodevice.findDeviceByName("Call Input")
        inputAudioDevice:setDefaultInputDevice()
        local outputAudioDevice = hs.audiodevice.findDeviceByName("Computer")
        outputAudioDevice:setDefaultOutputDevice()
        outputAudioDevice:setDefaultEffectDevice()

        hs.open("/Users/leafac/Videos/ASSETS/audio/audio.RPP")
        hs.application.open("EOS Utility 3")
        -- hs.application.open("OBS")

        streamShowKeysEventTap = hs.eventtap.new({
            hs.eventtap.event.types.keyDown
        }, function(event)
            local flags = event:getFlags()
            local character = hs.keycodes.map[event:getKeyCode()]
            if ((not flags.ctrl) and (not flags.alt) and (not flags.cmd)) or
                type(character) ~= "string" then return end
            hs.alert.closeAll(0)
            hs.alert(
                (flags.ctrl and "⌃" or "") .. (flags.alt and "⌥" or "") ..
                    (flags.shift and "⇧" or "") .. (flags.cmd and "⌘" or "") ..
                    string.gsub(({
                        ["return"] = "⏎",
                        ["delete"] = "⌫",
                        ["escape"] = "⎋",
                        ["space"] = "␣",
                        ["tab"] = "⇥",
                        ["up"] = "↑",
                        ["down"] = "↓",
                        ["left"] = "←",
                        ["right"] = "→"
                    })[character] or character, "^%l", string.upper), {
                    strokeWidth = 0,
                    fillColor = {white = 0.1},
                    textColor = {white = 0.9},
                    textSize = 11,
                    radius = 5,
                    fadeInDuration = 0,
                    atScreenEdge = 1
                })
        end):start()

        streamingMenubarTimer = hs.timer.doEvery(1, function()
            local REAPERResponse = select(2, hs.http
                                              .get(
                                              "http://127.0.0.1:8080/_/TRACK/2"))
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

        -- streamingMIDIController = hs.midi.new("LPK25")
        -- if streamingMIDIController ~= nil then
        --     streamingMIDIController:callback(
        --         function(_, _, commandType, description, metadata)
        --             -- print(description)
        --             if commandType == "noteOn" and metadata.channel == 15 then
        --                 if metadata.note == 49 then
        --                     streamingREAPERSetMicrophone(true)
        --                 end
        --                 if metadata.note == 51 then
        --                     streamingREAPERSetMicrophone(false)
        --                 end
        --                 for note, sceneName in pairs({
        --                     [48] = "STARTING SOON…",
        --                     [50] = "WE’LL BE RIGHT BACK…",
        --                     [52] = "THANKS FOR WATCHING",
        --                     [53] = "ME",
        --                     [54] = "GUEST 1",
        --                     [55] = "GUEST 2",
        --                     [56] = "GUEST 3",
        --                     [57] = "GUEST 4",
        --                     [60] = "GRID",
        --                     [62] = "SCREEN",
        --                     [64] = "PHONE",
        --                     [65] = "WINDOWS",
        --                     [67] = "GUEST · SKYPE · SCREEN"
        --                 }) do
        --                     if metadata.note == note then
        --                         streamingOBSSwitchScene(sceneName)
        --                     end
        --                 end
        --                 if metadata.note == 72 then
        --                     streamingMarker()
        --                 end
        --             end
        --         end)
        -- end
    end)
end

function streamingModal:exited()
    -- hs.screen.mainScreen():setMode(1920, 1080, 2, 60, 7)
    -- hs.screen.mainScreen():setMode(1920, 1080, 2, 60, 8)

    -- hs.wifi.setPower(true)

    local audioDevice = hs.audiodevice.findDeviceByName("Audient iD14")
    if audioDevice ~= nil then
        audioDevice:setDefaultInputDevice()
        audioDevice:setDefaultOutputDevice()
        audioDevice:setDefaultEffectDevice()
    end

    streamShowKeysEventTap:stop()
    streamShowKeysEventTap = nil

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

    if streamingMIDIController ~= nil then
        streamingMIDIController:callback(nil)
        streamingMIDIController = nil
    end
end

function streamingREAPERSetMicrophone(on)
    hs.http.get("http://127.0.0.1:8080/_/SET/TRACK/2/RECARM/" ..
                    (on and "1" or "0"))
end

streamingModal:bind({"⌃", "⌥", "⌘"}, "U",
                    function() streamingREAPERSetMicrophone(true) end)
streamingModal:bind({"⌃", "⌥", "⌘"}, "I",
                    function() streamingREAPERSetMicrophone(false) end)

function streamingOBSSwitchScene(sceneName)
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
end

for key, sceneName in pairs({
    ["R"] = "STARTING SOON…",
    ["T"] = "WE’LL BE RIGHT BACK…",
    ["Y"] = "THANKS FOR WATCHING",
    ["F"] = "CAMERA",
    ["G"] = "WEBCAM",
    ["H"] = "SCREEN"
}) do
    streamingModal:bind({"⌃", "⌥", "⌘"}, key,
                        function() streamingOBSSwitchScene(sceneName) end)
end

function streamingMarker()
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
end

streamingModal:bind({"⌃", "⌥", "⌘"}, "space", streamingMarker)

function streamingOBSConnect()
    streamingOBSCurrentProgramScene = nil
    streamingOBS = hs.websocket.new("ws://127.0.0.1:4455/",
                                    function(status, messageString)
        -- print([[OBS: ‘]] .. tostring(status) .. [[’: ‘]] .. tostring(messageString) .. [[’]])
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

--[[

https://stackoverflow.com/questions/70717694/hold-mouse-key-to-scroll-in-hammerspoon

----


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

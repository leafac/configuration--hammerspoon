local modal = hs.hotkey.modal.new({"⌘", "⇧"}, "2")
modal:bind({"⌘", "⇧"}, "2", function() modal:exit() end)

local obs
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
        if obs ~= nil and obs:status() == "open" then
            obs:send([[
                {
                    "op": 6,
                    "d": {
                        "requestType": "SetCurrentProgramScene",
                        "requestId": "CHANGE-SCENE",
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

        hs.timer.doAfter(5, function()
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
                    end
                end
            end)
        end)

        menubar = hs.menubar.new()
        menubarTimer = hs.timer.new(1, function()
            local isMicrophoneOn = tonumber(
                                       hs.fnutils.split(select(2, hs.http
                                                                   .get(
                                                                   "http://127.0.0.1:4456/_/TRACK/2")),
                                                        "\t")[4]) & 64 ~= 0
            menubar:setTitle(isMicrophoneOn and "🔴" or "⚫️")
        end)
        menubarTimer:start()
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

    menubar:delete()
    menubarTimer:stop()
end

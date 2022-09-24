local modal = hs.hotkey.modal.new({"⌘", "⇧"}, "2")
modal:bind({"⌘", "⇧"}, "2", function() modal:exit() end)

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
end

hs.hotkey.bind({"⌃", "⌥", "⌘"}, ",", function() print("HELLO") end)

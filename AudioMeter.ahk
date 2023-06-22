; Functions
; GOn(val)
; {
;     global
;     if timeDisp.Value != val {
;         timeDisp.Value := val
;         gDisp.BackColor := (st := !st) ? "FFFF00" : "FFAA00"
;     }
;     if gShow
;         return 1
;     gDisp.Show("NoActivate")
;     gShow := true
;     SoundBeep
;     return 0
; }

; GOff()
; {
;     global
;     if not gShow
;         return 1
;     gDisp.Hide()
;     gShow := false
;     return 0
; }

OPing(val) ; Sound test
{
    global
    SoundBeep
    loop 32 { ; ~1 second
        ComCall 3, aMeter[val], "float*", &peak:=0
        if peak {
            tStamp[val] := A_Now
            Init()
            return 0
        }
        Sleep 32
    }
    LogReset(val) ; Reset on fail
    return val
}

^+!CtrlBreak:: ; Ctrl+Shift+Alt + Pause
LogReset(val)
{
    global
    ; GOn((val ? tDiff[tIdle] : "ERR") "`nRST")

    for val in dInterface ; Restart all watched devices
        RunWait('*RunAs ' A_ComSpec ' /c pnputil /restart-device "' val '"',,'Hide')
    
    ; Log initializations
    local iValid := IsNumber(val) and (0 < val) and (val <= cnt)
    local tMin   := iValid ? tStamp[val] : A_Now

    if not iValid {
        local iCaller := val ? "Hotkey" : "Error"
        loop cnt
            tMin := (DateDiff(tMin, tStamp[A_Index], "s") < 0) ?
                tMin : tStamp[A_Index] ; If no timeout, use earliest timestamp
    }

    FileAppend( ; If new file, add headers
        (FileExist(logName) ? "" : "Date,Start,End,Device,Input")
        . "`n"
        . FormatTime(tNow, "yy-MM-dd,") ; Date
        . FormatTime(tMin, "HH:mm:ss,") ; Start
        . FormatTime((iValid && dInput[val]) ? tStamp[val] : tNow, "HH:mm:ss,") ; End
        . (iCaller ?? deviceName[val]) "," ; Device
        . (iValid ? (dinput[val] ? "TRUE":"FALSE") : "") ; Input     
    , logName)

    Init()
    return 0
}

Init()
{
    global tStamp
    iNow := LInit()
    for val in tStamp {
        tStamp[A_Index] := iNow
    }

    ; GOff()
    return 0
}

LInit()
{
    Sleep 32 ; ~30 FPS
    global tNow := A_Now
    return tNow
}

; Confirm admin elevation
if not A_IsAdmin {
    Run('*RunAs "' A_AhkPath '" /restart "' A_ScriptFullPath '"')
    ExitApp 1
}

; Constants
logName      := "AudioMeter.csv" ; Log name & save location
A_WorkingDir := A_Desktop

deviceName := ["Headset", "Headset:2"] ; Devices to monitor
dInput     := [   false ,       true ] ; true=input, false=output
dTimeout   := [      90 ,          2 ] ; Timeout delay per device
dInterface := ["BTHHFENUM\BthHFPAudio\8&1234dbd4&1&97"] ; Interfaces to restart
cnt := deviceName.Length

; Initializations
aMeter := Array(), aMeter.Length := cnt
tStamp := Array(), tStamp.Length := cnt
; st := false

; IAudioMeterInformation
for val in deviceName {
    aMeter[A_Index] := SoundGetInterface(
        "{C02216F6-8C67-4B5B-9D00-D008E73E0064}", , val
    )
    if not aMeter[A_Index] {
        MsgBox '"' val '" not found or supported.'
        ExitApp 1
    }
}

; Message box setup
; gDisp := Gui("AlwaysOnTop -Caption -DPIScale ToolWindow")

; tmp := "" ; Placeholder text for autosize
; loop cnt
;     tmp .= "000`n"
; timeDisp := gDisp.AddText("Right", SubStr(tmp, 1, -1))

; gDisp.Show("AutoSize xCenter y0 Hide")
; gShow := true

Init()

loop {
    try loop ; Inner loop resets on error
    {
        loop cnt { ; Write peak value to address
            ComCall 3, aMeter[A_Index], "float*", &peak:=0

            if peak ; If sound, update last time, else check for timeout
                tStamp[A_Index] := A_Now
            else if (DateDiff(tNow, tStamp[A_Index], "s") >= dTimeout[A_Index])
                dInput[A_Index] ? LogReset(A_Index) : OPing(A_Index)
        }
        LInit()
    }
    catch { 
        LogReset(false)
    }
}

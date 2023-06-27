; Functions
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
LogReset(val, err:=false)
{
    global
    for vDev in dInterface ; Restart all watched devices
        RunWait('*RunAs ' A_ComSpec ' /c pnputil /restart-device "' vDev '"',,'Hide')
    
    if not (IsInteger(val) && (val >= 1) && (val <= cnt)) { ; If hotkey pressed
        val := unset
        dInput[1] := false
        deviceName[1] := "Hotkey"
        loop cnt-1 { ; Use earliest timestamp
            if (DateDiff(tStamp[1], tStamp[A_Index+1], "s") > 0)
                tStamp[1] := tStamp[A_Index+1]
        }
    }

    FileAppend( ; If new file, add headers
        (FileExist(logName)? "" : "Date,Start,End,Device,Input,Error")
        . "`n"
        . FormatTime(tNow, "yy-MM-dd,") ; Date
        . FormatTime(tStamp[val??1], "HH:mm:ss,") ; Start
        . FormatTime((!err && dInput[val??1])? tStamp[val] : tNow, "HH:mm:ss,") ; End
        . deviceName[val??1] "," ; Device
        . (IsSet(val)? (dInput[val]? "TRUE,":"FALSE,") : ",") ; Input
        . (err? "TRUE" : "FALSE") ; Error
    , logName)

    Init()
    return 0
}

Init()
{
    global tStamp
    iNow := LInit()
    for val in tStamp
        tStamp[A_Index] := iNow
        tIdle[A_Index]  := false
    return 0
}

LInit()
{
    global
    Sleep 32 ; ~30 FPS
    if not A_Now = tNow {
        global tNow := A_Now
        loop cnt {
            tIdle[A_Index] :=
                (DateDiff(tNow, tStamp[A_Index], "s") >= dTimeout[A_Index])
        }
    }
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
dInterface   := ["BTHHFENUM\BthHFPAudio\8&1234dbd4&1&97"] ; Interfaces to restart

; Array constants (must all be same length)
deviceName := ["Headset", "Headset:2"] ; Devices to monitor
dInput     := [   false ,       true ] ; true=input, false=output
dTimeout   := [      90 ,          1 ] ; Timeout delay (+0.5 ± 0.5 sec)

; Initializations
cnt := deviceName.Length

loop cnt ; Compensate for 1-second time resolution
    dTimeout[A_Index] := Integer(Max(dTimeout[A_Index]+1, 2))

aMeter := Array(), aMeter.Length := cnt
tStamp := Array(), tStamp.Length := cnt
tIdle  := Array(), tIdle.Length  := cnt

; I_Audio_Meter_Information
for val in deviceName {
    aMeter[A_Index] := SoundGetInterface(
        "{C02216F6-8C67-4B5B-9D00-D008E73E0064}", , val
    )
    if not aMeter[A_Index] {
        MsgBox '"' val '" not found or supported.'
        ExitApp 1
    }
}

Init()
loop {
    loop cnt { ; Write peak value to address
        try {
            ComCall 3, aMeter[A_Index], "float*", &peak:=0

            if peak { ; If sound, update last time
                tStamp[A_Index] := tNow
                tIdle := false
            }
            else if tIdle[A_Index] ; Else test/reset if idle
                dInput[A_Index] ? LogReset(A_Index) : OPing(A_Index)
        }
        catch
            LogReset(A_Index, true)
    }
    LInit()
}

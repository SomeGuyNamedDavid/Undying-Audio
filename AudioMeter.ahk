; Functions
Init() {
    global
    tmp    := [A_Now, ""]
    tmp[2] := FormatTime(tmp[1], "hh:mm:ss")
    loop cnt {
        tStamp[A_Index] := tmp[1]
        fTime[A_Index]  := tmp[2]
    }
}

LInit() {
    global
    tMax := 0
    Sleep 32 ; ~30 FPS
    tNow := A_Now
}

BClick(N1, N2) {
    global
    gDisp.Hide()

    tmp := ""
    if not FileExist(logName) { ; If new file, add headers
        tmp .= "Logdate,Logtime"
        loop cnt
            tmp .= "," deviceName[A_Index]
    }

    tmp .= FormatTime(tNow, "`nyy-MM-dd,HH:mm:ss") ; Log current time
    loop cnt ; Log last sound time
        tmp .= FormatTime(tStamp[A_Index], ",HH:mm:ss")

    FileAppend tmp, logName

    for val in dInterface ; Restart all watched devices
        RunWait('*RunAs ' A_ComSpec ' /c pnputil /restart-device "' val '"',
            , 'Hide'
    )

    Init()
    LInit()
    return 0
}

; Confirm admin elevation
if not A_IsAdmin {
    Run('*RunAs "' A_AhkPath '" /restart "' A_ScriptFullPath '"')
    ExitApp 1
}

; Constants
logName      := "AudioMeter.csv" ; Log name & save location
A_WorkingDir := A_Desktop

deviceName := ["Headset", "Headset:2"] ; Devices to monitor array
dInterface := ["BTHHFENUM\BthHFPAudio\8&1234dbd4&1&97"] ; Interfaces to restart
audioMeter := Array()
cnt := audioMeter.Length := deviceName.Length

; IAudioMeterInformation
for val in deviceName {
    audioMeter[A_Index] := SoundGetInterface(
        "{C02216F6-8C67-4B5B-9D00-D008E73E0064}", , val
    )
    if not audioMeter[A_Index] {
        MsgBox '"' val '" not found or supported.'
        ExitApp 1
    }
}

; Message box setup
gDisp := Gui("AlwaysOnTop -Caption -DPIScale ToolWindow")
gDisp.BackColor := "FF9900"
gShow := false

tmp := "" ; Default text
loop cnt
    tmp .= " __:__:__"
timeDisp := gDisp.AddText("w87 -Wrap", SubStr(tmp, 2) "`n__:__:__")

tmp := gDisp.AddButton("WP", "Flash")
tmp.OnEvent("Click", BClick)

gDisp.Show("AutoSize xCenter y0 Hide")

; Initializations
peak := Array(), tStamp := Array(), fTime := Array(), tDiff := Array()
peak.Length :=   tStamp.Length :=   fTime.Length :=   tDiff.Length :=  cnt
Init()

; Main (breakout on error)
try loop
{
    LInit()
    for val in audioMeter
    {
        ; audioMeter->GetPeakValue(&peak)
        ComCall 3, val, "float*", &tmp:=0
        peak[A_Index] := tmp

        if peak[A_Index] { ; If sound, update last time
            if tStamp[A_Index] != tNow
                fTime[A_Index] := FormatTime(tNow, "hh:mm:ss")
            tStamp[A_Index] := tNow
            tDiff[A_Index]  := 0
        }
        else { ; Else, update time since sound
            tDiff[A_Index] := DateDiff(tNow, tStamp[A_Index], "s")
            tMax := Max(tMax, tDiff[A_Index])
        }
    }

    ; If any idle devices, show warnbox
    if tMax >= 2 {
        tmp := ""
        for val in tDiff
            tmp .= " " (val >= 2 ? fTime[A_Index] : "__:__:__")
        tmp := SubStr(tmp, 2) FormatTime(tNow, "`nhh:mm:ss")
        if (timeDisp.Value != tmp)
            timeDisp.Value := tmp

        if not gShow {
            gDisp.Show("NoActivate")
            gShow := true
        }
    }
    else if gShow {
        gDisp.Hide()
        gShow := false
    }
}

for val in audioMeter
    ObjRelease val
ExitApp

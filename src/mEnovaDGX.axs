MODULE_NAME='mEnovaDGX' 	(
                                dev vdvObject,
                                dev dvDevice[]
                            )

(***********************************************************)
#include 'NAVFoundation.ModuleBase.axi'
#include 'NAVFoundation.ArrayUtils.axi'

/*
 _   _                       _          ___     __
| \ | | ___  _ __ __ _  __ _| |_ ___   / \ \   / /
|  \| |/ _ \| '__/ _` |/ _` | __/ _ \ / _ \ \ / /
| |\  | (_) | | | (_| | (_| | ||  __// ___ \ V /
|_| \_|\___/|_|  \__, |\__,_|\__\___/_/   \_\_/
                 |___/

MIT License

Copyright (c) 2023 Norgate AV Services Limited

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

(***********************************************************)
(*          DEVICE NUMBER DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_DEVICE

(***********************************************************)
(*               CONSTANT DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_CONSTANT

constant long TL_DRIVE	= 1

constant integer MAX_SWITCH_LEVEL = 3
constant char SWITCH_LEVEL[][NAV_MAX_CHARS] =   {
                                                    'VIDEO',
                                                    'AUDIO',
                                                    'ALL'
                                                }

constant integer MAX_OUTPUT = 64

constant integer FEEDBACK_LEVELS[] = 	{
                                            50, 	// Video
                                            51 		// Audio
                                        }

(***********************************************************)
(*              DATA TYPE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_TYPE

(***********************************************************)
(*               VARIABLE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_VARIABLE

volatile long ltDrive[] = { 200 }

volatile integer iCommandBusy

volatile integer iOutput[MAX_SWITCH_LEVEL][MAX_OUTPUT]
volatile integer iPending[MAX_SWITCH_LEVEL][MAX_OUTPUT]

(***********************************************************)
(*               LATCHING DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_LATCHING

(***********************************************************)
(*       MUTUALLY EXCLUSIVE DEFINITIONS GO BELOW           *)
(***********************************************************)
DEFINE_MUTUALLY_EXCLUSIVE

(***********************************************************)
(*        SUBROUTINE/FUNCTION DEFINITIONS GO BELOW         *)
(***********************************************************)
(* EXAMPLE: DEFINE_FUNCTION <RETURN_TYPE> <NAME> (<PARAMETERS>) *)
(* EXAMPLE: DEFINE_CALL '<NAME>' (<PARAMETERS>) *)
define_function Send(char cParam[]) {
    NAVLog("'Command To ', NAVConvertDPSToAscii(dvDevice[1]), '-[', cParam, ']'")
    NAVCommand(dvDevice[1], "cParam")
    wait 1 iCommandBusy = false
}


define_function char[NAV_MAX_CHARS] Build(integer iInput, integer iOutput, integer iLevel) {
    return "'CL', SWITCH_LEVEL[iLevel], 'I', itoa(iInput), 'O', itoa(iOutput)"
}


define_function Drive() {
    stack_var integer x
    stack_var integer i

    if (!iCommandBusy) {
        for (x = 1; x <= MAX_OUTPUT; x++) {
            for (i = 1; i <= MAX_SWITCH_LEVEL; i++) {
                if (iPending[i][x] && !iCommandBusy) {
                    iPending[i][x] = false
                    iCommandBusy = true
                    Send(Build(iOutput[i][x], x, i))
                }
            }
        }
    }
}


(***********************************************************)
(*                STARTUP CODE GOES BELOW                  *)
(***********************************************************)
DEFINE_START {
    NAVTimelineStart(TL_DRIVE, ltDrive, TIMELINE_ABSOLUTE, TIMELINE_REPEAT)
}

(***********************************************************)
(*                THE EVENTS GO BELOW                      *)
(***********************************************************)
DEFINE_EVENT
data_event[dvDevice] {
    online: {

    }
    command: {
        [vdvObject, DEVICE_COMMUNICATING] = true
        [vdvObject, DATA_INITIALIZED] = true
        NAVLog(NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_COMMAND_FROM, data.device, data.text))
    }
}

data_event[vdvObject] {
    online: {
        NAVCommand(data.device,"'PROPERTY-RMS_MONITOR_ASSET_PROPERTY,MONITOR_ASSET_DESCRIPTION,Matrix Switcher'")
        NAVCommand(data.device,"'PROPERTY-RMS_MONITOR_ASSET_PROPERTY,MONITOR_ASSET_MANUFACTURER_URL,www.amx.com'")
        NAVCommand(data.device,"'PROPERTY-RMS_MONITOR_ASSET_PROPERTY,MONITOR_ASSET_MANUFACTURER_NAME,AMX'")
    }
    command: {
        stack_var char cCmdHeader[NAV_MAX_CHARS]
        stack_var char cCmdParam[3][NAV_MAX_CHARS]

        NAVLog(NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_COMMAND_FROM, data.device, data.text))

        cCmdHeader = DuetParseCmdHeader(data.text)
        cCmdParam[1] = DuetParseCmdParam(data.text)
        cCmdParam[2] = DuetParseCmdParam(data.text)
        cCmdParam[3] = DuetParseCmdParam(data.text)

        switch (cCmdHeader) {
            case 'PASSTHRU': { Send(cCmdParam[1]) }
            case 'SWITCH': {
                stack_var integer iLevel

                iLevel = NAVFindInArrayString(NAV_SWITCH_LEVELS, cCmdParam[3])

                if (!iLevel) { iLevel = NAV_SWITCH_LEVEL_ALL }

                iOutput[iLevel][atoi(cCmdParam[2])] = atoi(cCmdParam[1])
                iPending[iLevel][atoi(cCmdParam[2])] = true
            }
        }
    }
}


timeline_event[TL_DRIVE] { Drive() }


level_event[dvDevice, FEEDBACK_LEVELS] {
    send_string 0, "'Output ', itoa(get_last(dvDevice)), ', Input ', itoa(level.value), ', ', NAV_SWITCH_LEVELS[get_last(FEEDBACK_LEVELS)]"
    send_string vdvObject, "'SWITCH-', itoa(level.value), ',', itoa(get_last(dvDevice)), ',', NAV_SWITCH_LEVELS[get_last(FEEDBACK_LEVELS)]"
}

(***********************************************************)
(*                     END OF PROGRAM                      *)
(*        DO NOT PUT ANY CODE BELOW THIS COMMENT           *)
(***********************************************************)

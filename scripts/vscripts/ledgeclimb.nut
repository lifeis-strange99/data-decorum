// scripts/vscripts/mapspawn.nut
// Basic ledge climb prototype for P2:CE

const GRAB_REACH     = 40.0    // how far in front of you to look for a ledge
const MAX_LEDGE_UP   = 96.0    // highest ledge you can grab above your feet
const MIN_LEDGE_UP   = 24.0    // lowest ledge worth climbing (below this you just walk)
const CLIMB_SPEED    = 200.0   // upward speed during the climb
const FORWARD_PUSH   = 120.0   // forward speed once you clear the top

climbing <- false
climbTarget <- 0.0

function FindLedge(player)
{
    local origin = player.GetOrigin()
    local fwd = player.GetForwardVector()
    fwd.z = 0
    fwd.Norm()

    // 1. is there a wall right in front of us at chest height?
    local chest = origin + Vector(0, 0, 48)
    local wallHit = TraceLine(chest, chest + fwd * GRAB_REACH, player)
    if (wallHit >= 1.0)
        return null   // nothing in front

    // 2. look downward just past the wall's edge to find the ledge top
    local probeTop = origin + Vector(0, 0, MAX_LEDGE_UP + 16) + fwd * (GRAB_REACH * wallHit + 8)
    local probeBottom = probeTop - Vector(0, 0, MAX_LEDGE_UP + 16)
    local downHit = TraceLine(probeTop, probeBottom, player)
    if (downHit >= 1.0)
        return null

    local ledgeZ = probeTop.z - (probeTop.z - probeBottom.z) * downHit
    local rise = ledgeZ - origin.z
    if (rise < MIN_LEDGE_UP || rise > MAX_LEDGE_UP)
        return null

    return ledgeZ
}

function ClimbThink()
{
    local player = Entities.FindByClassname(null, "player")
    if (player == null)
        return 0.05

    local origin = player.GetOrigin()
    local vel = player.GetVelocity()
    // airborne if there's no floor within a few units below the feet
    local floorHit = TraceLine(origin + Vector(0, 0, 2), origin - Vector(0, 0, 4), player)
    local airborne = (floorHit >= 1.0)
    if (!climbing)
    {
        // start a climb when the player is in the air (jumping) near a ledge
        if (airborne && vel.z > 0)        {
            local ledgeZ = FindLedge(player)
            if (ledgeZ != null)
            {
                climbing = true
                climbTarget = ledgeZ
            }
        }
    }
    else
    {
        local fwd = player.GetForwardVector()
        fwd.z = 0
        fwd.Norm()

        if (origin.z < climbTarget + 4.0)
        {
            // rise up the wall
            player.SetVelocity(Vector(0, 0, CLIMB_SPEED))
        }
        else
        {
            // cleared the top: nudge forward onto the ledge and finish
            player.SetVelocity(fwd * FORWARD_PUSH)
            climbing = false
        }
    }

    return 0.02
}

// start the loop on map load
local timer = Entities.CreateByClassname("logic_timer")
timer.__KeyValueFromFloat("RefireTime", 0.02)
EntFireByHandle(timer, "AddOutput", "OnTimer !self:RunScriptCode:ClimbThink():0:-1", 0, null, null)
EntFireByHandle(timer, "Enable", "", 0, null, null)
printl("[ledgeclimb] timer started")

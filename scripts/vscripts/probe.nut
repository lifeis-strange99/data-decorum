// probe.nut - P2CE movement probe, ROUND 2
//
// UNTESTED when written. Round 1 showed that reading/setting player velocity,
// TraceLine and GetButtons all work. This round answers the big open question:
// how often can a script run, and does SetGravity work on the player?
//
// In the in-game console:   script_execute probe
// Then:                     script Probe_Help()

// state for the "EntFire chain" test
Probe_LoopTimes <- []
Probe_LoopZ <- []
Probe_LoopVZ <- []
Probe_LoopDelay <- 0.0167
Probe_LoopPlayer <- null

// state for the "thinkfunction" test (copied into the thinker's own scope)
Probe_Samples <- []
Probe_Z <- []
Probe_VZ <- []
Probe_Done <- false
ProbeRet <- null

// remembered gravity value
Probe_GravityBefore <- 1.0

printl("[probe] round 2 loaded. Type:  script Probe_Help()")

function Probe_Help()
{
    printl("[probe] Type each of these after the word 'script':")
    printl("[probe]   Probe_Info()            player facts (bind it to a key, see instructions)")
    printl("[probe]   Probe_Buttons()         which keys are held")
    printl("[probe]   Probe_Trace()           wall / floor / ceiling scan (face a wall, look level)")
    printl("[probe]   Probe_Globals()         list of global functions")
    printl("[probe]   Probe_Loop(0.0083)      tick-rate test A (also try 0.0167 and 0.1; never 0)")
    printl("[probe]   Probe_Think2(0.0)       tick-rate test B (also try 0.0167 and null)")
    printl("[probe]   Probe_Gravity()         low gravity test, then Probe_GravityReset()")
    printl("[probe]   Probe_Up() / Probe_Dash()   one-shot velocity tests (worked in round 1)")
}

// ---------- helpers ----------

function Probe_V(v)
{
    return "(" + v.x.tointeger() + ", " + v.y.tointeger() + ", " + v.z.tointeger() + ")"
}

function Probe_Player()
{
    local p = null
    try { p = GetPlayer() } catch (e) { p = null }
    if (p == null)
    {
        try { p = Entities.FindByClassname(null, "player") } catch (e) { p = null }
    }
    if (p == null)
        printl("[probe] FAIL could not find the player entity")
    return p
}

// fn receives the player as its only argument (round 1 showed that
// functions defined inside functions can NOT see the outer variables here).
function Probe_Try(label, p, fn)
{
    try
    {
        local r = fn(p)
        printl("[probe] OK   " + label + " = " + r)
    }
    catch (e)
    {
        printl("[probe] FAIL " + label + " -> " + e)
    }
}

function Probe_Forward(p)
{
    try
    {
        local a = p.EyeAngles()
        local pitch = a.x * 0.0174532925
        local yaw = a.y * 0.0174532925
        return Vector(cos(pitch) * cos(yaw), cos(pitch) * sin(yaw), -sin(pitch))
    }
    catch (e) { }
    try { return p.GetForwardVector() } catch (e) { }
    return null
}

function Probe_FlatForward(p)
{
    local f = Probe_Forward(p)
    if (f == null)
        return null
    local flat = Vector(f.x, f.y, 0.0)
    local l = flat.Length()
    if (l < 0.01)
        return null
    return flat * (1.0 / l)
}

// Distance from the feet down to the floor. About 0 when standing on something.
function Probe_GroundDist(p)
{
    local org = p.GetOrigin()
    local f = TraceLine(org + Vector(0.0, 0.0, 4.0), org + Vector(0.0, 0.0, -60.0), p)
    return f * 64.0 - 4.0
}

// ---------- read-only checks ----------

function Probe_Info()
{
    local p = Probe_Player()
    if (p == null)
        return
    printl("[probe] ---- info ----")
    Probe_Try("origin", p, function(e) { return Probe_V(e.GetOrigin()) })
    Probe_Try("eye height above origin", p, function(e) { return (e.EyePosition().z - e.GetOrigin().z).tointeger() })
    Probe_Try("velocity", p, function(e) { return Probe_V(e.GetVelocity()) })
    Probe_Try("horizontal speed", p, function(e) { return e.GetVelocity().Length2D().tointeger() })
    Probe_Try("hull mins", p, function(e) { return Probe_V(e.GetBoundingMins()) })
    Probe_Try("hull maxs", p, function(e) { return Probe_V(e.GetBoundingMaxs()) })
    Probe_Try("view angles (pitch yaw roll)", p, function(e) { return Probe_V(e.EyeAngles()) })
    Probe_Try("move type", p, function(e) { return e.GetMoveType() })
    Probe_Try("gravity scale", p, function(e) { return e.GetGravity() })
    Probe_Try("friction", p, function(e) { return e.GetFriction() })
    Probe_Try("distance from feet to floor", p, function(e) { return Probe_GroundDist(e) })
    Probe_Buttons()
}

function Probe_Globals()
{
    try
    {
        local line = ""
        foreach (k, v in getroottable())
        {
            if (type(v).find("function") != null)
            {
                line += k + " "
                if (line.len() > 150)
                {
                    printl(line)
                    line = ""
                }
            }
        }
        if (line != "")
            printl(line)
    }
    catch (e)
    {
        printl("[probe] FAIL listing globals -> " + e)
    }
}

function Probe_Trace()
{
    local p = Probe_Player()
    if (p == null)
        return
    local eye = p.EyePosition()
    local org = p.GetOrigin()
    local flat = Probe_FlatForward(p)
    if (flat == null)
    {
        printl("[probe] FAIL no usable forward direction (look level, not straight up or down)")
        return
    }
    try
    {
        printl("[probe] distance to floor below feet: " + Probe_GroundDist(p).tointeger() + " units")
        local u = TraceLine(eye, eye + Vector(0.0, 0.0, 128.0), p)
        printl("[probe] distance to ceiling above eyes: " + (u * 128.0).tointeger() + " units (128 means nothing within range)")
        printl("[probe] scan straight ahead, 64 units, at different heights above your feet:")
        for (local h = 8.0; h <= 72.0; h += 16.0)
        {
            local s = org + Vector(0.0, 0.0, h)
            local f = TraceLine(s, s + flat * 64.0, p)
            printl("[probe]   height " + h.tointeger() + ": " + (f * 64.0).tointeger() + " units to something (64 means clear)")
        }
    }
    catch (e)
    {
        printl("[probe] FAIL trace scan -> " + e)
    }
}

function Probe_Buttons()
{
    local p = Probe_Player()
    if (p == null)
        return
    local b = null
    try { b = p.GetButtons() } catch (e) { printl("[probe] FAIL GetButtons -> " + e); return }
    local names = { ATTACK = 1, JUMP = 2, DUCK = 4, FORWARD = 8, BACK = 16, USE = 32, MOVELEFT = 512, MOVERIGHT = 1024, ATTACK2 = 2048, RUN = 4096, RELOAD = 8192, SPEED = 131072, WALK = 262144 }
    local line = ""
    foreach (name, bit in names)
    {
        if ((b & bit) != 0)
            line += name + " "
    }
    printl("[probe] buttons raw = " + b + "   held: " + line)
}

// ---------- one-shot velocity tests (worked in round 1) ----------

function Probe_Up()
{
    local p = Probe_Player()
    if (p == null)
        return
    local v = p.GetVelocity()
    try
    {
        p.SetVelocity(Vector(v.x, v.y, v.z + 350.0))
        printl("[probe] OK   SetVelocity up; reads back " + Probe_V(p.GetVelocity()))
    }
    catch (e)
    {
        printl("[probe] FAIL SetVelocity -> " + e)
    }
}

function Probe_Dash()
{
    local p = Probe_Player()
    if (p == null)
        return
    local flat = Probe_FlatForward(p)
    if (flat == null)
    {
        printl("[probe] FAIL no usable forward direction")
        return
    }
    local v = p.GetVelocity()
    try
    {
        p.SetVelocity(Vector(v.x + flat.x * 450.0, v.y + flat.y * 450.0, v.z + 150.0))
        printl("[probe] OK   SetVelocity forward; reads back " + Probe_V(p.GetVelocity()))
    }
    catch (e)
    {
        printl("[probe] FAIL SetVelocity -> " + e)
    }
}

// ---------- gravity test ----------

function Probe_Gravity()
{
    local p = Probe_Player()
    if (p == null)
        return
    try
    {
        Probe_GravityBefore = p.GetGravity()
        p.SetGravity(0.15)
        printl("[probe] OK   SetGravity(0.15) accepted. Before: " + Probe_GravityBefore + "  now reads: " + p.GetGravity())
        printl("[probe] Now jump. Do you float? When done run:  script Probe_GravityReset()")
    }
    catch (e)
    {
        printl("[probe] FAIL SetGravity -> " + e)
    }
}

function Probe_GravityReset()
{
    local p = Probe_Player()
    if (p == null)
        return
    try
    {
        p.SetGravity(Probe_GravityBefore)
        printl("[probe] OK   gravity put back to " + p.GetGravity())
    }
    catch (e)
    {
        printl("[probe] FAIL SetGravity -> " + e)
    }
}

// ---------- tick-rate summary (used by both tests) ----------

function Probe_Summarize(label, times, zs, vzs)
{
    local n = times.len()
    if (n < 2)
    {
        printl("[probe] RESULT " + label + ": not enough samples (" + n + ")")
        return
    }
    local minGap = 999.0
    local maxGap = 0.0
    local sameFrame = 0
    for (local i = 1; i < n; i++)
    {
        local g = times[i] - times[i - 1]
        if (g < minGap)
            minGap = g
        if (g > maxGap)
            maxGap = g
        if (g < 0.0001)
            sameFrame++
    }
    local avg = (times[n - 1] - times[0]) / (n - 1)
    printl("[probe] RESULT " + label)
    printl("[probe]   calls: " + n + "   average gap: " + avg + " s   shortest: " + minGap + "   longest: " + maxGap + "   calls in the same frame as the previous: " + sameFrame)
    if (avg > 0.0)
        printl("[probe]   about " + (1.0 / avg).tointeger() + " calls per second (one game tick is about 0.0167 s)")

    if (zs.len() > 0)
    {
        local z0 = zs[0]
        local zmax = z0
        foreach (z in zs)
        {
            if (z > zmax)
                zmax = z
        }
        local vmax = -9999.0
        foreach (vz in vzs)
        {
            if (vz > vmax)
                vmax = vz
        }
        printl("[probe]   height gained at peak after the mid-test kick: " + (zmax - z0).tointeger() + " units   highest upward speed seen: " + vmax.tointeger())
    }
}

// ---------- tick-rate test A: a script that re-schedules itself ----------
// Never use a delay of 0: it could make the game loop forever.

function Probe_Loop(delay)
{
    local p = Probe_Player()
    if (p == null)
        return
    if (delay <= 0.0)
    {
        printl("[probe] use a delay above 0, for example 0.0083")
        return
    }
    Probe_LoopTimes = []
    Probe_LoopZ = []
    Probe_LoopVZ = []
    Probe_LoopDelay = delay
    Probe_LoopPlayer = p
    printl("[probe] OK   starting the EntFire chain with delay " + delay + ". Wait about 3 seconds. You get kicked upward partway through.")
    Probe_LoopStep()
}

// Runs inside the player's own script scope, so it only uses ::name for globals.
function Probe_LoopStep()
{
    try
    {
        local p = ::Probe_LoopPlayer
        local n = ::Probe_LoopTimes.len()
        ::Probe_LoopTimes.append(::Time())
        local v = p.GetVelocity()
        ::Probe_LoopZ.append(p.GetOrigin().z)
        ::Probe_LoopVZ.append(v.z)
        if (n == 3)
            p.SetVelocity(::Vector(v.x, v.y, v.z + 300.0))
        if (n + 1 >= 40)
        {
            ::Probe_Summarize("EntFire chain, delay " + ::Probe_LoopDelay, ::Probe_LoopTimes, ::Probe_LoopZ, ::Probe_LoopVZ)
            return
        }
        ::EntFireByHandle(p, "RunScriptCode", "Probe_LoopStep()", ::Probe_LoopDelay, null, null)
    }
    catch (e)
    {
        printl("[probe] FAIL in loop step -> " + e)
    }
}

// ---------- tick-rate test B: an entity with a think function ----------

function Probe_Think2(ret)
{
    local ent = null
    try
    {
        ent = CreateEntityByName("info_target")
        ent.__KeyValueFromString("targetname", "probe_thinker")
        ent.__KeyValueFromString("thinkfunction", "Probe_Tick")
        ent.Spawn()
    }
    catch (e)
    {
        printl("[probe] FAIL could not create/spawn a thinking entity -> " + e)
        return
    }
    try
    {
        ent.ValidateScriptScope()
        local sc = ent.GetScriptScope()
        sc.Probe_Tick <- Probe_Tick
        sc.Probe_Samples <- []
        sc.Probe_Z <- []
        sc.Probe_VZ <- []
        sc.Probe_Done <- false
        sc.ProbeRet <- ret
        printl("[probe] OK   thinker spawned. Wait about 5 seconds. If nothing else prints, this method does not work.")
    }
    catch (e)
    {
        printl("[probe] FAIL could not set up the thinker's script scope -> " + e)
    }
}

// Runs inside the spawned entity's own script scope.
function Probe_Tick()
{
    try
    {
        if (Probe_Done)
            return 3600.0

        local n = Probe_Samples.len()
        if (n == 0)
            printl("[probe] think function is being called")
        Probe_Samples.append(::Time())

        local p = ::Probe_Player()
        if (p != null)
        {
            local v = p.GetVelocity()
            Probe_Z.append(p.GetOrigin().z)
            Probe_VZ.append(v.z)
            if (n == 3)
                p.SetVelocity(::Vector(v.x, v.y, v.z + 300.0))
        }

        if (Probe_Samples.len() >= 30)
        {
            Probe_Done = true
            ::Probe_Summarize("thinkfunction, it returned " + tostring(ProbeRet), Probe_Samples, Probe_Z, Probe_VZ)
            try { ::EntFireByHandle(self, "Kill", "", 0.0, null, null) } catch (e) { }
            return 3600.0
        }
        return ProbeRet
    }
    catch (e)
    {
        printl("[probe] FAIL in think function -> " + e)
        return 3600.0
    }
}

// Parkour: sprint, slide, ledge climb.
const float walk_speed      = 175.0f;
const float sprint_speed    = 320.0f;
const float sprint_accel    = 450.0f;
const float turn_rate       = 6.0f;
const float slide_min_speed = 230.0f;
const float slide_boost     = 1.0f;
const float slide_friction  = 160.0f;
const float slide_end_speed = 110.0f;

bool ledge_enabled          = true;
const float ledge_reach     = 40.0f;
const float ledge_max_up    = 96.0f;
const float ledge_min_up    = 24.0f;
const float climb_speed     = 200.0f;
const float ledge_push      = 120.0f;
const float climb_timeout   = 1.5f;

bool debug = false;

// MASK_PLAYERSOLID isn't in the API dump
const uint PK_MASK_PLAYERSOLID = 0x201400B;
const int PK_COLLISION_GROUP_NONE = 0;

bool running = false;
bool sprintHeld = false;
bool slideHeld = false;
bool slidePressed = false;
bool kFwd = false;
bool kBack = false;
bool kLeft = false;
bool kRight = false;
string state = "idle";
float lastTime = 0.0f;
float sprintSpd = 175.0f;
float slideSpd = 0.0f;
float slideDirX = 0.0f;
float slideDirY = 0.0f;
float climbTarget = 0.0f;
float climbStart = 0.0f;
float climbCool = 0.0f;
float climbDirX = 0.0f;
float climbDirY = 0.0f;

// SetThink only works on script entity classes, as a method
[Entity("pk_thinker")]
class CPKThinker : CBaseEntity
{
    void StartThinking()
    {
        SetThink(ThinkFunc_t(this.OnThink), util::GetCurrentTime() + 0.01f);
    }

    void OnThink()
    {
        if (!running) return;
        PK_Tick();
        SetNextThink(util::GetCurrentTime() + 0.01f);
    }
}

CPKThinker@ pkThinker = null;

CBaseEntity@ PK_GetPlayer()
{
    return EntityList().FindByClassname(null, "player");
}

void PK_Start()
{
    if (running) return;
    if (PK_GetPlayer() is null) { Msgl("[pk] could not find the player"); return; }

    if (pkThinker is null)
    {
        @pkThinker = util::CreateEntityByNameT<CPKThinker>("pk_thinker");
        if (pkThinker is null) { Msgl("[pk] could not create the think entity"); return; }
        pkThinker.Spawn();
    }

    state = "idle";
    climbCool = 0.0f;
    running = true;
    pkThinker.StartThinking();
    Msgl("[pk] started");
}

void PK_Stop()
{
    running = false;
    sprintHeld = false;
    slideHeld = false;
    Msgl("[pk] stopped");
}

[ServerCommand("pk_toggle", "Start or stop parkour")]
void PK_ToggleCmd(const CommandArgs@ args) { if (running) PK_Stop(); else PK_Start(); }

[ServerCommand("pk_start", "Start parkour")]
void PK_StartCmd(const CommandArgs@ args) { PK_Start(); }

[ServerCommand("pk_stop", "Stop parkour")]
void PK_StopCmd(const CommandArgs@ args) { PK_Stop(); }

[ServerCommand("pk_debug", "Print state changes")]
void PK_DebugCmd(const CommandArgs@ args) { debug = !debug; Msgl("[pk] debug " + (debug ? "on" : "off")); }

[ServerCommand("pk_sprint_on", "")]
void PK_SprintOn(const CommandArgs@ args) { sprintHeld = true; }
[ServerCommand("pk_sprint_off", "")]
void PK_SprintOff(const CommandArgs@ args) { sprintHeld = false; }

[ServerCommand("pk_slide_on", "")]
void PK_SlideOn(const CommandArgs@ args) { slideHeld = true; slidePressed = true; }
[ServerCommand("pk_slide_off", "")]
void PK_SlideOff(const CommandArgs@ args) { slideHeld = false; }

[ServerCommand("pk_fwd_on", "")]
void PK_FwdOn(const CommandArgs@ args) { kFwd = true; }
[ServerCommand("pk_fwd_off", "")]
void PK_FwdOff(const CommandArgs@ args) { kFwd = false; }
[ServerCommand("pk_back_on", "")]
void PK_BackOn(const CommandArgs@ args) { kBack = true; }
[ServerCommand("pk_back_off", "")]
void PK_BackOff(const CommandArgs@ args) { kBack = false; }
[ServerCommand("pk_left_on", "")]
void PK_LeftOn(const CommandArgs@ args) { kLeft = true; }
[ServerCommand("pk_left_off", "")]
void PK_LeftOff(const CommandArgs@ args) { kLeft = false; }
[ServerCommand("pk_right_on", "")]
void PK_RightOn(const CommandArgs@ args) { kRight = true; }
[ServerCommand("pk_right_off", "")]
void PK_RightOff(const CommandArgs@ args) { kRight = false; }

// World Z of a grabbable ledge, or -99999
float PK_FindLedge(CBaseEntity@ p, float fx, float fy)
{
    Vector org = p.GetAbsOrigin();
    trace_t tr;

    Vector chest(org.x, org.y, org.z + 48.0f);
    Vector wallEnd(chest.x + fx * ledge_reach, chest.y + fy * ledge_reach, chest.z);
    util::TraceLine(chest, wallEnd, PK_MASK_PLAYERSOLID, p, PK_COLLISION_GROUP_NONE, tr);
    if (tr.fraction >= 1.0f) return -99999.0f;
    float wallHit = tr.fraction;

    float span = ledge_max_up + 16.0f;
    float topZ = org.z + span;
    float px = org.x + fx * (ledge_reach * wallHit + 8.0f);
    float py = org.y + fy * (ledge_reach * wallHit + 8.0f);
    util::TraceLine(Vector(px, py, topZ), Vector(px, py, topZ - span), PK_MASK_PLAYERSOLID, p, PK_COLLISION_GROUP_NONE, tr);
    if (tr.fraction >= 1.0f) return -99999.0f;

    float ledgeZ = topZ - span * tr.fraction;
    float rise = ledgeZ - org.z;
    if (rise < ledge_min_up || rise > ledge_max_up) return -99999.0f;
    return ledgeZ;
}

void PK_Tick()
{
    float now = util::GetCurrentTime();
    float dt = now - lastTime;
    if (dt > 0.1f) dt = 0.1f;
    if (dt < 0.0f) dt = 0.0f;
    lastTime = now;

    CBaseEntity@ p = PK_GetPlayer();
    if (p !is null) PK_Update(p, dt, now);
}

void PK_Update(CBaseEntity@ p, float dt, float now)
{
    Vector v = p.GetAbsVelocity();
    Vector org = p.GetAbsOrigin();
    float hs = v.Length2D();
    bool grounded = p.IsOnGround();
    bool active = (p.GetMoveType() == MOVETYPE_WALK) && (p.GetHealth() > 0);

    float yaw = p.EyeAngles().y * 0.0174532925f;
    float fx = cos(yaw);
    float fy = sin(yaw);

    float mf = 0.0f;
    float ms = 0.0f;
    if (kFwd) mf += 1.0f;
    if (kBack) mf -= 1.0f;
    if (kRight) ms += 1.0f;
    if (kLeft) ms -= 1.0f;
    float wx = fx * mf + fy * ms;
    float wy = fy * mf - fx * ms;
    float wl = sqrt(wx * wx + wy * wy);
    if (wl > 0.01f) { wx /= wl; wy /= wl; }

    string newState = "idle";

    if (active)
    {
        if (state == "climb")
        {
            if (now - climbStart > climb_timeout)
            {
                climbCool = now + 0.5f;
                newState = "air";
            }
            else if (org.z < climbTarget + 4.0f)
            {
                p.SetAbsVelocity(Vector(0.0f, 0.0f, climb_speed));
                newState = "climb";
            }
            else
            {
                p.SetAbsVelocity(Vector(climbDirX * ledge_push, climbDirY * ledge_push, 0.0f));
                climbCool = now + 0.4f;
                newState = "air";
            }
        }
        else if (!grounded)
        {
            newState = "air";
            if (ledge_enabled && v.z > 0.0f && now >= climbCool)
            {
                float lz = PK_FindLedge(p, fx, fy);
                if (lz > -99000.0f)
                {
                    newState = "climb";
                    climbTarget = lz;
                    climbStart = now;
                    climbDirX = fx;
                    climbDirY = fy;
                }
            }
        }
        else if (state == "slide" && slideHeld && slideSpd > slide_end_speed)
        {
            newState = "slide";
            slideSpd -= slide_friction * dt;
            p.SetAbsVelocity(Vector(slideDirX * slideSpd, slideDirY * slideSpd, v.z));
        }
        else if (slidePressed && hs >= slide_min_speed)
        {
            newState = "slide";
            slideDirX = v.x / hs;
            slideDirY = v.y / hs;
            slideSpd = hs * slide_boost;
        }
        else if (sprintHeld && !slideHeld && mf > 0.0f)
        {
            newState = "sprint";
            if (state != "sprint")
            {
                sprintSpd = hs;
                if (sprintSpd < walk_speed) sprintSpd = walk_speed;
            }
            if (sprintSpd < sprint_speed)
            {
                sprintSpd += sprint_accel * dt;
                if (sprintSpd > sprint_speed) sprintSpd = sprint_speed;
            }

            float dx = wx;
            float dy = wy;
            if (hs > 20.0f)
            {
                dx = v.x / hs;
                dy = v.y / hs;
                float k = turn_rate * dt;
                if (k > 1.0f) k = 1.0f;
                dx = dx + (wx - dx) * k;
                dy = dy + (wy - dy) * k;
                float dl = sqrt(dx * dx + dy * dy);
                if (dl > 0.001f) { dx /= dl; dy /= dl; }
                else { dx = wx; dy = wy; }
            }
            p.SetAbsVelocity(Vector(dx * sprintSpd, dy * sprintSpd, v.z));
        }
    }

    slidePressed = false;

    if (newState != state)
    {
        if (debug) Msgl("[pk] " + state + " -> " + newState + " (" + int(hs) + ")");
        state = newState;
    }
}

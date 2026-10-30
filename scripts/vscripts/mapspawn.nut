// scripts/vscripts/mapspawn.nut
// Only enable ledge climbing on the maps listed here

local ledgeMaps = [
    "1793344624",
    "1793344335",
]

local current = GetMapName().tolower()
printl("[ledgeclimb] map is: " + current)

local enabled = false
foreach (name in ledgeMaps)
{
    if (current == name.tolower())
    {
        enabled = true
        break
    }
}

if (enabled)
{
    printl("[ledgeclimb] enabled")
    IncludeScript("ledgeclimb")
}
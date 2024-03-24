local json = require('json')

-- Game grid dimensions
Width = 40  -- Width of the grid
Height = 40 -- Height of the grid
Range = 1   -- The distance for blast effect

-- Player energy settings
MaxEnergy = 100  -- Maximum energy a player can have
EnergyPerSec = 1 -- Energy gained per second

-- Attack settings
AverageMaxStrengthHitsToKill = 3 -- Average number of hits to eliminate a player

-- Number of Barriers
NumBarriers = 10

function initBarriers()
    for i = 1, NumBarriers do
        if math.random() < 0.5 then
            -- Horizontal barrier
            local y = math.random(1, Height)
            local startX = math.random(1, Width - 2)
            local endX = math.random(1, Width - 2)
            table.insert(Barriers, { start = { x = startX, y = y }, endPos = { x = endX, y = y } })
        else
            -- Vertical barrier
            local x = math.random(1, Width)
            local startY = math.random(1, Height - 2)
            local endY = math.random(1, Height - 2)
            table.insert(Barriers, { start = { x = x, y = startY }, endPos = { x = x, y = endY } })
        end
    end
end

function playerInitState()
    local player
    local isValidPosition = false
    local posX = math.random(1, Width)
    local posY = math.random(1, Height)

    while not isValidPosition do
        isValidPosition = true

        for _, barrier in ipairs(Barriers) do
            if barrier.start.x == barrier.endPos.x then
                -- Vertical barrier
                if posX == barrier.start.x and posY >= math.min(barrier.start.y, barrier.endPos.y) and posY <= math.max(barrier.start.y, barrier.endPos.y) then
                    isValidPosition = false
                    break
                end
            elseif barrier.start.y == barrier.endPos.y then
                -- Horizontal barrier
                if posY == barrier.start.y and posX >= math.min(barrier.start.x, barrier.endPos.x) and posX <= math.max(barrier.start.x, barrier.endPos.x) then
                    isValidPosition = false
                    break
                end
            end
        end
    end

    if isValidPosition then
        player = {
            x = posX,
            y = posY,
            health = 100,
            energy = 0
        }
    end

    return player
end

-- Helper function to check if two line segments intersect
function linesIntersect(aStart, aEnd, bStart, bEnd)
    local function ccw(A, B, C)
        return (C.y - A.y) * (B.x - A.x) > (B.y - A.y) * (C.x - A.x)
    end

    local function intersect(A, B, C, D)
        return ccw(A, C, D) ~= ccw(B, C, D) and ccw(A, B, C) ~= ccw(A, B, D)
    end

    return intersect(aStart, aEnd, bStart, bEnd)
end

function isMoveValid(playerPos, newPos)
    for _, barrier in ipairs(Barriers) do
        if linesIntersect(playerPos, newPos, barrier.start, barrier.endPos) then
            return false -- The path intersects with a barrier, move is invalid
        end
    end
    return true -- No intersections, move is valid
end

-- Function to incrementally increase player's energy
-- Called periodically to update player energy
function onTick()
    if GameMode ~= "Playing" then return end -- Only active during "Playing" state

    if LastTick == undefined then LastTick = Now end

    local Elapsed = Now - LastTick
    if Elapsed >= 1000 then -- Actions performed every second
        for player, state in pairs(Players) do
            local newEnergy = math.floor(math.min(MaxEnergy, state.energy + (Elapsed * EnergyPerSec // 2000)))
            state.energy = newEnergy
        end
        LastTick = Now
    end
end

-- Handles player movement
-- @param msg: Message request sent by player with movement direction and player info
function move(msg)
    local playerToMove = msg.From
    local direction = msg.Tags.Direction

    local directionMap = {
        Up = { x = 0, y = -1 },
        Down = { x = 0, y = 1 },
        Left = { x = -1, y = 0 },
        Right = { x = 1, y = 0 },
        UpRight = { x = 1, y = -1 },
        UpLeft = { x = -1, y = -1 },
        DownRight = { x = 1, y = 1 },
        DownLeft = { x = -1, y = 1 }
    }

    -- calculate and update new coordinates
    if directionMap[direction] then
        local newX = Players[playerToMove].x + directionMap[direction].x
        local newY = Players[playerToMove].y + directionMap[direction].y

        local isValidMove = isMoveValid({ x = Players[playerToMove].x, y = Players[playerToMove].y },
            { x = newX, y = newY })

        if not isValidMove then
            ao.send({ Target = playerToMove, Action = "Move-Failed", Reason = "Movement blocked by barrier." })
            return
        end

        -- updates player coordinates while checking for grid boundaries
        Players[playerToMove].x = (newX - 1) % Width + 1
        Players[playerToMove].y = (newY - 1) % Height + 1

        announce("Player-Moved",
            playerToMove .. " moved to " .. Players[playerToMove].x .. "," .. Players[playerToMove].y .. ".")
    else
        ao.send({ Target = playerToMove, Action = "Move-Failed", Reason = "Invalid direction." })
    end
    onTick()
end

-- Handles player attacks
-- @param msg: Message request sent by player with attack info and player state
function attack(msg)
    local player = msg.From
    local attackEnergy = tonumber(msg.Tags.AttackEnergy)

    -- get player coordinates
    local x = Players[player].x
    local y = Players[player].y

    -- check if player has enough energy to attack
    if Players[player].energy < attackEnergy then
        ao.send({ Target = player, Action = "Attack-Failed", Reason = "Not enough energy." })
        return
    end

    -- update player energy and calculate damage
    Players[player].energy = Players[player].energy - attackEnergy
    local damage = math.floor((math.random() * 2 * attackEnergy) * (1 / AverageMaxStrengthHitsToKill))

    announce("Attack", player .. " has launched a " .. damage .. " damage attack from " .. x .. "," .. y .. "!")

    -- check if any player is within range and update their status
    for target, state in pairs(Players) do
        if target ~= player and inRange(x, y, state.x, state.y, Range) then
            local newHealth = state.health - damage
            if newHealth <= 0 then
                eliminatePlayer(target, player)
            else
                Players[target].health = newHealth
                ao.send({ Target = target, Action = "Hit", Damage = tostring(damage), Health = tostring(newHealth) })
                ao.send({
                    Target = player,
                    Action = "Successful-Hit",
                    Recipient = target,
                    Damage = tostring(damage),
                    Health =
                        tostring(newHealth)
                })
            end
        end
    end
end

-- Helper function to check if a target is within range
-- @param x1, y1: Coordinates of the attacker
-- @param x2, y2: Coordinates of the potential target
-- @param range: Attack range
-- @return Boolean indicating if the target is within range
function inRange(x1, y1, x2, y2, range)
    return x2 >= (x1 - range) and x2 <= (x1 + range) and y2 >= (y1 - range) and y2 <= (y1 + range)
end

function generateMapString()
    -- Initialize map with 0s
    local map = {}
    for y = 1, Height do
        map[y] = {}
        for x = 1, Width do
            map[y][x] = 0
        end
    end

    -- Mark barriers on the map
    for _, barrier in ipairs(Barriers) do
        -- Simplified barrier plotting: Direct line, horizontal or vertical only
        if barrier.start.x == barrier.endPos.x then
            -- Vertical barrier
            for y = math.min(barrier.start.y, barrier.endPos.y), math.max(barrier.start.y, barrier.endPos.y) do
                map[y][barrier.start.x] = 1
            end
        elseif barrier.start.y == barrier.endPos.y then
            -- Horizontal barrier
            for x = math.min(barrier.start.x, barrier.endPos.x), math.max(barrier.start.x, barrier.endPos.x) do
                map[barrier.start.y][x] = 1
            end
        end
    end

    -- Convert map to string
    local mapString = ""
    for y = 1, Height do
        for x = 1, Width do
            mapString = mapString .. map[y][x]
        end
        if y < Height then
            mapString = mapString .. "\n"
        end
    end

    return mapString
end

-- HANDLERS: Game state management for AO-Effect

Handlers.add("PlayerMove", Handlers.utils.hasMatchingTag("Action", "PlayerMove"), move)

Handlers.add("PlayerAttack", Handlers.utils.hasMatchingTag("Action", "PlayerAttack"), attack)

Handlers.add("GetMap", Handlers.utils.hasMatchingTag("Action", "GetMap"),
    function(msg)
        local mapString = generateMapString()
        Handlers.utils.reply(tostring(mapString))(msg)
    end
)

Handlers.add("GetBarriers", Handlers.utils.hasMatchingTag("Action", "GetBarriers"),
    function(msg)
        Handlers.utils.reply(json.encode(Barriers))(msg)
    end
)

Handlers.add("GetPlayer", Handlers.utils.hasMatchingTag("Action", "GetPlayer"),
    function(msg)
        Handlers.utils.reply(json.encode(Players[msg.From]))(msg)
    end
)

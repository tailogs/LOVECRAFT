-- ============================================================================
-- CONSOLIDATED LOVECRAFT GAME - All modules merged into one file
-- Water/Fluids removed
-- ============================================================================

-- ============================================================================
-- GLOBAL ALIASES & SHARED VARIABLES
-- ============================================================================
local mabs = math.abs
local mtan = math.tan
local mrad = math.rad
local mfloor = math.floor
local mmax = math.max
local mmin = math.min
local msin = math.sin
local mcos = math.cos
local msqrt = math.sqrt

-- ============================================================================
-- RENDERER MODULE
-- ============================================================================
local Renderer = {}

function Renderer.getMatrix(cam)
    local ay = -cam.yaw - 1.57079632679
    local ap = -cam.pitch
    return {
        cy = math.cos(ay), sy = math.sin(ay),
        cp = math.cos(ap), sp = math.sin(ap)
    }
end

function Renderer.transform(x, y, z, cam, m)
    local dx, dy, dz = x - cam.x, y - cam.y, z - cam.z
    local tx = dx * m.cy - dz * m.sy
    local tz = dx * m.sy + dz * m.cy
    local ty = dy * m.cp - tz * m.sp
    tz = dy * m.sp + tz * m.cp
    return tx, ty, tz
end

-- ============================================================================
-- PARTICLE MODULE
-- ============================================================================
local Particle = {}
Particle.__index = Particle

function Particle.new(x, y, z)
    local self = setmetatable({}, Particle)
    self.x = x
    self.y = y
    self.z = z
    self.vx = 0
    self.vy = 0
    self.vz = 0
    self.life = 1.0
    self.maxLife = 1.0
    return self
end

function Particle:update(dt)
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt
    self.z = self.z + self.vz * dt
    self.life = self.life - dt / self.maxLife
end

function Particle:isAlive()
    return self.life > 0
end

-- ============================================================================
-- WORLD MODULE
-- ============================================================================
local World = {
    data = {},
    width = 512,
    height = 64,
    depth = 512,
    seed = 0,
    offsetX = 0,
    offsetZ = 0,
    types = {
        [1] = { name = "grass", 
            colors = {
                {0.35,0.75,0.25}, {0.35,0.75,0.25},
                {0.30,0.65,0.20}, {0.30,0.65,0.20},
                {0.40,0.85,0.30}, {0.25,0.45,0.15}
            }
        },
        [2] = { name = "wood",
            colors = {
                {0.40,0.30,0.15}, {0.40,0.30,0.15},
                {0.38,0.28,0.13}, {0.38,0.28,0.13},
                {0.42,0.32,0.17}, {0.35,0.25,0.12}
            }
        },
        [3] = { name = "leaf",
            colors = {
                {0.10,0.45,0.05}, {0.10,0.45,0.05},
                {0.08,0.40,0.04}, {0.08,0.40,0.04},
                {0.12,0.50,0.06}, {0.06,0.35,0.03}
            }
        },
        [4] = { name = "stone",
            colors = {
                {0.55,0.55,0.55}, {0.55,0.55,0.55},
                {0.50,0.50,0.50}, {0.50,0.50,0.50},
                {0.60,0.60,0.60}, {0.45,0.45,0.45}
            }
        },
        [5] = { name = "dirt",
            colors = {
                {0.45,0.35,0.20}, {0.45,0.35,0.20},
                {0.42,0.32,0.18}, {0.42,0.32,0.18},
                {0.48,0.38,0.22}, {0.40,0.30,0.16}
            }
        },
        [6] = { name = "sand",
            colors = {
                {0.95,0.90,0.60}, {0.95,0.90,0.60},
                {0.90,0.85,0.55}, {0.90,0.85,0.55},
                {1.00,0.95,0.65}, {0.85,0.80,0.50}
            }
        },
        [8] = { name = "snow",
            colors = {
                {0.95,0.95,1.00}, {0.95,0.95,1.00},
                {0.90,0.90,0.95}, {0.90,0.90,0.95},
                {1.00,1.00,1.05}, {0.85,0.85,0.90}
            }
        },
        [9] = { name = "gravel",
            colors = {
                {0.60,0.60,0.60}, {0.60,0.60,0.60},
                {0.55,0.55,0.55}, {0.55,0.55,0.55},
                {0.65,0.65,0.65}, {0.50,0.50,0.50}
            }
        },
        [10]= { name = "clay",
            colors = {
                {0.70,0.60,0.50}, {0.70,0.60,0.50},
                {0.65,0.55,0.45}, {0.65,0.55,0.45},
                {0.75,0.65,0.55}, {0.60,0.50,0.40}
            }
        },
        [11]= { name = "snow_leaf",
            colors = {
                {0.85,0.90,1.00}, {0.85,0.90,1.00},
                {0.80,0.85,0.95}, {0.80,0.85,0.95},
                {0.90,0.95,1.05}, {0.75,0.80,0.90}
            }
        },
        [99]= { name = "world_border",
            colors = {
                {0.50,0.50,0.80}, {0.50,0.50,0.80},
                {0.45,0.45,0.75}, {0.45,0.45,0.75},
                {0.60,0.60,0.90}, {0.40,0.40,0.70}
            }
        },
    },
    treePositions = {}
}

local SEA_LEVEL = 16
local BEACH_LEVEL = 18
local SNOW_THRESHOLD = 0.25

local function getFractalNoise(x, z, octaves, persistence, scale)
    local total = 0
    local frequency = scale
    local amplitude = 1
    local maxValue = 0
    for i = 1, octaves do
        total = total + love.math.noise(x * frequency, z * frequency) * amplitude
        maxValue = maxValue + amplitude
        amplitude = amplitude * persistence
        frequency = frequency * 2
    end
    return total / maxValue
end

function World.getHeight(x, z)
    local nx = (x + World.offsetX)
    local nz = (z + World.offsetZ)

    local m_noise = getFractalNoise(nx, nz, 4, 0.5, 0.002)
    local mountains = math.pow(m_noise, 3.2) * World.height * 1.3

    local plains = getFractalNoise(nx, nz, 3, 0.5, 0.015) * 7

    local h = SEA_LEVEL + mountains + plains
    return math.max(1, math.min(World.height, math.floor(h)))
end

local function placeTree(x, z, minX, maxX, minZ, maxZ)
    if x < minX+5 or x > maxX-5 or z < minZ+5 or z > maxZ-5 then return end

    local g = World.getHeight(x, z)
    if not World.data[x] or not World.data[x][g] then return end

    local ground_id = World.data[x][g][z]
    if ground_id ~= 1 and ground_id ~= 5 and ground_id ~= 8 then return end
    if g < SEA_LEVEL + 2 then return end

    local nx, nz = x + World.offsetX, z + World.offsetZ
    local temp = love.math.noise(nx * 0.006, nz * 0.006) - (g / World.height) * 0.4
    local isSnowy = (temp < SNOW_THRESHOLD)

    local treeH = isSnowy and math.random(7, 11) or math.random(5, 8)
    local leafType = isSnowy and 11 or 3

    for y = g + 1, g + treeH do
        if not World.data[x][y] then World.data[x][y] = {} end
        World.data[x][y][z] = 2
    end

    local leaves_start_y = isSnowy and (g + 3) or (g + treeH - 2)
    local top_y = g + treeH + 2

    for ly = leaves_start_y, top_y do
        if not World.data[x][ly] then World.data[x][ly] = {} end

        local r = 0
        local y_progress = (ly - leaves_start_y) / (top_y - leaves_start_y)

        if isSnowy then
            r = math.max(0, math.floor((1 - y_progress) * 3.5))
        else
            if y_progress < 0.3 then r = 2
            elseif y_progress < 0.7 then r = 3
            else r = 1 end
        end

        if r > 0 then
            for lx = -r, r do
                for lz = -r, r do
                    if lx*lx + lz*lz <= r*r + math.random(-1, 0) then
                        local wx, wy, wz = x + lx, ly, z + lz
                        if not World.data[wx] then World.data[wx] = {} end
                        if not World.data[wx][wy] then World.data[wx][wy] = {} end

                        if not World.data[wx][wy][wz] then
                            World.data[wx][wy][wz] = leafType
                        end
                    end
                end
            end
        end
    end
    table.insert(World.treePositions, {x = x, z = z})
end

function World.isWithinBounds(x, y, z)
    local minX = -math.floor(World.width / 2)
    local maxX = math.floor(World.width / 2)
    local minZ = -math.floor(World.depth / 2)
    local maxZ = math.floor(World.depth / 2)
    return x >= minX and x <= maxX and y >= 1 and y <= World.height and z >= minZ and z <= maxZ
end

function World.generate(seed)
    World.seed = seed or os.time()
    math.randomseed(World.seed)

    World.offsetX = math.random(-100000, 100000)
    World.offsetZ = math.random(-100000, 100000)

    World.data = {}

    local minX = -math.floor(World.width / 2)
    local maxX = math.floor(World.width / 2)
    local minZ = -math.floor(World.depth / 2)
    local maxZ = math.floor(World.depth / 2)

    for x = minX, maxX do
        World.data[x] = {}
        for z = minZ, maxZ do
            local g = World.getHeight(x, z)

            local nx, nz = x + World.offsetX, z + World.offsetZ
            local temp_noise = love.math.noise(nx * 0.006, nz * 0.006)
            local humid_noise = love.math.noise((nx + 500) * 0.006, (nz + 500) * 0.006)
            local current_temp = temp_noise - (g / World.height) * 0.4

            for y = 1, math.max(g, SEA_LEVEL) do
                World.data[x][y] = World.data[x][y] or {}
                local id = nil

                if y <= g then
                    if y == g then
                        if current_temp < SNOW_THRESHOLD then id = 8
                        elseif current_temp > 0.7 and humid_noise < 0.35 then id = 6
                        elseif y <= BEACH_LEVEL then id = 6
                        else id = 1 end
                    elseif y > g - 3 then
                        if current_temp < SNOW_THRESHOLD then id = 4
                        elseif current_temp > 0.7 and humid_noise < 0.35 then id = 6
                        else id = 5 end
                    else
                        id = 4
                    end
                end

                if id then World.data[x][y][z] = id end
            end
        end
    end

    for i = 1, 150 do
        placeTree(math.random(minX, maxX), math.random(minZ, maxZ), minX, maxX, minZ, maxZ)
    end

    -- World barriers
    local barrierId = 99
    local barrierTopY = 200

    for z = minZ-1, maxZ+1 do
        for y = 1, barrierTopY do
            if not World.data[minX-1] then World.data[minX-1] = {} end
            if not World.data[minX-1][y] then World.data[minX-1][y] = {} end
            World.data[minX-1][y][z] = barrierId

            if not World.data[maxX+1] then World.data[maxX+1] = {} end
            if not World.data[maxX+1][y] then World.data[maxX+1][y] = {} end
            World.data[maxX+1][y][z] = barrierId
        end
    end

    for x = minX-1, maxX+1 do
        for y = 1, barrierTopY do
            if not World.data[x] then World.data[x] = {} end
            if not World.data[x][y] then World.data[x][y] = {} end
            World.data[x][y][minZ-1] = barrierId

            if not World.data[x] then World.data[x] = {} end
            if not World.data[x][y] then World.data[x][y] = {} end
            World.data[x][y][maxZ+1] = barrierId
        end
    end

    for x = minX-1, maxX+1 do
        for z = minZ-1, maxZ+1 do
            if not World.data[x] then World.data[x] = {} end
            if not World.data[x][0] then World.data[x][0] = {} end
            World.data[x][0][z] = barrierId
        end
    end

    for x = minX-1, maxX+1 do
        for z = minZ-1, maxZ+1 do
            if not World.data[x] then World.data[x] = {} end
            if not World.data[x][barrierTopY+1] then World.data[x][barrierTopY+1] = {} end
            World.data[x][barrierTopY+1][z] = barrierId
        end
    end
end

function World.isFullySurrounded(x, y, z)
    local d = World.data
    local function isOpaque(bx, by, bz)
        if not d[bx] or not d[bx][by] or not d[bx][by][bz] then return false end
        local id = d[bx][by][bz]
        local t = World.types[id]
        if not t then return false end
        return true
    end

    return isOpaque(x+1,y,z) and isOpaque(x-1,y,z) and
           isOpaque(x,y+1,z) and isOpaque(x,y-1,z) and
           isOpaque(x,y,z+1) and isOpaque(x,y,z-1)
end

function World.getBlock(x, y, z)
    local ix, iy, iz = math.floor(x + 0.5), math.floor(y + 0.5), math.floor(z + 0.5)
    if World.data[ix] and World.data[ix][iy] and World.data[ix][iy][iz] then
        return World.data[ix][iy][iz]
    end
    return nil
end

World.treePositions = {}

-- ============================================================================
-- PLAYER MODULE
-- ============================================================================
local Player = {
    x = 0, y = 0, z = 0,
    yaw = 0, pitch = 0,
    velocityV = 0,
    onGround = false,
    config = {
        speed = 6,
        sens = 0.002,
        gravity = 20,
        jumpPower = 7.5,
        height = 1.6, 
        collisionHeight = 1.75,
        radius = 0.3
    }
}

local function isBlocked(x, y, z)
    if not World.isWithinBounds(x, y, z) then
        return true
    end
    local block = World.getBlock(x, y, z)
    if block == nil then return false end
    
    return true
end

local function checkWorldCollision(x, y, z, conf)
    local r = conf.radius
    local off = 0.05
    local px = {x - r + off, x + r - off}
    local pz = {z - r + off, z + r - off}
    local py = {y - 1.58, y - 0.8, y - 0.1} 

    for i = 1, 2 do
        for j = 1, 2 do
            for k = 1, 3 do
                if isBlocked(px[i], py[k], pz[j]) then return true end
            end
        end
    end
    return false
end

function Player.update(dt)
    local conf = Player.config
    local fX, fZ = math.cos(Player.yaw), math.sin(Player.yaw)
    local rX, rZ = -math.sin(Player.yaw), math.cos(Player.yaw)
    local moveX, moveZ = 0, 0

    if love.keyboard.isDown("w") then moveX, moveZ = moveX - fX, moveZ - fZ end
    if love.keyboard.isDown("s") then moveX, moveZ = moveX + fX, moveZ + fZ end
    if love.keyboard.isDown("a") then moveX, moveZ = moveX - rX, moveZ - rZ end
    if love.keyboard.isDown("d") then moveX, moveZ = moveX + rX, moveZ + rZ end

    if moveX ~= 0 or moveZ ~= 0 then
        local mag = math.sqrt(moveX*moveX + moveZ*moveZ)
        local dx = (moveX/mag) * conf.speed * dt
        local dz = (moveZ/mag) * conf.speed * dt
        if not checkWorldCollision(Player.x + dx, Player.y, Player.z, conf) then Player.x = Player.x + dx end
        if not checkWorldCollision(Player.x, Player.y, Player.z + dz, conf) then Player.z = Player.z + dz end
    end

    Player.velocityV = Player.velocityV - conf.gravity * dt
    local nextY = Player.y + Player.velocityV * dt

    if Player.velocityV > 0 then
        if not checkWorldCollision(Player.x, nextY, Player.z, conf) then
            Player.y = nextY
        else
            Player.velocityV = 0 
        end
        Player.onGround = false
    else
        local footY = nextY - 1.6
        local collision = false
        local r = conf.radius - 0.05
        local pts = {{Player.x-r,Player.z-r},{Player.x+r,Player.z-r},{Player.x-r,Player.z+r},{Player.x+r,Player.z+r},{Player.x,Player.z}}
        
        for _, p in ipairs(pts) do
            if isBlocked(p[1], footY, p[2]) then
                collision = true
                break
            end
        end

        if collision then
            local iy = math.floor(footY + 0.5)
            Player.y = iy + 0.499 + conf.height
            Player.velocityV = 0
            Player.onGround = true
            if love.keyboard.isDown("space") then
                Player.velocityV = conf.jumpPower
                Player.onGround = false
                Player.y = Player.y + 0.1
            end
        else
            Player.y = nextY
            Player.onGround = false
        end
    end
end

function Player.spawn(world)
    Player.x = 0
    Player.z = 0
    local groundY = world.getHeight(0, 0)
    Player.y = groundY + Player.config.height + 1
    Player.velocityV = 0
end

-- ============================================================================
-- INTERACT MODULE
-- ============================================================================
local Interact = {
    selectedBlock = nil,
    placePosition = nil,
    maxDist = 6
}

local function isSolid(id)
    if not id then return false end
    return true
end

function Interact.update(player, world)
    Interact.selectedBlock = nil
    Interact.placePosition = nil
    
    local lookX = -math.cos(player.yaw) * math.cos(player.pitch)
    local lookY = -math.sin(player.pitch)
    local lookZ = -math.sin(player.yaw) * math.cos(player.pitch)
    
    local px, py, pz
    
    for i = 0, Interact.maxDist, 0.05 do
        local tx = math.floor(player.x + lookX * i + 0.5)
        local ty = math.floor(player.y + lookY * i + 0.5)
        local tz = math.floor(player.z + lookZ * i + 0.5)
        
        local blockId = world.data[tx] and world.data[tx][ty] and world.data[tx][ty][tz]
        
        if isSolid(blockId) then
            Interact.selectedBlock = {x = tx, y = ty, z = tz}
            if px then 
                Interact.placePosition = {x = px, y = py, z = pz} 
            end
            return 
        end
        
        px, py, pz = tx, ty, tz
    end
end

function Interact.breakBlock(world)
    if Interact.selectedBlock then
        local b = Interact.selectedBlock
        local id = world.data[b.x] and world.data[b.x][b.y] and world.data[b.x][b.y][b.z]
        if id and id ~= 99 then
            world.data[b.x][b.y][b.z] = nil
        end
    end
end

function Interact.placeBlock(world)
    if Interact.placePosition then
        local p = Interact.placePosition
        local existing = world.data[p.x] and world.data[p.x][p.y] and world.data[p.x][p.y][p.z]
        
        if existing == 99 then
            return
        end
        
        if not world.isWithinBounds(p.x, p.y, p.z) then
            return
        end
        
        if existing == nil then
            if not world.data[p.x] then world.data[p.x] = {} end
            if not world.data[p.x][p.y] then world.data[p.x][p.y] = {} end
            world.data[p.x][p.y][p.z] = 4
        end
    end
end

-- ============================================================================
-- BARRIER MODULE
-- ============================================================================
local Barrier = {}
local barrierParticles = {}
local maxBarrierParticles = 200

local function spawnBarrierParticle(x, y, z)
    -- Adaptive barrier particle spawning
    if #barrierParticles >= mfloor(maxBarrierParticles * particleLOD) then return end
    
    table.insert(barrierParticles, {
        x = x, y = y, z = z,
        vx = (math.random() - 0.5) * 2,
        vy = math.random() * 1.5,
        vz = (math.random() - 0.5) * 2,
        life = 0.7,
        maxLife = 0.7
    })
end

function Barrier.update(dt)
    for i = #barrierParticles, 1, -1 do
        local p = barrierParticles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.z = p.z + p.vz * dt
        p.life = p.life - dt
        if p.life <= 0 then
            table.remove(barrierParticles, i)
        end
    end

    if not Player then return end

    local minX = -math.floor(World.width / 2) - 1
    local maxX = math.floor(World.width / 2) + 1
    local minZ = -math.floor(World.depth / 2) - 1
    local maxZ = math.floor(World.depth / 2) + 1

    local px, pz = Player.x, Player.z
    local distToBarrier = math.min(
        math.abs(px - minX),
        math.abs(px - maxX),
        math.abs(pz - minZ),
        math.abs(pz - maxZ)
    )

    if distToBarrier < 2 then
        local wallX, wallZ = nil, nil
        if math.abs(px - minX) == distToBarrier then
            wallX = minX
            local zStart = math.max(minZ-1, pz - 8)
            local zEnd = math.min(maxZ+1, pz + 8)
            for _ = 1, math.random(2, mfloor(6 * particleLOD)) do
                local z = math.random(zStart, zEnd)
                local y = Player.y + (math.random() - 0.5) * 3
                spawnBarrierParticle(wallX + (math.random() - 0.5) * 1.5, y, z)
            end
        elseif math.abs(px - maxX) == distToBarrier then
            wallX = maxX
            local zStart = math.max(minZ-1, pz - 8)
            local zEnd = math.min(maxZ+1, pz + 8)
            for _ = 1, math.random(2, mfloor(6 * particleLOD)) do
                local z = math.random(zStart, zEnd)
                local y = Player.y + (math.random() - 0.5) * 3
                spawnBarrierParticle(wallX + (math.random() - 0.5) * 1.5, y, z)
            end
        elseif math.abs(pz - minZ) == distToBarrier then
            wallZ = minZ
            local xStart = math.max(minX-1, px - 8)
            local xEnd = math.min(maxX+1, px + 8)
            for _ = 1, math.random(2, mfloor(6 * particleLOD)) do
                local x = math.random(xStart, xEnd)
                local y = Player.y + (math.random() - 0.5) * 3
                spawnBarrierParticle(x, y, wallZ + (math.random() - 0.5) * 1.5)
            end
        elseif math.abs(pz - maxZ) == distToBarrier then
            wallZ = maxZ
            local xStart = math.max(minX-1, px - 8)
            local xEnd = math.min(maxX+1, px + 8)
            for _ = 1, math.random(2, mfloor(6 * particleLOD)) do
                local x = math.random(xStart, xEnd)
                local y = Player.y + (math.random() - 0.5) * 3
                spawnBarrierParticle(x, y, wallZ + (math.random() - 0.5) * 1.5)
            end
        end
    end
end

function Barrier.draw(camera, fov_val, hw, hh, time)
    love.graphics.setBlendMode("add")
    for _, p in ipairs(barrierParticles) do
        local lifeAlpha = p.life / p.maxLife
        local tx, ty, tz = Renderer.transform(p.x, p.y, p.z, camera, Renderer.getMatrix(camera))
        if tz > 0.1 then
            local sx = (tx / tz) * fov_val + hw
            local sy = hh - (ty / tz) * fov_val
            local size = 4 * (1 - lifeAlpha * 0.5) / (tz * 0.5)
            local r = 0.5 + math.sin(time * 10) * 0.3
            local g = 0.6 + math.cos(time * 8) * 0.4
            local b = 1.0
            love.graphics.setColor(r, g, b, lifeAlpha * 0.8)
            love.graphics.circle("fill", sx, sy, math.max(2, size))
        end
    end
    love.graphics.setBlendMode("alpha")
end

-- ============================================================================
-- WEATHER PARTICLES MODULE
-- ============================================================================
local Weather = {}
local weatherParticles = {}
local maxParticles = 1000

local targetSnowCount = 200
local snowIntensity = 40

local leafIntensity = 10
local flowerIntensity = 2
local sandIntensity = 8

local spawnRadiusXZ = 20
local spawnMinY = -2
local spawnMaxY = 10

local playerCache = {x=0, y=0, z=0}

local particleLOD = 1.0

local function updateParticleLOD(fps)
    if fps >= 60 then
        particleLOD = 1.0
    elseif fps >= 45 then
        particleLOD = 0.9
    elseif fps >= 30 then
        particleLOD = 0.7
    elseif fps >= 20 then
        particleLOD = 0.5
    else
        particleLOD = 0.3
    end
end

local function getBiome(x, z)
    local y = World.getHeight(x, z)
    local block = World.getBlock(x, y, z)
    if block == 8 or block == 11 then
        return "snow"
    elseif block == 6 then
        return "desert"
    else
        return "normal"
    end
end

local function isNearTree(x, z)
    for _, tree in ipairs(World.treePositions or {}) do
        local dx = math.abs(tree.x - x)
        local dz = math.abs(tree.z - z)
        if dx <= 5 and dz <= 5 then
            return true
        end
    end
    return false
end

local function spawnWeatherParticle(px, py, pz, ptype)
    if #weatherParticles >= maxParticles then return end
    
    local particle = {
        x = px, y = py, z = pz,
        vx = (math.random() - 0.5) * 1.2,
        vy = 0,
        vz = (math.random() - 0.5) * 1.2,
        life = 1.0,
        maxLife = 1.0,
        type = ptype,
        size = 5
    }
    
    if ptype == "snow" then
        particle.vy = -2.0 - math.random() * 1.5
        particle.maxLife = 2.0 + math.random()
        particle.size = 6
        particle.vx = (math.random() - 0.5) * 0.8
        particle.vz = (math.random() - 0.5) * 0.8
    elseif ptype == "leaf" then
        particle.vy = -1.2 - math.random() * 1.2
        particle.maxLife = 2.0 + math.random() * 1.2
        particle.size = 5
        particle.vx = (math.random() - 0.5) * 1.5
        particle.vz = (math.random() - 0.5) * 1.5
    elseif ptype == "flower" then
        particle.vy = -1.0 - math.random() * 1.0
        particle.maxLife = 1.8 + math.random()
        particle.size = 4
    elseif ptype == "sand" then
        particle.vy = 0.8 + math.random() * 1.5
        particle.maxLife = 1.2 + math.random()
        particle.size = 4
    end
    particle.life = particle.maxLife
    
    table.insert(weatherParticles, particle)
end

local function spawnSnow(dt, playerX, playerY, playerZ)
    local snowCount = 0
    for _, p in ipairs(weatherParticles) do
        if p.type == "snow" then snowCount = snowCount + 1 end
    end
    
    local targetSnow = mfloor(targetSnowCount * particleLOD)
    local deficit = targetSnow - snowCount
    if deficit <= 0 then return end
    
    local toSpawn = math.min(deficit, math.floor(snowIntensity * dt * particleLOD))
    if toSpawn < 1 then toSpawn = 1 end
    
    for i = 1, toSpawn do
        local x = playerX + (math.random() - 0.5) * spawnRadiusXZ * 2
        local z = playerZ + (math.random() - 0.5) * spawnRadiusXZ * 2
        local y = playerY + spawnMinY + math.random() * (spawnMaxY - spawnMinY)
        spawnWeatherParticle(x, y, z, "snow")
    end
end

function Weather.update(dt)
    if not Player then return end
    
    if View and View.stats then
        updateParticleLOD(View.stats.fps or 60)
    else
        updateParticleLOD(60)
    end
    
    playerCache.x = Player.x
    playerCache.y = Player.y
    playerCache.z = Player.z
    
    local maxAllowedParticles = mfloor(maxParticles * particleLOD)
    
    for i = #weatherParticles, 1, -1 do
        local p = weatherParticles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.z = p.z + p.vz * dt
        p.life = p.life - dt
        if p.life <= 0 or p.y < 0 or p.y > 200 or #weatherParticles > maxAllowedParticles then
            table.remove(weatherParticles, i)
        end
    end
    
    local playerBiome = getBiome(playerCache.x, playerCache.z)
    
    if playerBiome == "snow" then
        spawnSnow(dt, playerCache.x, playerCache.y, playerCache.z)
        
        if isNearTree(playerCache.x, playerCache.z) and math.random() < 0.3 * particleLOD then
            for _ = 1, 2 do
                local x = playerCache.x + (math.random() - 0.5) * 6
                local z = playerCache.z + (math.random() - 0.5) * 6
                local y = playerCache.y + 5 + math.random() * 5
                spawnWeatherParticle(x, y, z, "snow")
            end
        end
    else
        local intensity = (playerBiome == "desert") and sandIntensity or (leafIntensity + flowerIntensity)
        local spawnChance = intensity * dt * particleLOD
        local numAttempts = math.max(1, math.floor(spawnChance * 3))
        for _ = 1, numAttempts do
            if math.random() < spawnChance / numAttempts then
                local angle = math.random() * math.pi * 2
                local radius = math.random() * 16
                local x = playerCache.x + math.cos(angle) * radius
                local z = playerCache.z + math.sin(angle) * radius
                local biomeAtPoint = getBiome(x, z)
                if biomeAtPoint == playerBiome then
                    local nearTree = isNearTree(x, z)
                    local groundY = World.getHeight(x, z)
                    if groundY then
                        if playerBiome == "desert" then
                            local y = groundY + 0.5 + math.random() * 2
                            spawnWeatherParticle(x, y, z, "sand")
                            if nearTree and math.random() < 0.4 then
                                spawnWeatherParticle(x + (math.random()-0.5)*2, y+0.5, z + (math.random()-0.5)*2, "sand")
                            end
                        else
                            local y = groundY + 3 + math.random() * 6
                            if nearTree then
                                if math.random() < 0.8 then
                                    spawnWeatherParticle(x, y, z, "leaf")
                                else
                                    spawnWeatherParticle(x, y, z, "flower")
                                end
                                if math.random() < 0.5 then
                                    spawnWeatherParticle(x + (math.random()-0.5)*2, y-1, z + (math.random()-0.5)*2, "leaf")
                                end
                            else
                                if math.random() < 0.35 then
                                    spawnWeatherParticle(x, y, z, "leaf")
                                elseif math.random() < 0.12 then
                                    spawnWeatherParticle(x, y, z, "flower")
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

function Weather.draw(camera, fov_val, hw, hh, time)
    love.graphics.setBlendMode("add")
    for _, p in ipairs(weatherParticles) do
        local lifeAlpha = p.life / p.maxLife
        local tx, ty, tz = Renderer.transform(p.x, p.y, p.z, camera, Renderer.getMatrix(camera))
        if tz > 0.1 then
            local sx = (tx / tz) * fov_val + hw
            local sy = hh - (ty / tz) * fov_val
            local size = p.size * (0.8 + lifeAlpha * 0.4) / (tz * 0.5)
            size = math.max(3, math.min(12, size))
            
            local r, g, b
            if p.type == "snow" then
                r, g, b = 1.0, 1.0, 1.0
            elseif p.type == "leaf" then
                r, g, b = 0.3, 0.8, 0.2
            elseif p.type == "flower" then
                r, g, b = 1.0, 0.5, 0.9
            elseif p.type == "sand" then
                r, g, b = 1.0, 0.9, 0.6
            end
            
            love.graphics.setColor(r, g, b, lifeAlpha)
            love.graphics.rectangle("fill", sx - size/2, sy - size/2, size, size)
        end
    end
    love.graphics.setBlendMode("alpha")
end

-- ============================================================================
-- VIEW MODULE
-- ============================================================================
local View = {
    time = 0,
    showDebug = false,
    showWireframe = false, 
    renderDistance = 18,
    minRenderDistance = 6,
    maxRenderDistance = 32,
    fontMain = nil,
    fontTitle = nil,
    fontSmall = nil,
    tabOffset = 0,
    stats = {
        blocksChecked = 0,
        facesCulled = 0,
        facesRendered = 0,
        fps = 0,
        frameTime = 0,
        chunkUpdates = 0,
    },
    lastFrameTime = 0,
    frameCounter = 0,
    fpsUpdateInterval = 0.5,
    fpsTimer = 0,
    lastFps = 60,
    fpsCheckCounter = 0,
    enableAdaptiveLOD = true,
    colorCache = {},
}

local MC_FOG = {192/255, 216/255, 255/255} 
local faces = { {0,0,1}, {0,0,-1}, {-1,0,0}, {1,0,0}, {0,1,0}, {0,-1,0} }
local faceIdx = { {5,6,7,8}, {2,1,4,3}, {1,5,8,4}, {6,2,3,7}, {1,2,6,5}, {8,7,3,4} }
local cube = {
    {-0.5,0.5,-0.5},{0.5,0.5,-0.5},{0.5,-0.5,-0.5},{-0.5,-0.5,-0.5},
    {-0.5,0.5,0.5},{0.5,0.5,0.5},{0.5,-0.5,0.5},{-0.5,-0.5,0.5},
}
local cubeEdges = {{1,2},{2,3},{3,4},{4,1},{5,6},{6,7},{7,8},{8,5},{1,5},{2,6},{3,7},{4,8}}

local lg = love.graphics

function View.init()
    View.fontMain = lg.newFont(16)
    View.fontTitle = lg.newFont(52)
    View.fontSmall = lg.newFont(12)
end

local function isBehindPlayer(x, y, z, player, matrix)
    local dx, dy, dz = x - player.x, y - player.y, z - player.z
    local tx = dx * matrix.cy - dz * matrix.sy
    local tz = dx * matrix.sy + dz * matrix.cy
    return tz <= 0.1
end

local function isWithinDistance(x, y, z, px, py, pz, maxDist)
    local dx = x - px
    local dy = y - py
    local dz = z - pz
    return dx*dx + dy*dy + dz*dz <= maxDist*maxDist
end

function View.render(dt, menuAnim)
    View.time = View.time + dt
    View.lastFrameTime = dt
    View.fpsTimer = View.fpsTimer + dt
    
    if View.enableAdaptiveLOD then
        View.fpsCheckCounter = View.fpsCheckCounter + 1
        if View.fpsCheckCounter >= 30 then
            View.lastFps = love.timer.getFPS()
            View.fpsCheckCounter = 0
            
            if View.lastFps < 30 and View.renderDistance > View.minRenderDistance then
                View.renderDistance = mmax(View.minRenderDistance, View.renderDistance - 2)
            elseif View.lastFps > 55 and View.renderDistance < View.maxRenderDistance then
                View.renderDistance = mmin(View.maxRenderDistance, View.renderDistance + 1)
            end
        end
    end
    
    local sw, sh = lg.getDimensions()
    local hw, hh = sw * 0.5, sh * 0.5
    
    local worldDarken = 1 - menuAnim * 0.6
    local r_sky = MC_FOG[1] * worldDarken
    local g_sky = MC_FOG[2] * worldDarken
    local b_sky = MC_FOG[3] * worldDarken
    lg.clear(r_sky, g_sky, b_sky)

    local R_DIST = View.renderDistance
    local FOG_START, FOG_END = R_DIST * 0.6, R_DIST
    local fov_val = (sh * 0.5) / mtan(mrad(75) * 0.5)
    local matrix = Renderer.getMatrix(Player)
    
    lg.push()
    if menuAnim > 0 then
        lg.translate(hw, hh)
        lg.scale(1 - menuAnim * 0.1)
        lg.translate(-hw, -hh)
    end

    if View.showDebug then
        View.stats.blocksChecked = 0
        View.stats.facesCulled = 0
        View.stats.facesRendered = 0
    end
    
    local faceDrawList = {}
    local ix, iy, iz = mfloor(Player.x + 0.5), mfloor(Player.y + 0.5), mfloor(Player.z + 0.5)
    local maxDistSq = (R_DIST + 2) * (R_DIST + 2)
    
    local worldData = World.data
    local faces_list = faces
    
    for x = ix - R_DIST, ix + R_DIST do
        if worldData[x] then
            for y = iy - 12, iy + 12 do
                if worldData[x][y] then
                    for z = iz - R_DIST, iz + R_DIST do
                        if View.showDebug then View.stats.blocksChecked = View.stats.blocksChecked + 1 end
                        
                        local id = worldData[x][y][z]
                        if id and id > 0 then
                            if isBehindPlayer(x, y, z, Player, matrix) then
                                if View.showDebug then View.stats.facesCulled = View.stats.facesCulled + 6 end
                                goto skip_block
                            end
                            
                            local dx, dy, dz = x - Player.x, y - Player.y, z - Player.z
                            if dx*dx + dy*dy + dz*dz > maxDistSq then
                                if View.showDebug then View.stats.facesCulled = View.stats.facesCulled + 6 end
                                goto skip_block
                            end
                            
                            for fIdx = 1, 6 do
                                local f = faces_list[fIdx]
                                local nx, ny, nz = x + f[1], y + f[2], z + f[3]
                                
                                if not (worldData[nx] and worldData[nx][ny] and worldData[nx][ny][nz]) then
                                    local cx, cy, cz = x+f[1]*0.5, y+f[2]*0.5, z+f[3]*0.5
                                    local dx2 = cx - Player.x
                                    local dy2 = cy - Player.y
                                    local dz2 = cz - Player.z
                                    local distSq = dx2*dx2 + dy2*dy2 + dz2*dz2
                                    
                                    local _, _, fz = Renderer.transform(cx, cy, cz, Player, matrix)
                                    if fz > 0.1 and distSq < (FOG_END + 1)*(FOG_END + 1) then
                                        local dist = msqrt(distSq)
                                        table.insert(faceDrawList, {x=x,y=y,z=z,fIdx=fIdx,d=dist,id=id})
                                        if View.showDebug then View.stats.facesRendered = View.stats.facesRendered + 1 end
                                    else
                                        if View.showDebug then View.stats.facesCulled = View.stats.facesCulled + 1 end
                                    end
                                else
                                    if View.showDebug then View.stats.facesCulled = View.stats.facesCulled + 1 end
                                end
                            end
                        end
                        ::skip_block::
                    end
                end
            end
        end
    end
    
    table.sort(faceDrawList, function(a, b) return a.d > b.d end)

    for _, f in ipairs(faceDrawList) do
        local fog = mmin(mmax((f.d - FOG_START) / (FOG_END - FOG_START), 0), 1)
        local pts = {}
        for v_i = 1, 4 do
            local v = cube[faceIdx[f.fIdx][v_i]]
            local tx, ty, tz = Renderer.transform(f.x+v[1], f.y+v[2], f.z+v[3], Player, matrix)
            tz = mmax(tz, 0.05)
            pts[v_i*2-1] = (tx/tz)*fov_val + hw
            pts[v_i*2]   = hh - (ty/tz)*fov_val
        end

        local blockType = World.types[f.id]
        local col
        if blockType and blockType.colors then
            col = blockType.colors[f.fIdx]
        else
            col = {0.5,0.5,0.5}
        end
        local r, g, b = col[1], col[2], col[3]
        
        local alpha = 1.0
        
        if f.id == 99 then
            local t = View.time * 2.5
            r = 0.4 + msin(t)*0.3
            g = 0.5 + msin(t+2.0)*0.4
            b = 0.9 + msin(t+1.2)*0.2
            alpha = 0.25 + (msin(t*1.8)+1)/4
        else
            local noise = msin(f.x*0.05)*0.03 + mcos(f.z*0.05)*0.03
            r = mmax(0, mmin(1, r + noise))
            g = mmax(0, mmin(1, g + noise))
            b = mmax(0, mmin(1, b + noise))
        end
        
        r = r * (1-fog) + r_sky * fog
        g = g * (1-fog) + g_sky * fog
        b = b * (1-fog) + b_sky * fog
        alpha = alpha * (1 - fog * 0.7)

        lg.setColor(r, g, b, alpha)
        lg.polygon("fill", pts)

        if not View.showWireframe and Interact.selectedBlock and f.x == Interact.selectedBlock.x and f.y == Interact.selectedBlock.y and f.z == Interact.selectedBlock.z then
            lg.setLineWidth(2)
            lg.setBlendMode("subtract")
            lg.setColor(1, 1, 1, 0.5)
            lg.polygon("line", pts)
            lg.setBlendMode("alpha")
        end
    end

    if View.showWireframe and Interact.selectedBlock and menuAnim < 0.1 then
        local b = Interact.selectedBlock
        lg.setLineWidth(2)
        lg.setBlendMode("subtract") 
        lg.setColor(1, 1, 1, 0.4)
        for _, edge in ipairs(cubeEdges) do
            local v1, v2 = cube[edge[1]], cube[edge[2]]
            local tx1, ty1, tz1 = Renderer.transform(b.x+v1[1], b.y+v1[2], b.z+v1[3], Player, matrix)
            local tx2, ty2, tz2 = Renderer.transform(b.x+v2[1], b.y+v2[2], b.z+v2[3], Player, matrix)
            if tz1 > 0.05 and tz2 > 0.05 then
                lg.line((tx1/tz1)*fov_val + hw, hh - (ty1/tz1)*fov_val, (tx2/tz2)*fov_val + hw, hh - (ty2/tz2)*fov_val)
            end
        end
        lg.setBlendMode("alpha")
    end
    lg.pop()

    if menuAnim < 0.1 then
        lg.setBlendMode("subtract")
        lg.setColor(1, 1, 1)
        lg.setLineWidth(1)
        local s, g = 6, 1
        lg.line(hw-s, hh, hw-g, hh) lg.line(hw+g, hh, hw+s, hh)
        lg.line(hw, hh-s, hw, hh-g) lg.line(hw, hh+g, hw, hh+s)
        lg.setBlendMode("alpha")
    end

    if View.fpsTimer >= View.fpsUpdateInterval then
        View.stats.fps = love.timer.getFPS()
        View.fpsTimer = 0
    end

    if View.showDebug then
        View.drawDebugInfo(ix, iy, iz, hw, sh)
    end
end

function View.drawDebugInfo(ix, iy, iz, hw, sh)
    local posY = 15
    local lineHeight = 18
    local textX = 25
    local panelWidth = 540
    local panelHeight = 340
    
    lg.setFont(View.fontSmall)
    lg.setColor(0, 0, 0, 0.6)
    lg.rectangle("fill", 15, posY, panelWidth, panelHeight, 5)
    lg.setColor(1, 1, 1)
    
    lg.setFont(View.fontMain)
    lg.print("§ LoveCraft Debug (F3)", textX, posY + 5)
    
    lg.setFont(View.fontSmall)
    posY = posY + 30
    
    local fpsColor = View.stats.fps >= 60 and {0, 1, 0} or View.stats.fps >= 30 and {1, 1, 0} or {1, 0, 0}
    lg.setColor(fpsColor[1], fpsColor[2], fpsColor[3])
    lg.print("FPS: "..View.stats.fps, textX, posY)
    
    lg.setColor(1, 1, 1)
    posY = posY + lineHeight
    lg.print("Frame Time: "..string.format("%.2f", View.lastFrameTime * 1000).."ms", textX, posY)
    
    posY = posY + lineHeight + 5
    lg.print("Position: "..string.format("%.2f", ix).." / "..string.format("%.2f", iy).." / "..string.format("%.2f", iz), textX, posY)
    posY = posY + lineHeight
    lg.print("Chunk: "..mfloor(ix/16).." / "..mfloor(iz/16), textX, posY)
    
    posY = posY + lineHeight + 5
    lg.print("Yaw: "..string.format("%.1f", Player.yaw * 57.2958).."°", textX, posY)
    posY = posY + lineHeight
    lg.print("Pitch: "..string.format("%.1f", Player.pitch * 57.2958).."°", textX, posY)
    posY = posY + lineHeight
    lg.print("On Ground: "..(Player.onGround and "YES" or "NO"), textX, posY)
    
    posY = posY + lineHeight + 5
    lg.print("Blocks Checked: "..View.stats.blocksChecked, textX, posY)
    posY = posY + lineHeight
    lg.print("Faces Culled: "..View.stats.facesCulled, textX, posY)
    posY = posY + lineHeight
    lg.print("Faces Rendered: "..View.stats.facesRendered, textX, posY)
    
    local cullingRate = View.stats.blocksChecked > 0 and 
        mfloor((View.stats.facesCulled / (View.stats.blocksChecked * 6)) * 100) or 0
    posY = posY + lineHeight
    lg.print("Culling Rate: "..cullingRate.."%", textX, posY)
    
    posY = posY + lineHeight + 5
    lg.print("Render Distance: "..View.renderDistance, textX, posY)
    
    posY = posY + lineHeight
    lg.print("Seed: "..(World.seed or "N/A"), textX, posY)
    
    posY = posY + lineHeight + 5
    local memUsage = collectgarbage("count") / 1024
    lg.print(string.format("Memory: %.1f MB", memUsage), textX, posY)
    
    local particleCount = #weatherParticles + #barrierParticles
    posY = posY + lineHeight
    lg.print("Particles: "..particleCount, textX, posY)
end

function View.drawMenu(anim, state)
    if anim < 0.01 then return end
    local sw, sh = lg.getDimensions()
    local hw, hh = sw/2, sh/2

    lg.setColor(0.05, 0.07, 0.1, anim * 0.7)
    lg.rectangle("fill", 0, 0, sw, sh)

    local targetTab = (state == "SETTINGS") and -sw or 0
    View.tabOffset = View.tabOffset + (targetTab - View.tabOffset) * love.timer.getDelta() * 12

    lg.push()
    lg.translate(View.tabOffset, 0)
    lg.setFont(View.fontTitle)
    lg.setColor(1, 1, 1, anim)
    lg.printf("LOVECRAFT", 0, hh - 180, sw, "center")
    View.drawStyledBtn("RESUME", hw, hh - 40, anim)
    View.drawStyledBtn("SETTINGS", hw, hh + 30, anim)
    View.drawStyledBtn("QUIT GAME", hw, hh + 100, anim)
    lg.push()
    lg.translate(sw, 0)
    lg.setFont(View.fontTitle)
    lg.printf("SETTINGS", 0, hh - 180, sw, "center")
    lg.setFont(View.fontMain)
    lg.printf("RENDER DISTANCE", 0, hh - 60, sw, "center")
    View.drawSideBtn("-", hw - 90, hh, anim)
    lg.printf(tostring(View.renderDistance), hw - 50, hh - 8, 100, "center")
    View.drawSideBtn("+", hw + 90, hh, anim)
    local selText = "3D SELECTION: " .. (View.showWireframe and "ON" or "OFF")
    View.drawStyledBtn(selText, hw, hh + 70, anim)
    View.drawStyledBtn("BACK", hw, hh + 140, anim)
    lg.pop()
    lg.pop()
end

function View.drawStyledBtn(txt, x, y, alpha)
    local w, h = 240, 45
    local mx, my = love.mouse.getPosition()
    local hover = mx > x-w/2 and mx < x+w/2 and my > y-h/2 and my < y+h/2
    lg.setColor(1, 1, 1, (hover and 0.15 or 0.05) * alpha)
    lg.rectangle("fill", x-w/2, y-h/2, w, h, 6)
    lg.setColor(1, 1, 1, (hover and 1 or 0.3) * alpha)
    lg.rectangle("line", x-w/2, y-h/2, w, h, 6)
    lg.setFont(View.fontMain)
    lg.printf(txt, x - w/2, y - 9, w, "center")
end

function View.drawSideBtn(txt, x, y, alpha)
    local size = 40
    local mx, my = love.mouse.getPosition()
    local hover = mx > x-size/2 and mx < x+size/2 and my > y-size/2 and my < y+size/2
    lg.setColor(1, 1, 1, (hover and 1 or 0.3) * alpha)
    lg.rectangle("line", x-size/2, y-size/2, size, size, 6)
    lg.printf(txt, x-size/2, y - 9, size, "center")
end

-- ============================================================================
-- MAIN GAME LOOP
-- ============================================================================

local State = "GAME"
local menuAnim = 0
local accumulator = 0
local fixed_dt = 1/60
local gcTimer = 0

function love.load()
    love.window.setTitle("LoveCraft v0.1")
    love.window.setMode(1280, 720, {resizable=true, vsync=true})
    love.mouse.setRelativeMode(true)

    View.init()
    World.generate()
    Player.spawn(World)
    
    collectgarbage("setpause", 200)
end

function love.update(dt)
    local targetAnim = (State == "GAME") and 0 or 1
    menuAnim = menuAnim + (targetAnim - menuAnim) * dt * 10

    if State == "GAME" then
        accumulator = accumulator + math.min(dt, 0.25)

        while accumulator >= fixed_dt do
            Player.update(fixed_dt)
            Interact.update(Player, World)
            accumulator = accumulator - fixed_dt
        end

        Barrier.update(dt)
        Weather.update(dt)
    end
    
    gcTimer = gcTimer + dt
    if gcTimer > 1.0 then
        gcTimer = 0
        if love.timer.getFPS() < 50 then
            collectgarbage("step", 1)
        end
    end
end

function love.draw()
    View.render(love.timer.getDelta(), menuAnim)
    local sw, sh = love.graphics.getDimensions()
    local hw, hh = sw/2, sh/2
    local fov_val = (sh * 0.5) / math.tan(math.rad(75) * 0.5)
    local time = love.timer.getTime()
    Barrier.draw(Player, fov_val, hw, hh, time)
    Weather.draw(Player, fov_val, hw, hh, time)
    View.drawMenu(menuAnim, State)
end

function love.mousepressed(x, y, button)
    local sw, sh = love.graphics.getDimensions()
    local hw, hh = sw/2, sh/2

    if State == "GAME" then
        if button == 1 then Interact.breakBlock(World) end
        if button == 2 then Interact.placeBlock(World) end

    elseif State == "MENU" then
        if x > hw-120 and x < hw+120 and y > hh-62 and y < hh-18 then
            State = "GAME"
            love.mouse.setRelativeMode(true)
        end
        if x > hw-120 and x < hw+120 and y > hh+8 and y < hh+52 then
            State = "SETTINGS"
        end
        if x > hw-120 and x < hw+120 and y > hh+78 and y < hh+122 then
            love.event.quit()
        end

    elseif State == "SETTINGS" then
        if y > hh-20 and y < hh+20 then
            if x > hw-110 and x < hw-70 then View.renderDistance = math.max(4, View.renderDistance - 2) end
            if x > hw+70 and x < hw+110 then View.renderDistance = math.min(64, View.renderDistance + 2) end
        end
        if x > hw-120 and x < hw+120 and y > hh+48 and y < hh+92 then
            View.showWireframe = not View.showWireframe
        end
        if x > hw-120 and x < hw+120 and y > hh+118 and y < hh+162 then
            State = "MENU"
        end
    end
end

function love.keypressed(key)
    if key == "escape" then
        if State == "GAME" then
            State = "MENU"
            love.mouse.setRelativeMode(false)
        else
            State = "GAME"
            love.mouse.setRelativeMode(true)
        end
    end

    if key == "f3" then
        View.showDebug = not View.showDebug
    end
end

function love.mousemoved(x, y, dx, dy)
    if State == "GAME" then
        Player.yaw = Player.yaw - dx * Player.config.sens
        Player.pitch = math.max(-1.5, math.min(1.5, Player.pitch + dy * Player.config.sens))
    end
end

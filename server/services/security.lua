CBKCommsSecurity = {}
local rateLimiter = {}

local function nowMs()
    return GetGameTimer()
end

function CBKCommsSecurity.Log(message)
    if CBKComms.Config.Debug then
        print(('[cbk-comms] %s'):format(message))
    end
end

function CBKCommsSecurity.GetPlayerIdentifiersMap(src)
    local map = {}
    for _, identifier in ipairs(GetPlayerIdentifiers(src)) do
        map[identifier] = true
    end
    return map
end

function CBKCommsSecurity.CanPassRateLimit(src, bucket, windowMs, burst)
    rateLimiter[src] = rateLimiter[src] or {}
    local item = rateLimiter[src][bucket]

    local current = nowMs()
    if not item or current > item.resetAt then
        rateLimiter[src][bucket] = {
            count = 1,
            resetAt = current + windowMs
        }
        return true
    end

    if item.count >= burst then
        return false
    end

    item.count = item.count + 1
    return true
end

function CBKCommsSecurity.CleanupPlayer(src)
    rateLimiter[src] = nil
end

function CBKCommsSecurity.IsValidVolume(value)
    return type(value) == 'number'
        and value >= CBKComms.Config.Radio.minVolume
        and value <= CBKComms.Config.Radio.maxVolume
end

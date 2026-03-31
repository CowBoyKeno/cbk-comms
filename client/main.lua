local function createDefaultState()
    return {
        radioOn = true,
        volume = CBKComms.Config.Radio.defaultVolume,
        active = nil,
        departments = {}
    }
end

local uiOpen = false
local uiFocused = false
local currentState = createDefaultState()

local currentListenChannels = {}
local transmitActive = false
local radioFxSubmixId = -1
local managedSubmixPlayers = {}
local listenAttemptTokens = {}

local function debugPrint(message)
    if CBKComms.Config.Debug then
        print(('[cbk-comms][client] %s'):format(message))
    end
end

local function notify(message)
    TriggerEvent('chat:addMessage', {
        color = { 90, 200, 255 },
        args = { 'CBK-COMMS', message }
    })
end

local function setUiState(state)
    currentState = state or currentState
    SendNUIMessage({
        action = 'state',
        payload = {
            radioOn = currentState.radioOn,
            volume = currentState.volume,
            active = currentState.active,
            departments = currentState.departments,
            uiDefaults = {
                closeOnJoin = CBKComms.Config.Radio.autoCloseOnJoin == true
            }
        }
    })
end

local function recoverVisualState()
    if uiOpen then
        return
    end

    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    RenderScriptCams(false, false, 0, true, true)
    ClearTimecycleModifier()
    ClearExtraTimecycleModifier()
    DisplayRadar(true)
    DisplayHud(true)

    if ShutdownLoadingScreen then
        pcall(ShutdownLoadingScreen)
    end

    if ShutdownLoadingScreenNui then
        pcall(ShutdownLoadingScreenNui)
    end

    if IsScreenFadedOut() or IsScreenFadingOut() then
        DoScreenFadeIn(0)
    end
end

local function scheduleVisualRecovery()
    CreateThread(function()
        local delays = { 0, 250, 1000, 2500, 5000 }
        for _, delay in ipairs(delays) do
            Wait(delay)
            recoverVisualState()
        end
    end)
end

local function applyUiFocus()
    local focus = uiOpen and uiFocused
    SetNuiFocus(focus, focus)
    SetNuiFocusKeepInput(false)
end

local function setUiFocus(state)
    uiFocused = uiOpen and state == true
    applyUiFocus()
end

local function setUiOpen(state, focused)
    uiOpen = state == true
    uiFocused = uiOpen and focused ~= false
    applyUiFocus()
    SendNUIMessage({
        action = 'visibility',
        payload = {
            visible = uiOpen
        }
    })

    if not uiOpen then
        recoverVisualState()
    end
end

local function playPttTone(toneKey)
    local pttSounds = CBKComms.Config.Radio.pttSounds
    if type(pttSounds) ~= 'table' or pttSounds.enabled == false then
        return
    end

    local tone = pttSounds[toneKey]
    if type(tone) ~= 'table' or type(tone.name) ~= 'string' or tone.name == '' then
        return
    end

    local soundId = type(GetSoundId) == 'function' and GetSoundId() or -1
    local playbackId = soundId ~= -1 and soundId or -1

    PlaySoundFrontend(playbackId, tone.name, tone.set or 'MP_RADIO_SFX', false)

    if playbackId ~= -1 and type(SetVariableOnSound) == 'function' and type(tone.volume) == 'number' then
        pcall(SetVariableOnSound, playbackId, 'Volume', tone.volume + 0.0)
    end

    if playbackId ~= -1 and type(ReleaseSoundId) == 'function' then
        local releaseMs = math.max(150, math.floor(tonumber(tone.releaseMs) or tonumber(pttSounds.releaseMs) or 450))
        CreateThread(function()
            Wait(releaseMs)
            ReleaseSoundId(playbackId)
        end)
    end
end

local function stopTransmit()
    if not transmitActive then
        return
    end

    transmitActive = false
    MumbleClearVoiceTargetChannels(CBKComms.Config.Radio.voiceTargetId)
    MumbleSetVoiceTarget(0)
    playPttTone('release')

    SendNUIMessage({
        action = 'transmit',
        payload = {
            active = false
        }
    })
end

local function startTransmit()
    if transmitActive then
        return
    end

    if not currentState.radioOn then
        notify('Radio is powered off')
        return
    end

    if not currentState.active or not currentState.active.department or not currentState.active.channel then
        notify('Join a radio channel first')
        return
    end

    local department = currentState.departments[currentState.active.department]
    if not department or not department.authorized then
        notify('Unauthorized radio state detected')
        return
    end

    local transmitChannels = currentState.active.transmitChannels or {}
    if #transmitChannels == 0 then
        notify('Radio channel sync missing')
        return
    end

    transmitActive = true
    MumbleClearVoiceTargetChannels(CBKComms.Config.Radio.voiceTargetId)

    local queuedVoiceChannels = {}
    for _, channelRef in ipairs(transmitChannels) do
        local voiceChannelId = tonumber(channelRef.voiceChannelId)
        if voiceChannelId and not queuedVoiceChannels[voiceChannelId] then
            queuedVoiceChannels[voiceChannelId] = true
            MumbleAddVoiceTargetChannel(CBKComms.Config.Radio.voiceTargetId, voiceChannelId)
        end
    end

    MumbleSetVoiceTarget(CBKComms.Config.Radio.voiceTargetId)
    playPttTone('press')

    SendNUIMessage({
        action = 'transmit',
        payload = {
            active = true
        }
    })
end

local function buildListenLookup(channelRefs)
    local lookup = {}

    for _, channelRef in ipairs(channelRefs or {}) do
        local channelId = channelRef.id
        local voiceChannelId = tonumber(channelRef.voiceChannelId)
        if channelId and voiceChannelId then
            lookup[channelId] = voiceChannelId
        end
    end

    return lookup
end

local function tryAddListenChannel(voiceChannelId)
    if type(MumbleDoesChannelExist) ~= 'function' or MumbleDoesChannelExist(voiceChannelId) then
        MumbleAddVoiceChannelListen(voiceChannelId)
        return true
    end

    return false
end

local function applyListenChannels(channelRefs)
    local desiredChannels = buildListenLookup(channelRefs)

    for channelId, voiceChannelId in pairs(currentListenChannels) do
        if desiredChannels[channelId] ~= voiceChannelId then
            listenAttemptTokens[channelId] = (listenAttemptTokens[channelId] or 0) + 1

            if type(MumbleDoesChannelExist) ~= 'function' or MumbleDoesChannelExist(voiceChannelId) then
                MumbleRemoveVoiceChannelListen(voiceChannelId)
            end

            currentListenChannels[channelId] = nil
        end
    end

    for channelId, voiceChannelId in pairs(desiredChannels) do
        if currentListenChannels[channelId] ~= voiceChannelId then
            currentListenChannels[channelId] = voiceChannelId
            listenAttemptTokens[channelId] = (listenAttemptTokens[channelId] or 0) + 1

            if not tryAddListenChannel(voiceChannelId) then
                local token = listenAttemptTokens[channelId]

                CreateThread(function()
                    for _ = 1, 20 do
                        Wait(250)

                        if token ~= listenAttemptTokens[channelId] or currentListenChannels[channelId] ~= voiceChannelId then
                            return
                        end

                        if tryAddListenChannel(voiceChannelId) then
                            return
                        end
                    end

                    debugPrint(('voice channel %s was still unavailable after retry window'):format(voiceChannelId))
                end)
            end
        end
    end
end

local function ensureRadioFx()
    if not CBKComms.Config.Radio.useRadioFx then
        return -1
    end

    if radioFxSubmixId ~= -1 then
        return radioFxSubmixId
    end

    radioFxSubmixId = CreateAudioSubmix('cbk_comms_radio')
    if radioFxSubmixId ~= -1 then
        SetAudioSubmixEffectRadioFx(radioFxSubmixId, CBKComms.Config.RadioFx.effectSlot)
        SetAudioSubmixEffectParamInt(radioFxSubmixId, CBKComms.Config.RadioFx.effectSlot, `default`, CBKComms.Config.RadioFx.default)
        SetAudioSubmixEffectParamFloat(radioFxSubmixId, CBKComms.Config.RadioFx.effectSlot, `freq_low`, CBKComms.Config.RadioFx.freqLow)
        SetAudioSubmixEffectParamFloat(radioFxSubmixId, CBKComms.Config.RadioFx.effectSlot, `freq_hi`, CBKComms.Config.RadioFx.freqHi)
        AddAudioSubmixOutput(radioFxSubmixId, 1)
    end

    return radioFxSubmixId
end

local function resetManagedSubmixPlayers()
    for serverId, _ in pairs(managedSubmixPlayers) do
        MumbleSetSubmixForServerId(serverId, -1)
        managedSubmixPlayers[serverId] = nil
    end
end

local function updateManagedSubmixPlayers()
    if not currentState.active then
        resetManagedSubmixPlayers()
        return
    end

    local allowed = {}
    for _, channelRef in ipairs(currentState.active.listenChannels or {}) do
        local dept = currentState.departments[channelRef.department]
        local channel = dept and dept.channels and dept.channels[channelRef.channel]
        if channel and type(channel.memberServerIds) == 'table' then
            for _, serverId in ipairs(channel.memberServerIds) do
                allowed[serverId] = true
            end
        end
    end

    if next(allowed) == nil then
        resetManagedSubmixPlayers()
        return
    end

    local submixId = ensureRadioFx()
    if submixId == -1 then
        return
    end

    local targetSeen = {}
    for _, playerId in ipairs(GetActivePlayers()) do
        if playerId ~= PlayerId() and NetworkIsPlayerTalking(playerId) then
            local serverId = GetPlayerServerId(playerId)
            if allowed[serverId] then
                targetSeen[serverId] = true
                MumbleSetSubmixForServerId(serverId, submixId)
                managedSubmixPlayers[serverId] = true
            end
        end
    end

    for serverId, _ in pairs(managedSubmixPlayers) do
        if not targetSeen[serverId] then
            MumbleSetSubmixForServerId(serverId, -1)
            managedSubmixPlayers[serverId] = nil
        end
    end
end

RegisterNetEvent('cbk-comms:client:syncState', function(state, closeUi)
    currentState = state or currentState

    local listenChannels = currentState.active and currentState.active.listenChannels or nil
    applyListenChannels(listenChannels)
    setUiState(currentState)

    if closeUi then
        setUiOpen(false)
    end

    if not listenChannels or #listenChannels == 0 then
        stopTransmit()
    end
end)

RegisterNetEvent('cbk-comms:client:setUiOpen', function(state)
    setUiOpen(state == true)
end)

RegisterNetEvent('cbk-comms:client:accessDenied', function(payload)
    stopTransmit()
    applyListenChannels(nil)
    currentState = createDefaultState()
    setUiState(currentState)
    setUiOpen(false)

    local reason = payload and payload.reason
    if reason and reason ~= '' then
        notify(reason)
    end
end)

RegisterNUICallback('close', function(_, cb)
    setUiOpen(false)
    cb({ ok = true })
end)

RegisterNUICallback('releaseFocus', function(_, cb)
    if uiOpen then
        setUiFocus(false)
    end
    cb({ ok = true })
end)

RegisterNUICallback('join', function(data, cb)
    if type(data) == 'table' then
        TriggerServerEvent('cbk-comms:server:joinChannel', {
            department = data.department,
            channel = data.channel
        })
    end
    cb({ ok = true })
end)

RegisterNUICallback('togglePatch', function(data, cb)
    if type(data) == 'table' then
        TriggerServerEvent('cbk-comms:server:togglePatch', {
            department = data.department,
            channel = data.channel
        })
    end
    cb({ ok = true })
end)

RegisterNUICallback('leave', function(_, cb)
    TriggerServerEvent('cbk-comms:server:leaveChannel')
    cb({ ok = true })
end)

RegisterNUICallback('togglePower', function(data, cb)
    TriggerServerEvent('cbk-comms:server:setPower', {
        enabled = data and data.enabled == true
    })
    cb({ ok = true })
end)

RegisterNUICallback('setVolume', function(data, cb)
    TriggerServerEvent('cbk-comms:server:setVolume', {
        volume = tonumber(data and data.volume) or CBKComms.Config.Radio.defaultVolume
    })
    cb({ ok = true })
end)

RegisterNUICallback('toggleLock', function(data, cb)
    if type(data) == 'table' then
        TriggerServerEvent('cbk-comms:server:toggleLock', {
            department = data.department,
            channel = data.channel,
            locked = data.locked == true
        })
    end
    cb({ ok = true })
end)

RegisterCommand('+cbk_comms_open', function()
    if uiOpen then
        if uiFocused then
            setUiOpen(false)
        else
            setUiFocus(true)
        end
        return
    end

    TriggerServerEvent('cbk-comms:server:openUi')
end, false)

RegisterCommand('-cbk_comms_open', function()
end, false)

RegisterKeyMapping('+cbk_comms_open', 'Open CBK Comms Radio', 'keyboard', CBKComms.Config.Keybinds.openRadio)

RegisterCommand('+cbk_comms_tx', function()
    startTransmit()
end, false)

RegisterCommand('-cbk_comms_tx', function()
    stopTransmit()
end, false)

RegisterKeyMapping('+cbk_comms_tx', 'Transmit on CBK Comms Radio', 'keyboard', CBKComms.Config.Keybinds.transmit)

CreateThread(function()
    ensureRadioFx()

    while true do
        Wait(350)
        updateManagedSubmixPlayers()
    end
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    TriggerServerEvent('cbk-comms:server:requestState')
    setUiOpen(false)
    setUiState(currentState)
    scheduleVisualRecovery()
    debugPrint('client started')
end)

AddEventHandler('playerSpawned', function()
    scheduleVisualRecovery()
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    stopTransmit()
    applyListenChannels(nil)
    resetManagedSubmixPlayers()
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    RenderScriptCams(false, false, 0, true, true)
end)

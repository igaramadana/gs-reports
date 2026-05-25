local uiOpen = false
local currentMode = nil

local function notify(title, description, notifyType, duration)
    lib.notify({
        title = title or 'Reports',
        description = description or '',
        type = notifyType or 'inform',
        duration = duration or 3500
    })
end

local function openUI(mode, payload)
    uiOpen = true
    currentMode = mode

    SetNuiFocus(true, true)

    SendNUIMessage({
        action = 'open',
        mode = mode,
        adminName = GetPlayerName(PlayerId()) or 'Admin',
        reports = payload and payload.reports or {},
        leaderboard = payload and payload.leaderboard or {}
    })
end

local function closeUI()
    uiOpen = false
    currentMode = nil

    SetNuiFocus(false, false)

    SendNUIMessage({
        action = 'close'
    })
end

local function updateAdminData(reports, leaderboard)
    SendNUIMessage({
        action = 'setData',
        reports = reports or {},
        leaderboard = leaderboard or {}
    })
end

local function handleCallbackNotify(result, successMessage, errorMessage)
    if result and result.ok then
        notify('Reports', result.message or successMessage or 'Berhasil.', 'success')
        return true
    end

    notify('Reports', result and result.message or errorMessage or 'Gagal memproses request.', 'error')
    return false
end

RegisterNetEvent('gs-reports:client:openPlayer', function(reports)
    openUI('player', {
        reports = reports or {},
        leaderboard = {}
    })
end)

RegisterNetEvent('gs-reports:client:openAdmin', function(reports, leaderboard)
    openUI('admin', {
        reports = reports or {},
        leaderboard = leaderboard or {}
    })
end)

RegisterNetEvent('gs-reports:client:setData', function(reports, leaderboard)
    updateAdminData(reports, leaderboard)
end)

RegisterNetEvent('gs-reports:client:close', function()
    closeUI()
end)

RegisterNetEvent('gs-reports:client:teleportToCoords', function(coords)
    if not coords then
        return
    end

    local ped = PlayerPedId()

    DoScreenFadeOut(250)
    Wait(300)

    SetEntityCoords(
        ped,
        coords.x + 0.0,
        coords.y + 0.0,
        coords.z + 0.0,
        false,
        false,
        false,
        false
    )

    if coords.heading then
        SetEntityHeading(ped, coords.heading + 0.0)
    end

    Wait(250)
    DoScreenFadeIn(250)
end)

RegisterNUICallback('close', function(_, cb)
    closeUI()

    cb({
        ok = true
    })
end)

RegisterNUICallback('createReport', function(data, cb)
    local result = lib.callback.await('gs-reports:server:createReport', false, {
        title = data and data.title or '',
        category = data and data.category or 'Help',
        priority = data and data.priority or 'medium',
        description = data and data.description or ''
    })

    handleCallbackNotify(result, 'Report berhasil dikirim.', 'Gagal membuat report.')

    cb(result or {
        ok = false
    })
end)

RegisterNUICallback('sendMessage', function(data, cb)
    local result = lib.callback.await('gs-reports:server:sendMessage', false, {
        reportId = data and data.reportId or nil,
        message = data and data.message or ''
    })

    handleCallbackNotify(result, 'Pesan terkirim.', 'Gagal mengirim pesan.')

    cb(result or {
        ok = false
    })
end)

RegisterNUICallback('assistReport', function(data, cb)
    local result = lib.callback.await('gs-reports:server:assistReport', false, {
        reportId = data and data.reportId or nil
    })

    handleCallbackNotify(result, 'Report diambil.', 'Gagal assist report.')

    cb(result or {
        ok = false
    })
end)

RegisterNUICallback('solveReport', function(data, cb)
    local result = lib.callback.await('gs-reports:server:solveReport', false, {
        reportId = data and data.reportId or nil
    })

    handleCallbackNotify(result, 'Report solved.', 'Gagal solve report.')

    cb(result or {
        ok = false
    })
end)

RegisterNUICallback('closeReport', function(data, cb)
    local result = lib.callback.await('gs-reports:server:closeReport', false, {
        reportId = data and data.reportId or nil
    })

    handleCallbackNotify(result, 'Report ditutup.', 'Gagal close report.')

    cb(result or {
        ok = false
    })
end)

RegisterNUICallback('gotoReporter', function(data, cb)
    local result = lib.callback.await('gs-reports:server:gotoReporter', false, {
        reportId = data and data.reportId or nil
    })

    handleCallbackNotify(result, 'Teleport ke reporter berhasil.', 'Gagal teleport ke reporter.')

    cb(result or {
        ok = false
    })
end)

RegisterNUICallback('bringReporter', function(data, cb)
    local result = lib.callback.await('gs-reports:server:bringReporter', false, {
        reportId = data and data.reportId or nil
    })

    handleCallbackNotify(result, 'Reporter berhasil dibawa.', 'Gagal membawa reporter.')

    cb(result or {
        ok = false
    })
end)

RegisterCommand('report', function()
    TriggerServerEvent('gs-reports:server:requestOpenPlayer')
end, false)

RegisterCommand('reports', function()
    TriggerServerEvent('gs-reports:server:requestOpenAdmin')
end, false)

RegisterKeyMapping('reports', 'Open admin reports menu', 'keyboard', 'F7')

CreateThread(function()
    while true do
        if uiOpen then
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 68, true)
            DisableControlAction(0, 69, true)
            DisableControlAction(0, 70, true)
            DisableControlAction(0, 91, true)
            DisableControlAction(0, 92, true)
            DisableControlAction(0, 106, true)
            DisableControlAction(0, 200, true)

            Wait(0)
        else
            Wait(500)
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    if uiOpen then
        SetNuiFocus(false, false)
    end
end)

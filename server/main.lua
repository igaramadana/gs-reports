local QBCore = nil
local playerCooldown = {}

CreateThread(function()
    if GetResourceState('qb-core') == 'started' then
        QBCore = exports['qb-core']:GetCoreObject()
    end
end)

local function getConfig()
    shReports = shReports or {}

    shReports.Command = shReports.Command or {
        Player = 'report',
        Admin = 'reports'
    }

    shReports.Admin = shReports.Admin or {}
    shReports.Admin.UseAce = shReports.Admin.UseAce ~= false
    shReports.Admin.AcePermission = shReports.Admin.AcePermission or 'gsreports.admin'
    shReports.Admin.UseQBPermission = shReports.Admin.UseQBPermission ~= false
    shReports.Admin.QBPermissions = shReports.Admin.QBPermissions or {
        'god',
        'admin',
        'mod'
    }
    shReports.Admin.Identifiers = shReports.Admin.Identifiers or {}

    shReports.Report = shReports.Report or {}
    shReports.Report.CooldownSeconds = shReports.Report.CooldownSeconds or 60
    shReports.Report.MaxTitleLength = shReports.Report.MaxTitleLength or 150
    shReports.Report.MaxDescriptionLength = shReports.Report.MaxDescriptionLength or 1500
    shReports.Report.MaxMessageLength = shReports.Report.MaxMessageLength or 700
    shReports.Report.Categories = shReports.Report.Categories or {
        'Help',
        'Bug',
        'Player Report',
        'Donation',
        'Other'
    }
    shReports.Report.Priorities = shReports.Report.Priorities or {
        'low',
        'medium',
        'high'
    }

    shReports.Webhook = shReports.Webhook or {}
    shReports.Webhook.Enabled = shReports.Webhook.Enabled == true
    shReports.Webhook.Url = shReports.Webhook.Url or ''
    shReports.Webhook.Username = shReports.Webhook.Username or 'GS Reports'
    shReports.Webhook.Avatar = shReports.Webhook.Avatar or ''
    shReports.Webhook.Color = shReports.Webhook.Color or {
        NewReport = 5763719,
        Message = 3447003,
        Assist = 16776960,
        Solved = 5763719,
        Closed = 15548997,
        Goto = 3447003,
        Bring = 3447003
    }

    return shReports
end

local function trim(value)
    value = tostring(value or '')
    return value:match('^%s*(.-)%s*$')
end

local function clampString(value, maxLength)
    value = trim(value)

    if #value > maxLength then
        value = value:sub(1, maxLength)
    end

    return value
end

local function tableHasValue(list, value)
    for _, item in ipairs(list or {}) do
        if item == value then
            return true
        end
    end

    return false
end

local function getIdentifier(src)
    local identifiers = GetPlayerIdentifiers(src)

    for _, identifier in ipairs(identifiers) do
        if identifier:find('license:', 1, true) then
            return identifier
        end
    end

    return identifiers[1] or ('source:' .. tostring(src))
end

local function getDiscordIdentifier(src)
    local identifiers = GetPlayerIdentifiers(src)

    for _, identifier in ipairs(identifiers) do
        if identifier:find('discord:', 1, true) then
            return identifier
        end
    end

    return nil
end

local function getPlayerNameSafe(src)
    if QBCore then
        local Player = QBCore.Functions.GetPlayer(src)

        if Player and Player.PlayerData and Player.PlayerData.charinfo then
            local charinfo = Player.PlayerData.charinfo
            local firstName = charinfo.firstname or ''
            local lastName = charinfo.lastname or ''
            local fullName = trim(firstName .. ' ' .. lastName)

            if fullName ~= '' then
                return fullName
            end
        end
    end

    local name = GetPlayerName(src)

    if name and name ~= '' then
        return name
    end

    return ('Player %s'):format(src)
end

local function isAdmin(src)
    local config = getConfig()

    if src == 0 then
        return true
    end

    if config.Admin.UseAce and IsPlayerAceAllowed(src, config.Admin.AcePermission) then
        return true
    end

    local license = getIdentifier(src)
    local discord = getDiscordIdentifier(src)

    if config.Admin.Identifiers[license] then
        return true
    end

    if discord and config.Admin.Identifiers[discord] then
        return true
    end

    if config.Admin.UseQBPermission and QBCore then
        for _, permission in ipairs(config.Admin.QBPermissions or {}) do
            if QBCore.Functions.HasPermission(src, permission) then
                return true
            end
        end
    end

    return false
end

local function notify(src, title, description, notifyType, duration)
    TriggerClientEvent('ox_lib:notify', src, {
        title = title or 'Reports',
        description = description or '',
        type = notifyType or 'inform',
        duration = duration or 3500
    })
end

local function notifyAdmins(title, description, notifyType, duration)
    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)

        if src and isAdmin(src) then
            notify(src, title, description, notifyType or 'inform', duration or 6500)
        end
    end
end

local function sendWebhook(kind, title, description, fields)
    local config = getConfig()

    if not config.Webhook.Enabled then
        return
    end

    if not config.Webhook.Url or config.Webhook.Url == '' then
        return
    end

    local color = config.Webhook.Color[kind] or 3447003
    local embedFields = {}

    for _, field in ipairs(fields or {}) do
        embedFields[#embedFields + 1] = {
            name = tostring(field.name or '-'),
            value = tostring(field.value or '-'),
            inline = field.inline == true
        }
    end

    local payload = {
        username = config.Webhook.Username or 'GS Reports',
        avatar_url = config.Webhook.Avatar ~= '' and config.Webhook.Avatar or nil,
        embeds = {
            {
                title = title or 'Reports',
                description = description or '',
                color = color,
                fields = embedFields,
                footer = {
                    text = os.date('%Y-%m-%d %H:%M:%S')
                }
            }
        }
    }

    PerformHttpRequest(config.Webhook.Url, function() end, 'POST', json.encode(payload), {
        ['Content-Type'] = 'application/json'
    })
end

local function getMessages(reportId)
    local rows = MySQL.query.await([[
        SELECT
            id,
            sender_name,
            sender_role,
            message,
            DATE_FORMAT(created_at, '%H:%i') AS created_at
        FROM gs_report_messages
        WHERE report_id = ?
        ORDER BY id ASC
    ]], {
        reportId
    })

    local messages = {}

    for _, row in ipairs(rows or {}) do
        messages[#messages + 1] = {
            id = row.id,
            author = row.sender_name,
            role = row.sender_role,
            message = row.message,
            createdAt = row.created_at
        }
    end

    return messages
end

local function mapReportRow(row)
    return {
        id = row.id,
        title = row.title,
        description = row.description,
        playerName = row.reporter_name,
        playerId = row.reporter_source or 0,
        category = row.category,
        priority = row.priority,
        status = row.status,
        assignedAdmin = row.assigned_admin_name,
        createdAt = row.created_at,
        messages = {}
    }
end

local function getReports()
    local rows = MySQL.query.await([[
        SELECT
            id,
            reporter_name,
            reporter_source,
            title,
            description,
            category,
            priority,
            status,
            assigned_admin_name,
            DATE_FORMAT(created_at, '%H:%i') AS created_at
        FROM gs_reports
        ORDER BY
            CASE
                WHEN status = 'open' THEN 1
                WHEN status = 'in_progress' THEN 2
                WHEN status = 'solved' THEN 3
                ELSE 4
            END,
            id DESC
        LIMIT 100
    ]])

    local reports = {}

    for _, row in ipairs(rows or {}) do
        local report = mapReportRow(row)
        report.messages = getMessages(report.id)
        reports[#reports + 1] = report
    end

    return reports
end


local function getPlayerReports(src)
    local identifier = getIdentifier(src)

    local rows = MySQL.query.await([[
        SELECT
            id,
            reporter_name,
            reporter_source,
            title,
            description,
            category,
            priority,
            status,
            assigned_admin_name,
            DATE_FORMAT(created_at, '%H:%i') AS created_at
        FROM gs_reports
        WHERE reporter_identifier = ?
        ORDER BY id DESC
        LIMIT 10
    ]], {
        identifier
    })

    local reports = {}

    for _, row in ipairs(rows or {}) do
        local report = mapReportRow(row)
        report.messages = getMessages(report.id)
        reports[#reports + 1] = report
    end

    return reports
end

local function refreshPlayerUI(src)
    if not src or GetPlayerPing(src) <= 0 then
        return
    end

    TriggerClientEvent('gs-reports:client:setData', src, getPlayerReports(src), {})
end

local function getLeaderboard()
    local rows = MySQL.query.await([[
        SELECT
            name,
            solved_count,
            DATE_FORMAT(last_solved_at, '%d/%m/%Y %H:%i') AS last_solved_at
        FROM gs_report_admin_stats
        ORDER BY solved_count DESC, last_solved_at DESC
        LIMIT 30
    ]])

    local leaderboard = {}

    for _, row in ipairs(rows or {}) do
        leaderboard[#leaderboard + 1] = {
            name = row.name,
            solved = row.solved_count,
            lastSolved = row.last_solved_at or '-'
        }
    end

    return leaderboard
end

local function refreshAdminUIs()
    local reports = getReports()
    local leaderboard = getLeaderboard()

    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)

        if src and isAdmin(src) then
            TriggerClientEvent('gs-reports:client:setData', src, reports, leaderboard)
        end
    end
end

local function getReportById(reportId)
    return MySQL.single.await([[
        SELECT
            *
        FROM gs_reports
        WHERE id = ?
    ]], {
        reportId
    })
end

local function getPlayerCoords(src)
    local ped = GetPlayerPed(src)

    if not ped or ped == 0 then
        return nil
    end

    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    if not coords then
        return nil
    end

    return {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        heading = heading
    }
end

RegisterNetEvent('gs-reports:server:requestOpenPlayer', function()
    local src = source

    TriggerClientEvent('gs-reports:client:openPlayer', src, getPlayerReports(src))
end)

RegisterNetEvent('gs-reports:server:requestOpenAdmin', function()
    local src = source

    if not isAdmin(src) then
        notify(src, 'Reports', 'Kamu tidak punya akses admin reports.', 'error')
        return
    end

    local reports = getReports()
    local leaderboard = getLeaderboard()

    TriggerClientEvent('gs-reports:client:openAdmin', src, reports, leaderboard)
end)

lib.callback.register('gs-reports:server:createReport', function(src, data)
    local config = getConfig()
    local now = os.time()
    local last = playerCooldown[src] or 0
    local cooldown = config.Report.CooldownSeconds or 60

    if now - last < cooldown then
        return {
            ok = false,
            message = ('Tunggu %s detik sebelum membuat report lagi.'):format(cooldown - (now - last))
        }
    end

    local title = clampString(data and data.title or '', config.Report.MaxTitleLength or 150)
    local description = clampString(data and data.description or '', config.Report.MaxDescriptionLength or 1500)
    local category = clampString(data and data.category or 'Help', 60)
    local priority = clampString(data and data.priority or 'medium', 20)

    if title == '' or description == '' then
        return {
            ok = false,
            message = 'Title dan description wajib diisi.'
        }
    end

    if not tableHasValue(config.Report.Categories, category) then
        category = 'Help'
    end

    if not tableHasValue(config.Report.Priorities, priority) then
        priority = 'medium'
    end

    local identifier = getIdentifier(src)
    local reporterName = getPlayerNameSafe(src)

    local reportId = MySQL.insert.await([[
        INSERT INTO gs_reports
            (
                reporter_identifier,
                reporter_name,
                reporter_source,
                title,
                description,
                category,
                priority,
                status
            )
        VALUES
            (?, ?, ?, ?, ?, ?, ?, 'open')
    ]], {
        identifier,
        reporterName,
        src,
        title,
        description,
        category,
        priority
    })

    if not reportId then
        return {
            ok = false,
            message = 'Gagal membuat report ke database.'
        }
    end

    MySQL.insert.await([[
        INSERT INTO gs_report_messages
            (
                report_id,
                sender_identifier,
                sender_name,
                sender_role,
                message
            )
        VALUES
            (?, ?, ?, 'player', ?)
    ]], {
        reportId,
        identifier,
        reporterName,
        description
    })

    playerCooldown[src] = now

    notify(src, 'Reports', ('Report #%s berhasil dikirim ke admin.'):format(reportId), 'success')

    notifyAdmins(
        'New Report',
        ('%s membuat report baru #%s: %s'):format(reporterName, reportId, title),
        'inform',
        7500
    )

    sendWebhook('NewReport', ('New Report #%s'):format(reportId), title, {
        {
            name = 'Reporter',
            value = ('%s / ID %s'):format(reporterName, src),
            inline = true
        },
        {
            name = 'Category',
            value = category,
            inline = true
        },
        {
            name = 'Priority',
            value = priority,
            inline = true
        },
        {
            name = 'Description',
            value = description,
            inline = false
        }
    })

    refreshAdminUIs()
    refreshPlayerUI(src)

    return {
        ok = true,
        message = 'Report berhasil dikirim.',
        reportId = reportId
    }
end)

lib.callback.register('gs-reports:server:sendMessage', function(src, data)
    local config = getConfig()
    local reportId = tonumber(data and data.reportId)
    local message = clampString(data and data.message or '', config.Report.MaxMessageLength or 700)

    if not reportId or message == '' then
        return {
            ok = false,
            message = 'Pesan tidak valid.'
        }
    end

    local report = getReportById(reportId)

    if not report then
        return {
            ok = false,
            message = 'Report tidak ditemukan.'
        }
    end

    local identifier = getIdentifier(src)
    local senderName = getPlayerNameSafe(src)
    local role = 'player'

    if isAdmin(src) then
        role = 'admin'
    elseif report.reporter_identifier ~= identifier then
        return {
            ok = false,
            message = 'Kamu bukan pelapor report ini.'
        }
    end

    MySQL.insert.await([[
        INSERT INTO gs_report_messages
            (
                report_id,
                sender_identifier,
                sender_name,
                sender_role,
                message
            )
        VALUES
            (?, ?, ?, ?, ?)
    ]], {
        reportId,
        identifier,
        senderName,
        role,
        message
    })

    sendWebhook('Message', ('Report #%s Message'):format(reportId), message, {
        {
            name = 'Sender',
            value = senderName,
            inline = true
        },
        {
            name = 'Role',
            value = role,
            inline = true
        }
    })

    local reporterSource = tonumber(report.reporter_source)

    if role == 'admin' and reporterSource and GetPlayerPing(reporterSource) > 0 then
        notify(reporterSource, 'Reports', ('Admin membalas report #%s kamu.'):format(reportId), 'inform')
        refreshPlayerUI(reporterSource)
    elseif role == 'player' then
        refreshPlayerUI(src)
        notifyAdmins('Report Chat', ('%s membalas chat report #%s.'):format(senderName, reportId), 'inform', 4500)
    end

    refreshAdminUIs()

    return {
        ok = true,
        message = 'Pesan terkirim.'
    }
end)

lib.callback.register('gs-reports:server:assistReport', function(src, data)
    if not isAdmin(src) then
        return {
            ok = false,
            message = 'No permission.'
        }
    end

    local reportId = tonumber(data and data.reportId)

    if not reportId then
        return {
            ok = false,
            message = 'Report tidak valid.'
        }
    end

    local report = getReportById(reportId)

    if not report then
        return {
            ok = false,
            message = 'Report tidak ditemukan.'
        }
    end

    local adminIdentifier = getIdentifier(src)
    local adminName = getPlayerNameSafe(src)

    MySQL.update.await([[
        UPDATE gs_reports
        SET
            status = 'in_progress',
            assigned_admin_identifier = ?,
            assigned_admin_name = ?
        WHERE id = ?
    ]], {
        adminIdentifier,
        adminName,
        reportId
    })

    MySQL.insert.await([[
        INSERT INTO gs_report_messages
            (
                report_id,
                sender_identifier,
                sender_name,
                sender_role,
                message
            )
        VALUES
            (?, ?, 'System', 'system', ?)
    ]], {
        reportId,
        adminIdentifier,
        ('%s mengambil report ini.'):format(adminName)
    })

    local reporterSource = tonumber(report.reporter_source)

    if reporterSource and GetPlayerPing(reporterSource) > 0 then
        notify(reporterSource, 'Reports', ('Admin %s sedang menangani report kamu.'):format(adminName), 'inform')
        refreshPlayerUI(reporterSource)
    end

    sendWebhook('Assist', ('Report #%s Assisted'):format(reportId), ('%s mengambil report ini.'):format(adminName), {
        {
            name = 'Reporter',
            value = report.reporter_name or '-',
            inline = true
        },
        {
            name = 'Admin',
            value = adminName,
            inline = true
        }
    })

    refreshAdminUIs()

    return {
        ok = true,
        message = 'Report diambil.'
    }
end)

lib.callback.register('gs-reports:server:solveReport', function(src, data)
    if not isAdmin(src) then
        return {
            ok = false,
            message = 'No permission.'
        }
    end

    local reportId = tonumber(data and data.reportId)

    if not reportId then
        return {
            ok = false,
            message = 'Report tidak valid.'
        }
    end

    local report = getReportById(reportId)

    if not report then
        return {
            ok = false,
            message = 'Report tidak ditemukan.'
        }
    end

    if report.status == 'solved' then
        return {
            ok = false,
            message = 'Report sudah solved.'
        }
    end

    local adminIdentifier = getIdentifier(src)
    local adminName = getPlayerNameSafe(src)

    MySQL.update.await([[
        UPDATE gs_reports
        SET
            status = 'solved',
            assigned_admin_identifier = COALESCE(assigned_admin_identifier, ?),
            assigned_admin_name = COALESCE(assigned_admin_name, ?),
            solved_by_identifier = ?,
            solved_by_name = ?,
            solved_at = NOW()
        WHERE id = ?
    ]], {
        adminIdentifier,
        adminName,
        adminIdentifier,
        adminName,
        reportId
    })

    MySQL.insert.await([[
        INSERT INTO gs_report_messages
            (
                report_id,
                sender_identifier,
                sender_name,
                sender_role,
                message
            )
        VALUES
            (?, ?, 'System', 'system', ?)
    ]], {
        reportId,
        adminIdentifier,
        ('Report diselesaikan oleh %s.'):format(adminName)
    })

    MySQL.insert.await([[
        INSERT INTO gs_report_admin_stats
            (
                identifier,
                name,
                solved_count,
                last_solved_at
            )
        VALUES
            (?, ?, 1, NOW())
        ON DUPLICATE KEY UPDATE
            name = VALUES(name),
            solved_count = solved_count + 1,
            last_solved_at = NOW()
    ]], {
        adminIdentifier,
        adminName
    })

    local reporterSource = tonumber(report.reporter_source)

    if reporterSource and GetPlayerPing(reporterSource) > 0 then
        notify(reporterSource, 'Reports', ('Report #%s kamu sudah diselesaikan.'):format(reportId), 'success')
        refreshPlayerUI(reporterSource)
    end

    sendWebhook('Solved', ('Report #%s Solved'):format(reportId), ('Report diselesaikan oleh %s.'):format(adminName), {
        {
            name = 'Reporter',
            value = report.reporter_name or '-',
            inline = true
        },
        {
            name = 'Admin',
            value = adminName,
            inline = true
        }
    })

    refreshAdminUIs()

    return {
        ok = true,
        message = 'Report solved.'
    }
end)

lib.callback.register('gs-reports:server:closeReport', function(src, data)
    if not isAdmin(src) then
        return {
            ok = false,
            message = 'No permission.'
        }
    end

    local reportId = tonumber(data and data.reportId)

    if not reportId then
        return {
            ok = false,
            message = 'Report tidak valid.'
        }
    end

    local report = getReportById(reportId)

    if not report then
        return {
            ok = false,
            message = 'Report tidak ditemukan atau sudah dihapus.'
        }
    end

    local adminName = getPlayerNameSafe(src)
    local reporterSource = tonumber(report.reporter_source)

    sendWebhook('Closed', ('Report #%s Closed & Deleted'):format(reportId),
        ('Report ditutup dan dihapus oleh %s.'):format(adminName), {
        {
            name = 'Reporter',
            value = report.reporter_name or '-',
            inline = true
        },
        {
            name = 'Admin',
            value = adminName,
            inline = true
        },
        {
            name = 'Title',
            value = report.title or '-',
            inline = false
        }
    })

    MySQL.update.await('DELETE FROM gs_report_messages WHERE report_id = ?', {
        reportId
    })

    local affectedRows = MySQL.update.await('DELETE FROM gs_reports WHERE id = ?', {
        reportId
    })

    if not affectedRows or affectedRows < 1 then
        return {
            ok = false,
            message = 'Gagal menghapus report dari database.'
        }
    end

    if reporterSource and GetPlayerPing(reporterSource) > 0 then
        notify(
            reporterSource,
            'Reports',
            ('Report #%s kamu sudah ditutup oleh admin.'):format(reportId),
            'inform'
        )
        refreshPlayerUI(reporterSource)
    end

    notify(src, 'Reports', ('Report #%s berhasil ditutup dan dihapus.'):format(reportId), 'success')

    refreshAdminUIs()

    return {
        ok = true,
        message = 'Report ditutup dan data berhasil dihapus.'
    }
end)

lib.callback.register('gs-reports:server:gotoReporter', function(src, data)
    if not isAdmin(src) then
        return {
            ok = false,
            message = 'No permission.'
        }
    end

    local reportId = tonumber(data and data.reportId)

    if not reportId then
        return {
            ok = false,
            message = 'Report tidak valid.'
        }
    end

    local report = getReportById(reportId)

    if not report then
        return {
            ok = false,
            message = 'Report tidak ditemukan.'
        }
    end

    local reporterSource = tonumber(report.reporter_source)

    if not reporterSource or GetPlayerPing(reporterSource) <= 0 then
        return {
            ok = false,
            message = 'Reporter sedang offline.'
        }
    end

    local coords = getPlayerCoords(reporterSource)

    if not coords then
        return {
            ok = false,
            message = 'Gagal mengambil koordinat reporter.'
        }
    end

    TriggerClientEvent('gs-reports:client:teleportToCoords', src, coords)

    sendWebhook('Goto', ('Report #%s Goto'):format(reportId),
        ('Admin %s teleport ke reporter %s.'):format(getPlayerNameSafe(src), report.reporter_name or '-'), {
        {
            name = 'Reporter',
            value = report.reporter_name or '-',
            inline = true
        },
        {
            name = 'Admin',
            value = getPlayerNameSafe(src),
            inline = true
        }
    })

    return {
        ok = true,
        message = ('Teleport ke %s berhasil.'):format(report.reporter_name or 'reporter')
    }
end)

lib.callback.register('gs-reports:server:bringReporter', function(src, data)
    if not isAdmin(src) then
        return {
            ok = false,
            message = 'No permission.'
        }
    end

    local reportId = tonumber(data and data.reportId)

    if not reportId then
        return {
            ok = false,
            message = 'Report tidak valid.'
        }
    end

    local report = getReportById(reportId)

    if not report then
        return {
            ok = false,
            message = 'Report tidak ditemukan.'
        }
    end

    local reporterSource = tonumber(report.reporter_source)

    if not reporterSource or GetPlayerPing(reporterSource) <= 0 then
        return {
            ok = false,
            message = 'Reporter sedang offline.'
        }
    end

    local adminCoords = getPlayerCoords(src)

    if not adminCoords then
        return {
            ok = false,
            message = 'Gagal mengambil koordinat admin.'
        }
    end

    TriggerClientEvent('gs-reports:client:teleportToCoords', reporterSource, adminCoords)

    notify(reporterSource, 'Reports', ('Kamu dibawa oleh admin %s.'):format(getPlayerNameSafe(src)), 'inform')

    sendWebhook('Bring', ('Report #%s Bring'):format(reportId),
        ('Admin %s membawa reporter %s.'):format(getPlayerNameSafe(src), report.reporter_name or '-'), {
        {
            name = 'Reporter',
            value = report.reporter_name or '-',
            inline = true
        },
        {
            name = 'Admin',
            value = getPlayerNameSafe(src),
            inline = true
        }
    })

    return {
        ok = true,
        message = ('%s berhasil dibawa.'):format(report.reporter_name or 'Reporter')
    }
end)

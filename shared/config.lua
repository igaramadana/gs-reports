shReports = {}

shReports.Command = {
    Player = 'report',
    Admin = 'reports',
}

shReports.Admin = {
    UseAce = true,
    AcePermission = 'gsreports.admin',

    UseQBPermission = true,
    QBPermissions = {
        'god',
        'admin',
        'mod',
    },

    Identifiers = {
        -- ['license:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'] = true,
        -- ['discord:123456789012345678'] = true,
    }
}

shReports.Report = {
    CooldownSeconds = 60,

    Categories = {
        'Help',
        'Bug',
        'Player Report',
        'Donation',
        'Other',
    },

    Priorities = {
        'low',
        'medium',
        'high',
    },

    MaxTitleLength = 150,
    MaxDescriptionLength = 1500,
    MaxMessageLength = 700,
}

shReports.Actions = {
    Goto = true,
    Bring = true,
    MinimumDistanceFromAdmin = 1.5,
}

shReports.Webhook = {
    Enabled = false,
    Url = '',
    Username = 'Orizon Reports',
    Avatar = '',
    Color = {
        NewReport = 5763719,
        Message = 3447003,
        Assist = 16776960,
        Solved = 5763719,
        Closed = 15548997,
        Action = 10181046,
    }
}

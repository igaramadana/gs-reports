CREATE TABLE IF NOT EXISTS gs_reports (
    id INT AUTO_INCREMENT PRIMARY KEY,
    reporter_identifier VARCHAR(100) NOT NULL,
    reporter_name VARCHAR(100) NOT NULL,
    reporter_source INT NULL,
    title VARCHAR(150) NOT NULL,
    description TEXT NOT NULL,
    category VARCHAR(60) NOT NULL DEFAULT 'Help',
    priority VARCHAR(20) NOT NULL DEFAULT 'medium',
    status VARCHAR(30) NOT NULL DEFAULT 'open',
    assigned_admin_identifier VARCHAR(100) NULL,
    assigned_admin_name VARCHAR(100) NULL,
    solved_by_identifier VARCHAR(100) NULL,
    solved_by_name VARCHAR(100) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    solved_at TIMESTAMP NULL
);

CREATE TABLE IF NOT EXISTS gs_report_messages (
    id INT AUTO_INCREMENT PRIMARY KEY,
    report_id INT NOT NULL,
    sender_identifier VARCHAR(100) NULL,
    sender_name VARCHAR(100) NOT NULL,
    sender_role VARCHAR(30) NOT NULL,
    message TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_report_messages_report_id (report_id),
    CONSTRAINT fk_gs_report_messages_report
        FOREIGN KEY (report_id)
        REFERENCES gs_reports(id)
        ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS gs_report_admin_stats (
    identifier VARCHAR(100) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    solved_count INT NOT NULL DEFAULT 0,
    last_solved_at TIMESTAMP NULL
);

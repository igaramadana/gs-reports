import React, { useEffect, useMemo, useRef, useState } from "react";
import ReactDOM from "react-dom/client";
import {
  FaBug,
  FaCheck,
  FaCheckCircle,
  FaClock,
  FaComments,
  FaExclamationTriangle,
  FaLocationArrow,
  FaPaperPlane,
  FaPeopleArrows,
  FaPlus,
  FaSearch,
  FaShieldAlt,
  FaSignOutAlt,
  FaStar,
  FaTimes,
  FaTrophy,
  FaUser,
  FaUserShield,
} from "react-icons/fa";
import "./index.css";

type ViewMode = "admin" | "player" | "leaderboard";
type ReportStatus = "open" | "in_progress" | "solved" | "closed";
type ReportPriority = "low" | "medium" | "high";
type ReportMessageRole = "player" | "admin" | "system";

type ReportMessage = {
  id: number;
  author: string;
  role: ReportMessageRole;
  message: string;
  createdAt: string;
};

type Report = {
  id: number;
  title: string;
  description: string;
  playerName: string;
  playerId: number;
  category: string;
  priority: ReportPriority;
  status: ReportStatus;
  assignedAdmin?: string;
  createdAt: string;
  messages: ReportMessage[];
};

type LeaderboardItem = {
  name: string;
  solved: number;
  lastSolved?: string;
};

type AppState = {
  visible: boolean;
  mode: ViewMode;
  adminName: string;
  reports: Report[];
  leaderboard: LeaderboardItem[];
};

type ReportForm = {
  title: string;
  category: string;
  priority: ReportPriority;
  description: string;
};

type Stats = {
  open: number;
  progress: number;
  solved: number;
};

declare global {
  interface Window {
    GetParentResourceName?: () => string;
  }
}

const isFiveM =
  typeof window !== "undefined" &&
  typeof window.GetParentResourceName === "function";

const EMPTY_FORM: ReportForm = {
  title: "",
  category: "Help",
  priority: "medium",
  description: "",
};

const mockReports: Report[] = [
  {
    id: 101,
    title: "Player RDM di Legion Square",
    description:
      "Ada player yang menembak warga tanpa alasan di dekat Legion Square. Saya punya bukti clip pendek.",
    playerName: "Atherosmurf",
    playerId: 12,
    category: "Player Report",
    priority: "high",
    status: "open",
    createdAt: "14:20",
    messages: [
      {
        id: 1,
        author: "Atherosmurf",
        role: "player",
        message: "Min tolong cek, ada player RDM di Legion.",
        createdAt: "14:20",
      },
      {
        id: 2,
        author: "System",
        role: "system",
        message: "Report berhasil dibuat dan sedang menunggu admin.",
        createdAt: "14:20",
      },
    ],
  },
  {
    id: 102,
    title: "Bug inventory tidak bisa dibuka",
    description:
      "Inventory saya tidak bisa terbuka setelah relog. Sudah coba restart game masih sama.",
    playerName: "Bima",
    playerId: 22,
    category: "Bug",
    priority: "medium",
    status: "in_progress",
    assignedAdmin: "Admin Iga",
    createdAt: "14:33",
    messages: [
      {
        id: 1,
        author: "Bima",
        role: "player",
        message: "Inventory saya tidak bisa kebuka min.",
        createdAt: "14:33",
      },
      {
        id: 2,
        author: "Admin Iga",
        role: "admin",
        message: "Oke saya cek dulu ya, jangan relog dulu.",
        createdAt: "14:34",
      },
    ],
  },
];

const mockLeaderboard: LeaderboardItem[] = [
  { name: "Admin Iga", solved: 28, lastSolved: "Hari ini" },
  { name: "Admin Naufal", solved: 19, lastSolved: "Kemarin" },
  { name: "Admin Dimas", solved: 12, lastSolved: "2 hari lalu" },
];

function getInitialMode(): ViewMode {
  const params = new URLSearchParams(window.location.search);
  const mode = params.get("mode");

  if (mode === "player" || mode === "leaderboard" || mode === "admin") {
    return mode;
  }

  return "admin";
}

function nowTime() {
  return new Date().toLocaleTimeString("id-ID", {
    hour: "2-digit",
    minute: "2-digit",
  });
}

function statusLabel(status: ReportStatus) {
  const map: Record<ReportStatus, string> = {
    open: "Open",
    in_progress: "Progress",
    solved: "Solved",
    closed: "Closed",
  };

  return map[status];
}

function priorityLabel(priority: ReportPriority) {
  const map: Record<ReportPriority, string> = {
    low: "Low",
    medium: "Medium",
    high: "High",
  };

  return map[priority];
}

function statusClass(status: ReportStatus) {
  if (status === "open") return "badge lime";
  if (status === "in_progress") return "badge orange";
  if (status === "solved") return "badge lime";

  return "badge gray";
}

function priorityClass(priority: ReportPriority) {
  if (priority === "high") return "badge red";
  if (priority === "medium") return "badge orange";

  return "badge gray";
}

function isBugCategory(category: string) {
  return category.toLowerCase() === "bug";
}

async function nui<T = unknown>(
  eventName: string,
  data?: Record<string, unknown>
): Promise<T | null> {
  if (!isFiveM) return Promise.resolve(null);

  const resource = window.GetParentResourceName?.() ?? "gs-reports";

  try {
    const response = await fetch(`https://${resource}/${eventName}`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json; charset=UTF-8",
      },
      body: JSON.stringify(data ?? {}),
    });

    return await response.json();
  } catch {
    return null;
  }
}

function App() {
  const [state, setState] = useState<AppState>({
    visible: !isFiveM,
    mode: getInitialMode(),
    adminName: "Admin Iga",
    reports: mockReports,
    leaderboard: mockLeaderboard,
  });

  const [selectedId, setSelectedId] = useState<number>(
    mockReports[0]?.id ?? 0
  );
  const [query, setQuery] = useState("");
  const [chatText, setChatText] = useState("");
  const [form, setForm] = useState<ReportForm>(EMPTY_FORM);

  useEffect(() => {
    setChatText("");
  }, [selectedId, state.mode]);

  useEffect(() => {
    const handler = (event: MessageEvent) => {
      const data = event.data;

      if (!data || typeof data !== "object") return;

      if (data.action === "open") {
        const nextReports = Array.isArray(data.reports)
          ? data.reports
          : state.reports;

        setState((prev) => ({
          ...prev,
          visible: true,
          mode: data.mode ?? prev.mode,
          adminName: data.adminName ?? prev.adminName,
          reports: nextReports,
          leaderboard: data.leaderboard ?? prev.leaderboard,
        }));

        if (nextReports.length > 0) {
          setSelectedId(nextReports[0].id);
        }

        return;
      }

      if (data.action === "close") {
        setState((prev) => ({
          ...prev,
          visible: false,
        }));

        return;
      }

      if (data.action === "setData") {
        const nextReports = Array.isArray(data.reports) ? data.reports : state.reports;

        setState((prev) => ({
          ...prev,
          reports: nextReports,
          leaderboard: data.leaderboard ?? prev.leaderboard,
        }));

        if (nextReports.length > 0) {
          const stillSelected = nextReports.some((report: Report) => report.id === selectedId);

          if (!stillSelected) {
            setSelectedId(nextReports[0].id);
          }
        } else {
          setSelectedId(0);
        }
      }
    };

    window.addEventListener("message", handler);

    return () => window.removeEventListener("message", handler);
  }, [state.reports, selectedId]);

  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        handleClose();
      }
    };

    window.addEventListener("keydown", onKey);

    return () => window.removeEventListener("keydown", onKey);
  });

  const filteredReports = useMemo(() => {
    const normalized = query.trim().toLowerCase();

    if (!normalized) return state.reports;

    return state.reports.filter((report) => {
      return (
        report.title.toLowerCase().includes(normalized) ||
        report.playerName.toLowerCase().includes(normalized) ||
        String(report.playerId).includes(normalized) ||
        report.category.toLowerCase().includes(normalized) ||
        report.status.toLowerCase().includes(normalized)
      );
    });
  }, [state.reports, query]);

  const selectedReport =
    state.reports.find((report) => report.id === selectedId) ??
    filteredReports[0];

  const stats = useMemo<Stats>(() => {
    return {
      open: state.reports.filter((report) => report.status === "open").length,
      progress: state.reports.filter(
        (report) => report.status === "in_progress"
      ).length,
      solved: state.reports.filter((report) => report.status === "solved")
        .length,
    };
  }, [state.reports]);

  function patchReport(reportId: number, patch: Partial<Report>) {
    setState((prev) => ({
      ...prev,
      reports: prev.reports.map((report) => {
        if (report.id !== reportId) return report;

        return {
          ...report,
          ...patch,
        };
      }),
    }));
  }

  function handleClose() {
    if (isFiveM) {
      nui("close");
    }

    setState((prev) => ({
      ...prev,
      visible: false,
    }));
  }

  function switchMode(mode: ViewMode) {
    setState((prev) => ({
      ...prev,
      mode,
    }));
  }

  async function handleSendMessage() {
    const message = chatText.trim();

    if (!message || !selectedReport) return;

    if (isFiveM) {
      await nui("sendMessage", {
        reportId: selectedReport.id,
        message,
      });
    } else {
      const nextMessage: ReportMessage = {
        id: Date.now(),
        author:
          state.mode === "admin" ? state.adminName : selectedReport.playerName,
        role: state.mode === "admin" ? "admin" : "player",
        message,
        createdAt: nowTime(),
      };

      patchReport(selectedReport.id, {
        messages: [...selectedReport.messages, nextMessage],
      });
    }

    setChatText("");
  }

  function handleAssist() {
    if (!selectedReport) return;

    if (isFiveM) {
      nui("assistReport", {
        reportId: selectedReport.id,
      });

      return;
    }

    patchReport(selectedReport.id, {
      status: "in_progress",
      assignedAdmin: state.adminName,
    });
  }

  function handleSolve() {
    if (!selectedReport) return;

    if (isFiveM) {
      nui("solveReport", {
        reportId: selectedReport.id,
      });

      return;
    }

    patchReport(selectedReport.id, {
      status: "solved",
      assignedAdmin: state.adminName,
    });
  }

  function handleCloseReport() {
    if (!selectedReport) return;

    if (isFiveM) {
      nui("closeReport", {
        reportId: selectedReport.id,
      });

      return;
    }

    patchReport(selectedReport.id, {
      status: "closed",
    });
  }

  function handleGotoReporter() {
    if (!selectedReport) return;

    if (isFiveM) {
      nui("gotoReporter", {
        reportId: selectedReport.id,
      });

      return;
    }

    console.log("[Preview] Goto reporter", selectedReport.playerId);
  }

  function handleBringReporter() {
    if (!selectedReport) return;

    if (isFiveM) {
      nui("bringReporter", {
        reportId: selectedReport.id,
      });

      return;
    }

    console.log("[Preview] Bring reporter", selectedReport.playerId);
  }

  async function handleCreateReport() {
    const title = form.title.trim();
    const description = form.description.trim();

    if (!title || !description) return;

    if (isFiveM) {
      await nui("createReport", {
        title,
        category: form.category,
        priority: form.priority,
        description,
      });
    } else {
      const newReport: Report = {
        id: Math.floor(Math.random() * 9000) + 1000,
        title,
        description,
        playerName: "Preview Player",
        playerId: 99,
        category: form.category,
        priority: form.priority,
        status: "open",
        createdAt: nowTime(),
        messages: [
          {
            id: Date.now(),
            author: "Preview Player",
            role: "player",
            message: description,
            createdAt: nowTime(),
          },
        ],
      };

      setState((prev) => ({
        ...prev,
        reports: [newReport, ...prev.reports],
        mode: "admin",
      }));

      setSelectedId(newReport.id);
    }

    setForm(EMPTY_FORM);
  }

  if (!state.visible) return null;

  if (state.mode === "player") {
    return (
      <main className="app-root">
        <PlayerReportView
          form={form}
          setForm={setForm}
          activeReport={selectedReport}
          chatText={chatText}
          setChatText={setChatText}
          onSubmit={handleCreateReport}
          onSendMessage={handleSendMessage}
          onClose={handleClose}
        />
      </main>
    );
  }

  return (
    <main className="app-root">
      <section className="report-shell">
        <Sidebar
          mode={state.mode}
          stats={stats}
          onModeChange={switchMode}
          onClose={handleClose}
        />

        <section className="main-panel">
          <Header
            mode={state.mode}
            query={query}
            setQuery={setQuery}
            onClose={handleClose}
          />

          <div className="content">
            {state.mode === "admin" && (
              <section className="dashboard-grid">
                <ReportList
                  reports={filteredReports}
                  selectedId={selectedReport?.id ?? 0}
                  onSelect={setSelectedId}
                />

                <ReportDetail
                  report={selectedReport}
                  adminName={state.adminName}
                  chatText={chatText}
                  setChatText={setChatText}
                  onSendMessage={handleSendMessage}
                  onAssist={handleAssist}
                  onSolve={handleSolve}
                  onCloseReport={handleCloseReport}
                  onGotoReporter={handleGotoReporter}
                  onBringReporter={handleBringReporter}
                />
              </section>
            )}

            {state.mode === "leaderboard" && (
              <Leaderboard leaderboard={state.leaderboard} />
            )}
          </div>
        </section>
      </section>
    </main>
  );
}

function Sidebar({
  mode,
  stats,
  onModeChange,
  onClose,
}: {
  mode: ViewMode;
  stats: Stats;
  onModeChange: (mode: ViewMode) => void;
  onClose: () => void;
}) {
  return (
    <aside className="sidebar">
      <div className="brand-card">
        <div className="brand-row">
          <div className="brand-icon">
            <FaShieldAlt />
          </div>

          <div>
            <h1 className="brand-title">Reports</h1>
            <p className="brand-desc">Admin support center</p>
          </div>
        </div>
      </div>

      <div className="kpi-row">
        <StatCard icon={<FaClock />} value={stats.open} label="Open" />
        <StatCard
          icon={<FaComments />}
          value={stats.progress}
          label="Progress"
        />
        <StatCard
          icon={<FaCheckCircle />}
          value={stats.solved}
          label="Solved"
        />
      </div>

      <nav className="nav-stack">
        <NavButton
          active={mode === "admin"}
          icon={<FaUserShield />}
          label="Admin"
          count={stats.open + stats.progress}
          onClick={() => onModeChange("admin")}
        />

        <NavButton
          active={mode === "leaderboard"}
          icon={<FaTrophy />}
          label="Ranking"
          count={<FaStar />}
          onClick={() => onModeChange("leaderboard")}
        />
      </nav>

      <div className="sidebar-footer">
        <div className="footer-icon">
          <FaPeopleArrows />
        </div>

        <div>
          <h3 className="sidebar-footer-title">Actions</h3>
          <p className="sidebar-footer-desc">Goto + bring reporter.</p>
        </div>
      </div>

      <button className="btn btn-ghost full-btn" onClick={onClose}>
        <FaSignOutAlt />
        Close
      </button>
    </aside>
  );
}

function StatCard({
  icon,
  value,
  label,
}: {
  icon: React.ReactNode;
  value: number;
  label: string;
}) {
  return (
    <div className="kpi-card">
      <span className="kpi-icon">{icon}</span>

      <div>
        <p className="kpi-value">{value}</p>
        <div className="kpi-label">{label}</div>
      </div>
    </div>
  );
}

function NavButton({
  active,
  icon,
  label,
  count,
  onClick,
}: {
  active: boolean;
  icon: React.ReactNode;
  label: string;
  count: React.ReactNode;
  onClick: () => void;
}) {
  return (
    <button
      className={`nav-button ${active ? "active" : ""}`}
      onClick={onClick}
    >
      <span className="nav-left">
        {icon}
        {label}
      </span>

      <span className="nav-count">{count}</span>
    </button>
  );
}

function Header({
  mode,
  query,
  setQuery,
  onClose,
}: {
  mode: ViewMode;
  query: string;
  setQuery: (value: string) => void;
  onClose: () => void;
}) {
  const titleMap: Record<ViewMode, string> = {
    admin: "Report Center",
    player: "Create Report",
    leaderboard: "Admin Ranking",
  };

  const subtitleMap: Record<ViewMode, string> = {
    admin: "Manage, reply, goto, bring, and solve reports.",
    player: "Send a clear report so admins can help faster.",
    leaderboard: "Top admins based on solved reports.",
  };

  return (
    <header className="topbar">
      <div>
        <h2 className="page-title">{titleMap[mode]}</h2>
        <p className="page-subtitle">{subtitleMap[mode]}</p>
      </div>

      <div className="topbar-actions">
        {mode === "admin" && (
          <div className="search-wrapper">
            <FaSearch />

            <input
              className="search-box"
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="Search..."
            />
          </div>
        )}

        <button className="icon-button" onClick={onClose}>
          <FaTimes />
        </button>
      </div>
    </header>
  );
}

function ReportList({
  reports,
  selectedId,
  onSelect,
}: {
  reports: Report[];
  selectedId: number;
  onSelect: (id: number) => void;
}) {
  return (
    <aside className="report-list-card">
      <div className="card-header compact">
        <div>
          <h3 className="card-title">Queue</h3>
          <p className="card-desc">Incoming reports</p>
        </div>

        <FaComments className="card-header-icon" />
      </div>

      <div className="report-list scroll-area">
        {reports.length === 0 && (
          <EmptyState
            icon={<FaSearch />}
            title="No Report"
            description="No matching report found."
          />
        )}

        {reports.map((report) => (
          <ReportListItem
            key={report.id}
            report={report}
            active={selectedId === report.id}
            onSelect={() => onSelect(report.id)}
          />
        ))}
      </div>
    </aside>
  );
}

function ReportListItem({
  report,
  active,
  onSelect,
}: {
  report: Report;
  active: boolean;
  onSelect: () => void;
}) {
  return (
    <button
      className={`report-item ${active ? "active" : ""}`}
      onClick={onSelect}
    >
      <div className="report-item-top">
        <div className="report-main-info">
          <div className="report-icon">
            {isBugCategory(report.category) ? <FaBug /> : <FaUser />}
          </div>

          <div>
            <div className="report-id">#{report.id}</div>
            <div className="report-title">{report.title}</div>
          </div>
        </div>

        <span className={statusClass(report.status)}>
          {statusLabel(report.status)}
        </span>
      </div>

      <div className="report-meta">
        <span>
          <FaUser />
          {report.playerName}
        </span>

        <span>
          <FaClock />
          {report.createdAt}
        </span>
      </div>
    </button>
  );
}

function EmptyState({
  icon,
  title,
  description,
}: {
  icon: React.ReactNode;
  title: string;
  description: string;
}) {
  return (
    <div className="detail-empty">
      <div>
        <div className="empty-icon">{icon}</div>
        <h3 className="card-title">{title}</h3>
        <p className="card-desc">{description}</p>
      </div>
    </div>
  );
}

function getVisibleMessages(report?: Report) {
  if (!report) return [];

  const description = report.description.trim();
  const first = report.messages[0];

  if (
    first &&
    first.role === "player" &&
    description.length > 0 &&
    first.message.trim() === description
  ) {
    return report.messages.slice(1);
  }

  return report.messages;
}

function ReportDetail({
  report,
  adminName,
  chatText,
  setChatText,
  onSendMessage,
  onAssist,
  onSolve,
  onCloseReport,
  onGotoReporter,
  onBringReporter,
}: {
  report?: Report;
  adminName: string;
  chatText: string;
  setChatText: (value: string) => void;
  onSendMessage: () => void;
  onAssist: () => void;
  onSolve: () => void;
  onCloseReport: () => void;
  onGotoReporter: () => void;
  onBringReporter: () => void;
}) {
  const chatRef = useRef<HTMLDivElement | null>(null);
  const visibleMessages = getVisibleMessages(report);

  useEffect(() => {
    const el = chatRef.current;
    if (!el) return;

    el.scrollTop = el.scrollHeight;
  }, [report?.id, report?.messages.length]);

  if (!report) {
    return (
      <section className="detail-card">
        <EmptyState
          icon={<FaComments />}
          title="Select Report"
          description="Choose a report from queue."
        />
      </section>
    );
  }

  return (
    <section className="detail-card">
      <div className="detail-head">
        <div className="detail-info">
          <ReportTags report={report} />

          <h3 className="detail-title">{report.title}</h3>
          <p className="detail-desc">{report.description}</p>

          <div className="report-meta">
            <span>
              <FaUser />
              {report.playerName} / ID {report.playerId}
            </span>

            <span>
              <FaUserShield />
              {report.assignedAdmin ?? "-"}
            </span>
          </div>
        </div>

        <ReportActions
          onGotoReporter={onGotoReporter}
          onBringReporter={onBringReporter}
          onAssist={onAssist}
          onSolve={onSolve}
          onCloseReport={onCloseReport}
        />
      </div>

      <div ref={chatRef} className="chat-area scroll-area">
        {visibleMessages.length > 0 ? (
          visibleMessages.map((message) => (
            <MessageBubble key={message.id} message={message} />
          ))
        ) : (
          <EmptyState
            icon={<FaComments />}
            title="Belum Ada Percakapan"
            description="Balasan admin dan player akan tampil di sini."
          />
        )}
      </div>

      <div className="chat-input-wrap">
        <input
          className="chat-input"
          value={chatText}
          onChange={(event) => setChatText(event.target.value)}
          onKeyDown={(event) => {
            if (event.key === "Enter") {
              onSendMessage();
            }
          }}
          placeholder="Type reply..."
        />

        <button className="btn btn-primary send-btn" onClick={onSendMessage}>
          <FaPaperPlane />
        </button>
      </div>
    </section>
  );
}

function ReportTags({ report }: { report: Report }) {
  return (
    <div className="tag-row">
      <span className="badge lime">#{report.id}</span>

      <span className={statusClass(report.status)}>
        {statusLabel(report.status)}
      </span>

      <span className={priorityClass(report.priority)}>
        {report.priority === "high" && <FaExclamationTriangle />}
        {priorityLabel(report.priority)}
      </span>

      <span className="badge gray">{report.category}</span>
    </div>
  );
}

function ReportActions({
  onGotoReporter,
  onBringReporter,
  onAssist,
  onSolve,
  onCloseReport,
}: {
  onGotoReporter: () => void;
  onBringReporter: () => void;
  onAssist: () => void;
  onSolve: () => void;
  onCloseReport: () => void;
}) {
  return (
    <div className="detail-actions">
      <div className="action-group">
        <button
          className="btn btn-soft action-btn"
          onClick={onGotoReporter}
          title="Goto reporter"
        >
          <FaLocationArrow />
          <span>Goto</span>
        </button>

        <button
          className="btn btn-soft action-btn"
          onClick={onBringReporter}
          title="Bring reporter"
        >
          <FaPeopleArrows />
          <span>Bring</span>
        </button>
      </div>

      <div className="action-group action-group-right">
        <button
          className="btn btn-soft action-btn"
          onClick={onAssist}
          title="Assist report"
        >
          <FaComments />
          <span>Assist</span>
        </button>

        <button
          className="btn btn-primary action-btn"
          onClick={onSolve}
          title="Solve report"
        >
          <FaCheck />
          <span>Solve</span>
        </button>

        <button
          className="btn btn-danger icon-only-btn"
          onClick={onCloseReport}
          title="Close report"
        >
          <FaTimes />
        </button>
      </div>
    </div>
  );
}

function MessageBubble({ message }: { message: ReportMessage }) {
  return (
    <div className={`message-row ${message.role}`}>
      <div className="message-bubble">
        <div className="message-author">
          <MessageAuthorIcon role={message.role} />
          {getMessageAuthor(message)}
        </div>

        <p className="message-text">{message.message}</p>
        <div className="message-time">{message.createdAt}</div>
      </div>
    </div>
  );
}

function MessageAuthorIcon({ role }: { role: ReportMessageRole }) {
  if (role === "admin") return <FaUserShield />;
  if (role === "system") return <FaShieldAlt />;

  return <FaUser />;
}

function getMessageAuthor(message: ReportMessage) {
  if (message.role === "system") return "System";
  return message.author;
}

function PlayerReportView({
  form,
  setForm,
  activeReport,
  chatText,
  setChatText,
  onSubmit,
  onSendMessage,
  onClose,
}: {
  form: ReportForm;
  setForm: React.Dispatch<React.SetStateAction<ReportForm>>;
  activeReport?: Report;
  chatText: string;
  setChatText: (value: string) => void;
  onSubmit: () => void;
  onSendMessage: () => void;
  onClose: () => void;
}) {
  const chatRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    const el = chatRef.current;
    if (!el) return;

    el.scrollTop = el.scrollHeight;
  }, [activeReport?.id, activeReport?.messages.length]);

  const activeVisibleMessages = getVisibleMessages(activeReport);

  return (
    <section className={`player-report-shell ${activeReport ? "with-chat" : ""}`}>
      <div className="player-report-card">
        <header className="player-report-header">
          <div className="player-report-brand">
            <div className="brand-icon">
              <FaPaperPlane />
            </div>

            <div>
              <h1 className="player-report-title">
                {activeReport ? "Report Chat" : "Create Report"}
              </h1>
              <p className="player-report-subtitle">
                {activeReport
                  ? "Chat dengan admin yang sedang menangani laporan kamu."
                  : "Kirim laporan ke admin dengan detail yang jelas."}
              </p>
            </div>
          </div>

          <button className="icon-button" onClick={onClose}>
            <FaTimes />
          </button>
        </header>

        {activeReport ? (
          <div className="player-chat-layout">
            <section className="player-active-report">
              <ReportTags report={activeReport} />

              <h3 className="detail-title">{activeReport.title}</h3>
              <p className="detail-desc">{activeReport.description}</p>

              <div className="report-meta">
                <span>
                  <FaClock />
                  {activeReport.createdAt}
                </span>

                <span>
                  <FaUserShield />
                  {activeReport.assignedAdmin ?? "Menunggu admin"}
                </span>
              </div>
            </section>

            <section className="player-chat-card">
              <div className="card-header compact">
                <div>
                  <h3 className="card-title">Live Chat</h3>
                  <p className="card-desc">Balas admin langsung dari menu ini.</p>
                </div>

                <FaComments className="card-header-icon" />
              </div>

              <div ref={chatRef} className="chat-area player-chat-area scroll-area">
                {activeVisibleMessages.length > 0 ? (
                  activeVisibleMessages.map((message) => (
                    <MessageBubble key={message.id} message={message} />
                  ))
                ) : (
                  <EmptyState
                    icon={<FaComments />}
                    title="Belum Ada Chat"
                    description="Tunggu admin membalas report kamu."
                  />
                )}
              </div>

              <div className="chat-input-wrap">
                <input
                  className="chat-input"
                  value={chatText}
                  disabled={activeReport.status === "closed"}
                  onChange={(event) => setChatText(event.target.value)}
                  onKeyDown={(event) => {
                    if (event.key === "Enter") {
                      onSendMessage();
                    }
                  }}
                  placeholder={
                    activeReport.status === "closed"
                      ? "Report sudah ditutup."
                      : "Tulis pesan untuk admin..."
                  }
                />

                <button
                  className="btn btn-primary send-btn"
                  disabled={activeReport.status === "closed"}
                  onClick={onSendMessage}
                >
                  <FaPaperPlane />
                </button>
              </div>
            </section>
          </div>
        ) : (
          <div className="player-report-body">
            <div className="player-report-form">
              <div className="form-group">
                <label className="form-label">Title</label>

                <input
                  className="input"
                  value={form.title}
                  onChange={(event) =>
                    setForm((prev) => ({
                      ...prev,
                      title: event.target.value,
                    }))
                  }
                  placeholder="Contoh: Inventory tidak bisa dibuka"
                />
              </div>

              <div className="player-report-row">
                <div className="form-group">
                  <label className="form-label">Category</label>

                  <select
                    className="select"
                    value={form.category}
                    onChange={(event) =>
                      setForm((prev) => ({
                        ...prev,
                        category: event.target.value,
                      }))
                    }
                  >
                    <option value="Help">Help</option>
                    <option value="Bug">Bug</option>
                    <option value="Player Report">Player Report</option>
                    <option value="Donation">Donation</option>
                    <option value="Other">Other</option>
                  </select>
                </div>

                <div className="form-group">
                  <label className="form-label">Priority</label>

                  <select
                    className="select"
                    value={form.priority}
                    onChange={(event) =>
                      setForm((prev) => ({
                        ...prev,
                        priority: event.target.value as ReportPriority,
                      }))
                    }
                  >
                    <option value="low">Low</option>
                    <option value="medium">Medium</option>
                    <option value="high">High</option>
                  </select>
                </div>
              </div>

              <div className="form-group">
                <label className="form-label">Description</label>

                <textarea
                  className="textarea player-report-textarea"
                  value={form.description}
                  onChange={(event) =>
                    setForm((prev) => ({
                      ...prev,
                      description: event.target.value,
                    }))
                  }
                  placeholder="Jelaskan masalah kamu. Sertakan lokasi, ID player lain jika ada, dan kronologi singkat."
                />
              </div>

              <button className="btn btn-primary full-btn" onClick={onSubmit}>
                <FaPaperPlane />
                Submit Report
              </button>
            </div>

            <aside className="player-report-tips">
              <HelperCard
                icon={<FaComments />}
                title="Jelas"
                description="Pakai judul pendek dan tulis kronologi lengkap."
              />

              <HelperCard
                icon={<FaExclamationTriangle />}
                title="Prioritas"
                description="Gunakan High hanya untuk masalah urgent."
              />

              <HelperCard
                icon={<FaShieldAlt />}
                title="Admin"
                description="Setelah report terkirim, chat akan muncul di menu ini."
              />
            </aside>
          </div>
        )}
      </div>
    </section>
  );
}

function HelperCard({
  icon,
  title,
  description,
}: {
  icon: React.ReactNode;
  title: string;
  description: string;
}) {
  return (
    <div className="helper-card">
      <span className="helper-icon">{icon}</span>

      <div>
        <h4 className="helper-title">{title}</h4>
        <p className="helper-text">{description}</p>
      </div>
    </div>
  );
}

function Leaderboard({ leaderboard }: { leaderboard: LeaderboardItem[] }) {
  return (
    <section className="leaderboard-card">
      <div className="card-header compact">
        <div>
          <h3 className="card-title">Top Solver</h3>
          <p className="card-desc">Most solved reports</p>
        </div>

        <FaTrophy className="card-header-icon" />
      </div>

      <div className="leaderboard-list scroll-area">
        {leaderboard.map((item, index) => (
          <div className="leader-row" key={item.name}>
            <div className="leader-rank">
              {index === 0 ? <FaTrophy /> : index + 1}
            </div>

            <div className="leader-info">
              <p className="leader-name">{item.name}</p>
              <p className="leader-meta">{item.lastSolved ?? "-"}</p>
            </div>

            <span className="badge lime">
              <FaCheckCircle />
              {item.solved}
            </span>
          </div>
        ))}
      </div>
    </section>
  );
}

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
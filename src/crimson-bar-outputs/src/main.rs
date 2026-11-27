//! crimson-bar-outputs: pick which monitors show the Quickshell bar.
//!
//! The choice lives in ~/.config/crimson/bar-outputs, one output name per
//! line (it's this machine's own setting, not part of the dotfiles repo).
//! Quickshell's shell.qml reads it; nothing picked, or none of the picked
//! outputs plugged in, means a bar on every output. Each toggle is saved
//! straight away and the bar is told to reload (quickshell ipc call bar
//! reload), so changes show at once.
//!
//! The outputs are listed from Wayland itself (wl_output names, the same
//! ones Quickshell and wlr-randr use), and the list follows monitors being
//! plugged in and out while it's open.

use std::collections::BTreeSet;
use std::io;
use std::path::PathBuf;
use std::process::{Command, Stdio};
use std::time::Duration;

use ratatui::crossterm::event::{
    self, DisableMouseCapture, EnableMouseCapture, Event, KeyCode, KeyEventKind, KeyModifiers,
    MouseButton, MouseEventKind,
};
use ratatui::crossterm::execute;
use ratatui::layout::{Constraint, Layout, Margin, Rect};
use ratatui::style::{Color, Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, BorderType, Borders, Paragraph, Row, Table, TableState};
use ratatui::{DefaultTerminal, Frame};
use wayland_client::protocol::{wl_output, wl_registry};
use wayland_client::{Connection, Dispatch, EventQueue, Proxy, QueueHandle, WEnum};

// Crimson Dark, from alacritty's palette.
const FG: Color = Color::Rgb(0xe8, 0xd5, 0xd0);
const MUTED: Color = Color::Rgb(0x8c, 0x74, 0x70);
const LINE: Color = Color::Rgb(0x3a, 0x25, 0x28);
const CRIMSON: Color = Color::Rgb(0xe5, 0x48, 0x4d);
const SELECTED_BG: Color = Color::Rgb(0x3a, 0x22, 0x26);

// Nerd Font checkboxes (the font the rest of the desktop uses).
const CHECKED: &str = "󰄲";
const UNCHECKED: &str = "󰄱";

// ---------------------------------------------------------------- Wayland

#[derive(Default)]
struct Output {
    global: u32,
    proxy: Option<wl_output::WlOutput>,
    name: String,
    description: String,
    mode: Option<(i32, i32)>,
}

#[derive(Default)]
struct Outputs {
    list: Vec<Output>,
    /// Set whenever an output appears, goes or changes, so the UI redraws.
    changed: bool,
}

impl Dispatch<wl_registry::WlRegistry, ()> for Outputs {
    fn event(
        state: &mut Self,
        registry: &wl_registry::WlRegistry,
        event: wl_registry::Event,
        _: &(),
        _: &Connection,
        qh: &QueueHandle<Self>,
    ) {
        match event {
            wl_registry::Event::Global { name, interface, version } if interface == "wl_output" => {
                // Version 4 is the one with the output's name (HDMI-A-1...).
                let proxy = registry.bind::<wl_output::WlOutput, _, _>(name, version.min(4), qh, name);
                state.list.push(Output { global: name, proxy: Some(proxy), ..Default::default() });
                state.changed = true;
            }
            wl_registry::Event::GlobalRemove { name } => {
                if let Some(i) = state.list.iter().position(|o| o.global == name) {
                    if let Some(p) = state.list.remove(i).proxy {
                        if p.version() >= 3 {
                            p.release();
                        }
                    }
                    state.changed = true;
                }
            }
            _ => {}
        }
    }
}

impl Dispatch<wl_output::WlOutput, u32> for Outputs {
    fn event(
        state: &mut Self,
        _: &wl_output::WlOutput,
        event: wl_output::Event,
        global: &u32,
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
        let Some(o) = state.list.iter_mut().find(|o| o.global == *global) else { return };
        match event {
            wl_output::Event::Name { name } => o.name = name,
            wl_output::Event::Description { description } => o.description = description,
            wl_output::Event::Geometry { make, model, .. } if o.description.is_empty() => {
                o.description = format!("{make} {model}");
            }
            wl_output::Event::Mode { flags: WEnum::Value(f), width, height, .. }
                if f.contains(wl_output::Mode::Current) =>
            {
                o.mode = Some((width, height));
            }
            _ => {}
        }
        state.changed = true;
    }
}

struct Wayland {
    conn: Connection,
    queue: EventQueue<Outputs>,
    outputs: Outputs,
}

impl Wayland {
    fn connect() -> Result<Self, String> {
        let conn = Connection::connect_to_env()
            .map_err(|e| format!("can't reach the Wayland compositor ({e}); run this inside labwc"))?;
        let mut queue = conn.new_event_queue();
        conn.display().get_registry(&queue.handle(), ());
        let mut outputs = Outputs::default();
        // One roundtrip for the globals, one for each output's details.
        for _ in 0..2 {
            queue.roundtrip(&mut outputs).map_err(|e| format!("Wayland error: {e}"))?;
        }
        Ok(Wayland { conn, queue, outputs })
    }

    /// Takes in whatever the compositor has sent since last time, without
    /// waiting. Returns whether the list of outputs changed.
    fn poll(&mut self) -> bool {
        let _ = self.conn.flush();
        if let Some(guard) = self.queue.prepare_read() {
            // Nothing to read is fine; a dead connection shows as no outputs
            // changing, which is all we could do about it anyway.
            let _ = guard.read();
        }
        let _ = self.queue.dispatch_pending(&mut self.outputs);
        std::mem::take(&mut self.outputs.changed)
    }
}

// ---------------------------------------------------------------- Settings

fn config_path() -> PathBuf {
    let base = std::env::var_os("XDG_CONFIG_HOME")
        .filter(|v| !v.is_empty())
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from(std::env::var_os("HOME").unwrap_or_default()).join(".config"));
    base.join("crimson").join("bar-outputs")
}

fn load(path: &PathBuf) -> BTreeSet<String> {
    std::fs::read_to_string(path)
        .unwrap_or_default()
        .lines()
        .map(str::trim)
        .filter(|l| !l.is_empty() && !l.starts_with('#'))
        .map(String::from)
        .collect()
}

fn save(path: &PathBuf, picked: &BTreeSet<String>) -> io::Result<()> {
    if let Some(dir) = path.parent() {
        std::fs::create_dir_all(dir)?;
    }
    let mut text = String::from(
        "# Outputs that show the Quickshell bar, one per line. None, or none of\n\
         # them plugged in: a bar on every output. Edited by crimson-bar-outputs\n\
         # (System Controls, Super+o); read by ~/.config/quickshell/shell.qml.\n",
    );
    for name in picked {
        text.push_str(name);
        text.push('\n');
    }
    // Written in place rather than renamed over, so Quickshell's watch on
    // the file keeps working.
    std::fs::write(path, text)?;
    // Quickshell not running (or too old to know "bar") isn't an error here:
    // it reads the file when it next starts.
    let _ = Command::new("quickshell")
        .args(["ipc", "call", "bar", "reload"])
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status();
    Ok(())
}

// ---------------------------------------------------------------- App

struct Entry {
    name: String,
    description: String,
    mode: Option<(i32, i32)>,
    connected: bool,
}

struct App {
    wayland: Wayland,
    path: PathBuf,
    picked: BTreeSet<String>,
    table: TableState,
    /// Where the rows were last drawn, for mouse clicks.
    rows_area: Rect,
    message: Option<(String, bool)>,
}

impl App {
    /// Connected outputs in the compositor's order, then picked outputs that
    /// aren't plugged in now (so they can still be unticked).
    fn entries(&self) -> Vec<Entry> {
        let mut out: Vec<Entry> = self
            .wayland
            .outputs
            .list
            .iter()
            .filter(|o| !o.name.is_empty())
            .map(|o| Entry {
                name: o.name.clone(),
                // labwc's descriptions end in " (HDMI-A-1)"; the name has
                // its own column.
                description: o
                    .description
                    .strip_suffix(&format!(" ({})", o.name))
                    .unwrap_or(&o.description)
                    .to_string(),
                mode: o.mode,
                connected: true,
            })
            .collect();
        for name in &self.picked {
            if !out.iter().any(|e| &e.name == name) {
                out.push(Entry { name: name.clone(), description: String::new(), mode: None, connected: false });
            }
        }
        out
    }

    fn toggle(&mut self, index: usize) {
        let entries = self.entries();
        let Some(e) = entries.get(index) else { return };
        if !self.picked.remove(&e.name) {
            self.picked.insert(e.name.clone());
        }
        self.store();
    }

    fn pick_all(&mut self) {
        self.picked.clear();
        self.store();
    }

    fn store(&mut self) {
        self.message = Some(match save(&self.path, &self.picked) {
            Ok(()) => ("Saved.".into(), false),
            Err(e) => (format!("Couldn't save {}: {e}", self.path.display()), true),
        });
    }

    fn clamp_selection(&mut self) {
        let n = self.entries().len();
        match self.table.selected() {
            _ if n == 0 => self.table.select(None),
            None => self.table.select(Some(0)),
            Some(i) if i >= n => self.table.select(Some(n - 1)),
            _ => {}
        }
    }

    /// The outputs that will actually show the bar, as a sentence.
    fn summary(&self, entries: &[Entry]) -> Line<'static> {
        let live: Vec<&str> = entries
            .iter()
            .filter(|e| e.connected && self.picked.contains(&e.name))
            .map(|e| e.name.as_str())
            .collect();
        let (lead, what) = if self.picked.is_empty() {
            ("Bar on ", "every output".to_string())
        } else if live.is_empty() {
            ("None of the picked outputs is plugged in, so the bar is on ", "every output".to_string())
        } else {
            ("Bar on ", live.join(", "))
        };
        Line::from(vec![
            Span::styled(lead, Style::new().fg(MUTED)),
            Span::styled(what, Style::new().fg(FG).add_modifier(Modifier::BOLD)),
        ])
    }

    fn draw(&mut self, f: &mut Frame) {
        let entries = self.entries();
        let area = f.area().inner(Margin { horizontal: 2, vertical: 1 });
        let [title, intro, list, summary, status, help] = Layout::vertical([
            Constraint::Length(1),
            Constraint::Length(2),
            Constraint::Length(entries.len().max(1) as u16 + 2),
            Constraint::Length(2),
            Constraint::Fill(1),
            Constraint::Length(1),
        ])
        .areas(area);

        f.render_widget(
            Paragraph::new(Span::styled("󰍹  Bar outputs", Style::new().fg(CRIMSON).add_modifier(Modifier::BOLD))),
            title,
        );
        f.render_widget(
            Paragraph::new(Span::styled(
                "Tick the monitors that should show the bar. Tick none for all of them.",
                Style::new().fg(MUTED),
            )),
            intro,
        );

        let block = Block::new().borders(Borders::ALL).border_type(BorderType::Rounded).border_style(Style::new().fg(LINE));
        self.rows_area = block.inner(list);
        if entries.is_empty() {
            f.render_widget(
                Paragraph::new(Span::styled("No outputs reported by the compositor.", Style::new().fg(MUTED))).block(block),
                list,
            );
        } else {
            let rows = entries.iter().map(|e| {
                let on = self.picked.contains(&e.name);
                let tick = Span::styled(if on { CHECKED } else { UNCHECKED }, Style::new().fg(if on { CRIMSON } else { MUTED }));
                let name_style = if e.connected { Style::new().fg(FG).add_modifier(Modifier::BOLD) } else { Style::new().fg(MUTED) };
                let detail = if e.connected { e.description.clone() } else { "not plugged in".into() };
                let mode = e.mode.map(|(w, h)| format!("{w}×{h}")).unwrap_or_default();
                Row::new(vec![
                    Line::from(tick),
                    Line::from(Span::styled(e.name.clone(), name_style)),
                    Line::from(Span::styled(detail, Style::new().fg(if e.connected { FG } else { MUTED }))),
                    Line::from(Span::styled(mode, Style::new().fg(MUTED))),
                ])
            });
            let name_width = entries.iter().map(|e| e.name.chars().count()).max().unwrap_or(0) as u16;
            let table = Table::new(
                rows,
                [Constraint::Length(1), Constraint::Length(name_width.max(6)), Constraint::Fill(1), Constraint::Length(9)],
            )
            .column_spacing(2)
            .row_highlight_style(Style::new().bg(SELECTED_BG))
            .block(block);
            f.render_stateful_widget(table, list, &mut self.table);
        }

        f.render_widget(Paragraph::new(self.summary(&entries)), summary);
        if let Some((msg, err)) = &self.message {
            f.render_widget(Paragraph::new(Span::styled(msg.clone(), Style::new().fg(if *err { CRIMSON } else { MUTED }))), status);
        }

        let key = |k: &'static str| Span::styled(k, Style::new().fg(CRIMSON));
        let txt = |t: &'static str| Span::styled(t, Style::new().fg(MUTED));
        f.render_widget(
            Paragraph::new(Line::from(vec![
                key("↑↓"), txt(" move  ·  "),
                key("space"), txt(" tick  ·  "),
                key("a"), txt(" all outputs  ·  "),
                key("q"), txt(" quit"),
            ])),
            help,
        );
    }

    fn run(&mut self, terminal: &mut DefaultTerminal) -> io::Result<()> {
        self.clamp_selection();
        let mut dirty = true;
        loop {
            if self.wayland.poll() {
                self.clamp_selection();
                dirty = true;
            }
            if dirty {
                terminal.draw(|f| self.draw(f))?;
                dirty = false;
            }
            // Short enough that plugging a monitor in shows up promptly.
            if !event::poll(Duration::from_millis(250))? {
                continue;
            }
            dirty = true;
            match event::read()? {
                Event::Key(k) if k.kind != KeyEventKind::Release => match k.code {
                    KeyCode::Char('q') | KeyCode::Esc => return Ok(()),
                    KeyCode::Char('c') if k.modifiers.contains(KeyModifiers::CONTROL) => return Ok(()),
                    KeyCode::Up | KeyCode::Char('k') => self.table.select_previous(),
                    KeyCode::Down | KeyCode::Char('j') => self.table.select_next(),
                    KeyCode::Home | KeyCode::Char('g') => self.table.select_first(),
                    KeyCode::End | KeyCode::Char('G') => self.table.select_last(),
                    KeyCode::Char(' ') | KeyCode::Enter => {
                        if let Some(i) = self.table.selected() {
                            self.toggle(i);
                        }
                    }
                    KeyCode::Char('a') => self.pick_all(),
                    _ => dirty = false,
                },
                Event::Mouse(m) => match m.kind {
                    MouseEventKind::Down(MouseButton::Left) => {
                        let r = self.rows_area;
                        if m.column >= r.x && m.column < r.right() && m.row >= r.y && m.row < r.bottom() {
                            let i = (m.row - r.y) as usize + self.table.offset();
                            if i < self.entries().len() {
                                self.table.select(Some(i));
                                self.toggle(i);
                            }
                        }
                    }
                    MouseEventKind::ScrollUp => self.table.select_previous(),
                    MouseEventKind::ScrollDown => self.table.select_next(),
                    _ => dirty = false,
                },
                Event::Resize(..) => {}
                _ => dirty = false,
            }
            self.clamp_selection();
        }
    }
}

fn main() {
    if let Some(arg) = std::env::args().nth(1) {
        match arg.as_str() {
            // For scripts: the connected outputs, one per line.
            "--list" => {}
            "-h" | "--help" => {
                println!("crimson-bar-outputs: pick which monitors show the Quickshell bar.");
                println!("Saves to {}", config_path().display());
                println!("  --list   print the connected outputs and exit");
                return;
            }
            _ => {
                eprintln!("crimson-bar-outputs: unknown option {arg} (try --help)");
                std::process::exit(2);
            }
        }
    }
    let wayland = match Wayland::connect() {
        Ok(w) => w,
        Err(e) => {
            eprintln!("crimson-bar-outputs: {e}");
            std::process::exit(1);
        }
    };
    if std::env::args().nth(1).as_deref() == Some("--list") {
        for o in wayland.outputs.list.iter().filter(|o| !o.name.is_empty()) {
            println!("{}\t{}", o.name, o.description);
        }
        return;
    }

    let path = config_path();
    let mut app = App { picked: load(&path), path, wayland, table: TableState::default(), rows_area: Rect::default(), message: None };
    let mut terminal = ratatui::init();
    let _ = execute!(io::stdout(), EnableMouseCapture);
    let result = app.run(&mut terminal);
    let _ = execute!(io::stdout(), DisableMouseCapture);
    ratatui::restore();
    if let Err(e) = result {
        eprintln!("crimson-bar-outputs: {e}");
        std::process::exit(1);
    }
}

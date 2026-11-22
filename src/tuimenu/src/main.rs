// tuimenu, restyled in Crimson Dark.
//
// Same config as upstream (~/.config/tuimenu/list.json: an array of
// {"cmd", "desc", "args"?}) and the same behaviour: the chosen program
// replaces tuimenu (exec). Changes from upstream 0.0.2:
//   - Crimson Dark colours, aligned columns, a full-width selection bar
//   - drawn on the alternate screen, so quitting leaves the shell tidy
//   - j/k and Esc as well as the arrows and q; Quit is a key, not a row
//   - a failed exec is reported instead of leaving a half-raw terminal
//   - no stray "Failed to exec" line for entries that have args

use std::env;
use std::fs;
use std::io::{stdin, stdout, Stdout, Write};
use std::os::unix::process::CommandExt;
use std::path::Path;
use std::process::{exit, Command, ExitCode};

use serde_json::Value;
use termion::event::Key;
use termion::input::TermRead;
use termion::raw::{IntoRawMode, RawTerminal};

// Crimson Dark, from alacritty's palette. Change these to restyle.
const CRIMSON: (u8, u8, u8) = (0xe5, 0x48, 0x4d); // accent, selection marker
const TEXT: (u8, u8, u8) = (0xe8, 0xd5, 0xd0); // names
const TEXT_HI: (u8, u8, u8) = (0xf5, 0xe9, 0xe6); // selected name
const MUTED: (u8, u8, u8) = (0x8c, 0x74, 0x70); // descriptions, hints
const MUTED_HI: (u8, u8, u8) = (0xb0, 0x9a, 0x95); // selected description
const LINE: (u8, u8, u8) = (0x3a, 0x25, 0x28); // rule under the title
const SEL_BG: (u8, u8, u8) = (0x3a, 0x22, 0x26); // selection bar

const TITLE: &str = "Launch";
const HINTS: &str = "↑↓ move   enter open   q quit";

const RESET: &str = "\x1b[0m";
const BOLD: &str = "\x1b[1m";
const ALT_SCREEN_ON: &str = "\x1b[?1049h";
const ALT_SCREEN_OFF: &str = "\x1b[?1049l";

fn fg(c: (u8, u8, u8)) -> String {
    format!("\x1b[38;2;{};{};{}m", c.0, c.1, c.2)
}

fn bg(c: (u8, u8, u8)) -> String {
    format!("\x1b[48;2;{};{};{}m", c.0, c.1, c.2)
}

fn pad(s: &str, width: usize) -> String {
    let len = s.chars().count();
    format!("{}{}", s, " ".repeat(width.saturating_sub(len)))
}

struct Entry {
    cmd: String,
    desc: String,
    args: Vec<String>,
}

fn fail(msg: &str) -> ! {
    eprintln!("\x1b[31mError\x1b[0m {}", msg);
    exit(1);
}

fn read_config() -> Vec<Entry> {
    let home = env::var("HOME").unwrap_or_else(|e| {
        eprintln!("Environment variable $HOME not found or invalid: {}", e);
        exit(2);
    });
    let dir = format!("{}/.config/tuimenu", home);
    let file = format!("{}/list.json", dir);

    let text = match fs::read_to_string(&file) {
        Ok(t) => t,
        Err(_) => {
            // First run: create an empty list for the user to fill in.
            if !Path::new(&dir).exists() {
                if let Err(e) = fs::create_dir_all(&dir) {
                    fail(&format!("creating directory {}:\n{}", dir, e));
                }
            }
            if let Err(e) = fs::write(&file, "") {
                fail(&format!("creating file {}:\n{}", file, e));
            }
            fail(&format!(
                "{} is empty\n\n    Please visit https://github.com/achester88/tuimenu to find out more\n",
                file
            ));
        }
    };

    let json: Value = serde_json::from_str(&text)
        .unwrap_or_else(|e| fail(&format!("reading tuimenu config:\n    {}", e)));
    let list = json
        .as_array()
        .unwrap_or_else(|| fail(&format!("{} should be a JSON array of programs", file)));

    let entries: Vec<Entry> = list
        .iter()
        .enumerate()
        .map(|(i, p)| Entry {
            cmd: p["cmd"]
                .as_str()
                .unwrap_or_else(|| fail(&format!("entry {} in {} has no \"cmd\"", i + 1, file)))
                .to_string(),
            desc: p["desc"].as_str().unwrap_or("").to_string(),
            args: p["args"]
                .as_array()
                .map(|a| a.iter().filter_map(|v| v.as_str().map(String::from)).collect())
                .unwrap_or_default(),
        })
        .collect();

    if entries.is_empty() {
        fail(&format!("{} has no programs in it", file));
    }
    entries
}

fn draw(out: &mut RawTerminal<Stdout>, entries: &[Entry], selected: usize) {
    let name_w = entries.iter().map(|e| e.cmd.chars().count()).max().unwrap_or(0);
    let desc_w = entries.iter().map(|e| e.desc.chars().count()).max().unwrap_or(0);
    // Row text: name, a gap, description; plus room for the marker and edges.
    let text_w = name_w + if desc_w > 0 { 4 + desc_w } else { 0 };
    let width = (text_w + 5).max(HINTS.chars().count() + 2);

    let mut s = String::new();
    s.push_str(&termion::clear::All.to_string());

    s.push_str(&format!(
        "{}{}{}{}{}",
        termion::cursor::Goto(4, 2),
        fg(CRIMSON),
        BOLD,
        TITLE,
        RESET
    ));
    s.push_str(&format!(
        "{}{}{}{}",
        termion::cursor::Goto(2, 3),
        fg(LINE),
        "─".repeat(width + 2),
        RESET
    ));

    for (i, e) in entries.iter().enumerate() {
        let row = 5 + i as u16;
        let name = pad(&e.cmd, name_w);
        let desc = pad(&e.desc, width - 4 - name_w);
        s.push_str(&termion::cursor::Goto(2, row).to_string());
        if i == selected {
            s.push_str(&format!(
                "{bg}{c}▌ {hi}{b}{name}{r}{bg}    {mh}{desc}{r}",
                bg = bg(SEL_BG),
                c = fg(CRIMSON),
                hi = fg(TEXT_HI),
                b = BOLD,
                name = name,
                mh = fg(MUTED_HI),
                desc = desc,
                r = RESET,
            ));
        } else {
            s.push_str(&format!(
                "  {t}{name}    {m}{desc}{r}",
                t = fg(TEXT),
                name = name,
                m = fg(MUTED),
                desc = desc,
                r = RESET,
            ));
        }
    }

    s.push_str(&format!(
        "{}{}{}{}",
        termion::cursor::Goto(4, 6 + entries.len() as u16),
        fg(MUTED),
        HINTS,
        RESET
    ));

    let _ = write!(out, "{}", s);
    let _ = out.flush();
}

// Put the terminal back the way the shell expects it.
fn restore(out: &mut RawTerminal<Stdout>) {
    let _ = write!(out, "{}{}{}", RESET, ALT_SCREEN_OFF, termion::cursor::Show);
    let _ = out.flush();
    let _ = out.suspend_raw_mode();
}

fn main() -> ExitCode {
    if env::args().nth(1).as_deref() == Some("-v") {
        println!("tuimenu v{}", env!("CARGO_PKG_VERSION"));
        return ExitCode::SUCCESS;
    }

    let entries = read_config();
    let mut selected = 0usize;

    let mut out = stdout().into_raw_mode().unwrap_or_else(|e| {
        fail(&format!("tuimenu needs to run in a terminal: {}", e));
    });
    let _ = write!(out, "{}{}", ALT_SCREEN_ON, termion::cursor::Hide);
    draw(&mut out, &entries, selected);

    for key in stdin().keys() {
        match key {
            Ok(Key::Up) | Ok(Key::Char('k')) => {
                selected = selected.saturating_sub(1);
            }
            Ok(Key::Down) | Ok(Key::Char('j')) => {
                if selected + 1 < entries.len() {
                    selected += 1;
                }
            }
            Ok(Key::Home) | Ok(Key::Char('g')) => selected = 0,
            Ok(Key::End) | Ok(Key::Char('G')) => selected = entries.len() - 1,
            Ok(Key::Char('\n')) => {
                let e = &entries[selected];
                restore(&mut out);
                let err = Command::new(&e.cmd).args(&e.args).exec();
                // exec only returns if it failed.
                eprintln!("\x1b[31mError\x1b[0m couldn't run {}: {}", e.cmd, err);
                return ExitCode::FAILURE;
            }
            Ok(Key::Char('q')) | Ok(Key::Esc) | Ok(Key::Ctrl('c')) => break,
            Ok(_) => continue,
            Err(_) => break,
        }
        draw(&mut out, &entries, selected);
    }

    restore(&mut out);
    ExitCode::SUCCESS
}

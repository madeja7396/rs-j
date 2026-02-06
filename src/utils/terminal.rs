fn get_env_value(env_name: &str) -> Option<String> {
    std::env::var(env_name)
        .ok()
        .filter(|value| !value.trim().is_empty())
}

#[inline]
fn has_prefix(value: &str, prefixes: &[&str]) -> bool {
    prefixes.iter().any(|prefix| value.starts_with(prefix))
}

fn is_wsl_with<F>(mut get_env: F) -> bool
where
    F: FnMut(&str) -> Option<String>,
{
    get_env("WSL_DISTRO_NAME").is_some() || get_env("WSL_INTEROP").is_some()
}

fn should_auto_enable_dot_marker_with<F>(is_windows: bool, mut get_env: F) -> bool
where
    F: FnMut(&str) -> Option<String>,
{
    if !is_windows {
        return false;
    }

    // Windows Terminal usually handles braille rendering better than the
    // built-in cmd/PowerShell host.
    if get_env("WT_SESSION").is_some() {
        return false;
    }

    let term_program = get_env("TERM_PROGRAM")
        .unwrap_or_default()
        .to_ascii_lowercase();
    if matches!(term_program.as_str(), "vscode" | "wezterm") {
        return false;
    }

    let term = get_env("TERM").unwrap_or_default().to_ascii_lowercase();
    if has_prefix(
        &term,
        &["xterm", "screen", "tmux", "rxvt", "cygwin", "msys", "st-"],
    ) {
        return false;
    }

    let has_powershell_env = get_env("PSModulePath").is_some();
    let has_cmd_env = get_env("PROMPT").is_some()
        || get_env("COMSPEC")
            .map(|comspec| comspec.to_ascii_lowercase().contains("cmd.exe"))
            .unwrap_or(false);

    has_powershell_env || has_cmd_env
}

pub(crate) fn is_wsl() -> bool {
    is_wsl_with(get_env_value)
}

pub(crate) fn should_auto_enable_dot_marker() -> bool {
    should_auto_enable_dot_marker_with(cfg!(windows), get_env_value)
}

#[cfg(test)]
mod tests {
    use super::{is_wsl_with, should_auto_enable_dot_marker_with};
    use std::collections::HashMap;

    #[test]
    fn detects_wsl_from_known_env_vars() {
        let mut env = HashMap::new();
        env.insert("WSL_DISTRO_NAME", "Ubuntu");
        assert!(is_wsl_with(|key| env.get(key).map(ToString::to_string)));

        let mut env = HashMap::new();
        env.insert("WSL_INTEROP", "/run/WSL/123");
        assert!(is_wsl_with(|key| env.get(key).map(ToString::to_string)));
    }

    #[test]
    fn does_not_detect_wsl_without_wsl_vars() {
        let env = HashMap::<&str, &str>::new();
        assert!(!is_wsl_with(|key| env.get(key).map(ToString::to_string)));
    }

    #[test]
    fn enables_dot_marker_for_windows_cmd() {
        let mut env = HashMap::new();
        env.insert("COMSPEC", r"C:\Windows\System32\cmd.exe");
        assert!(should_auto_enable_dot_marker_with(true, |key| {
            env.get(key).map(ToString::to_string)
        }));
    }

    #[test]
    fn enables_dot_marker_for_windows_powershell() {
        let mut env = HashMap::new();
        env.insert(
            "PSModulePath",
            r"C:\Users\User\Documents\WindowsPowerShell\Modules",
        );
        assert!(should_auto_enable_dot_marker_with(true, |key| {
            env.get(key).map(ToString::to_string)
        }));
    }

    #[test]
    fn does_not_auto_enable_on_windows_terminal() {
        let mut env = HashMap::new();
        env.insert("WT_SESSION", "1");
        env.insert("COMSPEC", r"C:\Windows\System32\cmd.exe");
        assert!(!should_auto_enable_dot_marker_with(true, |key| {
            env.get(key).map(ToString::to_string)
        }));
    }

    #[test]
    fn does_not_auto_enable_for_xterm_like_terminals() {
        let mut env = HashMap::new();
        env.insert("TERM", "xterm-256color");
        env.insert("COMSPEC", r"C:\Windows\System32\cmd.exe");
        assert!(!should_auto_enable_dot_marker_with(true, |key| {
            env.get(key).map(ToString::to_string)
        }));
    }

    #[test]
    fn does_not_auto_enable_on_non_windows() {
        let mut env = HashMap::new();
        env.insert("COMSPEC", r"C:\Windows\System32\cmd.exe");
        assert!(!should_auto_enable_dot_marker_with(false, |key| {
            env.get(key).map(ToString::to_string)
        }));
    }
}

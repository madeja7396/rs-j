use std::sync::atomic::{AtomicU8, Ordering};

#[derive(Debug, Clone, Copy, Eq, PartialEq, Default)]
#[repr(u8)]
pub enum UiLanguage {
    English = 0,
    #[default]
    Japanese = 1,
}

impl UiLanguage {
    pub fn as_str(self) -> &'static str {
        match self {
            UiLanguage::English => "en",
            UiLanguage::Japanese => "ja",
        }
    }

    fn from_raw(raw: u8) -> Self {
        match raw {
            0 => UiLanguage::English,
            _ => UiLanguage::Japanese,
        }
    }
}

impl std::str::FromStr for UiLanguage {
    type Err = ();

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.trim().to_ascii_lowercase().as_str() {
            "en" | "english" => Ok(UiLanguage::English),
            "ja" | "jp" | "japanese" => Ok(UiLanguage::Japanese),
            _ => Err(()),
        }
    }
}

static UI_LANGUAGE: AtomicU8 = AtomicU8::new(UiLanguage::Japanese as u8);

pub fn set_ui_language(language: UiLanguage) {
    UI_LANGUAGE.store(language as u8, Ordering::Relaxed);
}

pub fn ui_language() -> UiLanguage {
    UiLanguage::from_raw(UI_LANGUAGE.load(Ordering::Relaxed))
}

#[inline]
pub fn is_japanese() -> bool {
    matches!(ui_language(), UiLanguage::Japanese)
}

#[inline]
pub fn help_title() -> &'static str {
    if is_japanese() {
        " ヘルプ "
    } else {
        " Help "
    }
}

#[inline]
pub fn esc_to_close() -> &'static str {
    if is_japanese() {
        " Escで閉じる "
    } else {
        " Esc to close "
    }
}

#[inline]
pub fn esc_to_go_back() -> &'static str {
    if is_japanese() {
        " Escで戻る "
    } else {
        " Esc to go back "
    }
}

#[inline]
pub fn no_data() -> &'static str {
    if is_japanese() {
        "データなし"
    } else {
        "No data"
    }
}

#[inline]
pub fn status_frozen() -> &'static str {
    if is_japanese() {
        "更新停止中。'f' で再開"
    } else {
        "Frozen, press 'f' to unfreeze"
    }
}

#[inline]
pub fn environment_label() -> &'static str {
    if is_japanese() { "環境" } else { "Env" }
}

#[inline]
pub fn environment_label_verbose() -> &'static str {
    if is_japanese() {
        "環境情報"
    } else {
        "Environment"
    }
}

#[inline]
pub fn title_cpu() -> &'static str {
    " CPU "
}

#[inline]
pub fn title_memory() -> &'static str {
    if is_japanese() {
        " メモリ "
    } else {
        " Memory "
    }
}

#[inline]
pub fn title_network() -> &'static str {
    if is_japanese() {
        " ネットワーク "
    } else {
        " Network "
    }
}

#[inline]
pub fn title_disks() -> &'static str {
    if is_japanese() {
        " ディスク "
    } else {
        " Disks "
    }
}

#[inline]
pub fn title_temperatures() -> &'static str {
    if is_japanese() {
        " 温度センサー "
    } else {
        " Temperatures "
    }
}

#[cfg(feature = "battery")]
#[inline]
pub fn title_battery() -> &'static str {
    if is_japanese() {
        " バッテリー "
    } else {
        " Battery "
    }
}

#[inline]
pub fn sort_by_label() -> &'static str {
    if is_japanese() {
        "並び替え"
    } else {
        "Sort By"
    }
}

#[inline]
pub fn yes_label() -> &'static str {
    if is_japanese() { "はい" } else { "Yes" }
}

#[inline]
pub fn no_label() -> &'static str {
    if is_japanese() { "いいえ" } else { "No" }
}

#[inline]
pub fn error_title() -> &'static str {
    if is_japanese() {
        " エラー "
    } else {
        " Error "
    }
}

#[inline]
pub fn select_signal_title() -> &'static str {
    if is_japanese() {
        " シグナル選択 "
    } else {
        " Select Signal "
    }
}

#[inline]
pub fn confirm_kill_title() -> &'static str {
    if is_japanese() {
        " プロセス終了の確認 "
    } else {
        " Confirm Kill Process "
    }
}

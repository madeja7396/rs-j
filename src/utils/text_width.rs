use std::str::FromStr;

use unicode_ellipsis::grapheme_width;
use unicode_segmentation::UnicodeSegmentation;
use unicode_width::UnicodeWidthStr;

#[derive(Debug, Clone, Copy, Eq, PartialEq, Default)]
pub enum TextWidthMode {
    #[default]
    Normal,
    Cjk,
    UnicodeApprox,
}

impl TextWidthMode {
    pub const fn as_str(&self) -> &'static str {
        match self {
            TextWidthMode::Normal => "normal",
            TextWidthMode::Cjk => "cjk",
            TextWidthMode::UnicodeApprox => "unicode-approx",
        }
    }
}

impl FromStr for TextWidthMode {
    type Err = ();

    fn from_str(value: &str) -> Result<Self, Self::Err> {
        match value.to_ascii_lowercase().trim() {
            "normal" => Ok(Self::Normal),
            "cjk" => Ok(Self::Cjk),
            "unicode-approx" | "unicode_approx" => Ok(Self::UnicodeApprox),
            _ => Err(()),
        }
    }
}

#[inline]
pub fn grapheme_display_width(grapheme: &str, mode: TextWidthMode) -> usize {
    match mode {
        TextWidthMode::Normal => grapheme_width(grapheme),
        TextWidthMode::Cjk => UnicodeWidthStr::width_cjk(grapheme),
        TextWidthMode::UnicodeApprox => UnicodeWidthStr::width(grapheme).max(1),
    }
}

#[inline]
pub fn display_width(content: &str, mode: TextWidthMode) -> usize {
    UnicodeSegmentation::graphemes(content, true)
        .map(|grapheme| grapheme_display_width(grapheme, mode))
        .sum()
}

pub fn truncate_to_width(content: &str, width: usize, mode: TextWidthMode) -> String {
    if mode == TextWidthMode::Normal {
        return unicode_ellipsis::truncate_str(content, width).to_string();
    }

    if width == 0 {
        return String::new();
    }

    if display_width(content, mode) <= width {
        return content.to_string();
    }

    let ellipsis = "…";
    let ellipsis_width = display_width(ellipsis, mode).max(1);

    if width <= ellipsis_width {
        return ellipsis.to_string();
    }

    let max_content_width = width - ellipsis_width;
    let mut used_width = 0;
    let mut last_end = 0;

    for (byte_index, grapheme) in UnicodeSegmentation::grapheme_indices(content, true) {
        let grapheme_width = grapheme_display_width(grapheme, mode);
        if used_width + grapheme_width > max_content_width {
            break;
        }

        used_width += grapheme_width;
        last_end = byte_index + grapheme.len();
    }

    let mut truncated = String::from(&content[..last_end]);
    truncated.push('…');
    truncated
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_text_width_mode_variants() {
        assert_eq!("normal".parse::<TextWidthMode>(), Ok(TextWidthMode::Normal));
        assert_eq!("cjk".parse::<TextWidthMode>(), Ok(TextWidthMode::Cjk));
        assert_eq!(
            "unicode-approx".parse::<TextWidthMode>(),
            Ok(TextWidthMode::UnicodeApprox)
        );
        assert!("invalid".parse::<TextWidthMode>().is_err());
    }

    #[test]
    fn cjk_mode_widens_ambiguous_characters() {
        let ambiguous = "·";
        assert_eq!(display_width(ambiguous, TextWidthMode::Normal), 1);
        assert_eq!(display_width(ambiguous, TextWidthMode::Cjk), 2);
    }

    #[test]
    fn truncate_to_width_respects_ellipsis() {
        let result = truncate_to_width("abcdef", 4, TextWidthMode::UnicodeApprox);
        assert_eq!(result, "abc…");
    }
}

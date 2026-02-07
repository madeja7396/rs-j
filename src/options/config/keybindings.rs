use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Default, Deserialize, Serialize)]
#[cfg_attr(feature = "generate_schema", derive(schemars::JsonSchema))]
#[cfg_attr(test, serde(deny_unknown_fields), derive(PartialEq, Eq))]
pub(crate) struct KeyBindingsConfig {
    pub(crate) quit: Option<String>,
    pub(crate) help: Option<String>,
    pub(crate) toggle_percentages: Option<String>,
    pub(crate) show_percentages: Option<String>,
    pub(crate) show_values: Option<String>,
}

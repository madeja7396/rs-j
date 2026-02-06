//! Code related to attributes, which should be "searchable" leaf nodes.

use regex::Regex;
use unicode_normalization::UnicodeNormalization;

use crate::{
    collection::processes::ProcessHarvest,
    widgets::query::{
        NumericalQuery, PrefixType, QueryOptions, TimeQuery,
        error::{QueryError, QueryResult},
        new_regex,
    },
};

#[derive(Debug)]
pub(super) enum StringMatcher {
    Regex(Regex),
    Literal {
        normalized: String,
        whole_word: bool,
        ignore_case: bool,
    },
}

impl StringMatcher {
    fn normalize(value: &str, ignore_case: bool) -> String {
        let normalized = value.nfkc().collect::<String>();
        if ignore_case {
            normalized.to_lowercase()
        } else {
            normalized
        }
    }

    fn from_query(base: &str, regex_options: &QueryOptions) -> QueryResult<Self> {
        if regex_options.use_regex {
            Ok(Self::Regex(new_regex(base, regex_options)?))
        } else {
            Ok(Self::Literal {
                normalized: Self::normalize(base, regex_options.ignore_case),
                whole_word: regex_options.whole_word,
                ignore_case: regex_options.ignore_case,
            })
        }
    }

    fn is_match(&self, value: &str) -> bool {
        match self {
            StringMatcher::Regex(re) => re.is_match(value),
            StringMatcher::Literal {
                normalized,
                whole_word,
                ignore_case,
            } => {
                let normalized_value = Self::normalize(value, *ignore_case);
                if *whole_word {
                    normalized_value == *normalized
                } else {
                    normalized_value.contains(normalized)
                }
            }
        }
    }
}

/// An attribute (leaf node) for a process.
#[derive(Debug)]
pub(super) enum ProcessAttribute {
    /// This is a bit of a hack to allow for "empty" attributes. We can fix it properly,
    /// but it would potentially require handling "empty" queries better. Currently, we just
    /// treat it as a leaf node that always succeeds on matches.
    Empty,
    Pid(StringMatcher),
    CpuPercentage(NumericalQuery),
    MemBytes(NumericalQuery),
    MemPercentage(NumericalQuery),
    ReadPerSecond(NumericalQuery),
    WritePerSecond(NumericalQuery),
    TotalRead(NumericalQuery),
    TotalWrite(NumericalQuery),
    /// Note this is an "untagged" attribute (e.g. "btm", "firefox").
    Name(StringMatcher),
    State(StringMatcher),
    User(StringMatcher),
    Time(TimeQuery),
    #[cfg(unix)]
    Nice(NumericalQuery),
    Priority(NumericalQuery),
    #[cfg(feature = "gpu")]
    GpuPercentage(NumericalQuery),
    #[cfg(feature = "gpu")]
    GpuMemoryPercentage(NumericalQuery),
    #[cfg(feature = "gpu")]
    GpuMemoryBytes(NumericalQuery),
}

impl ProcessAttribute {
    pub(super) fn check(&self, process: &ProcessHarvest, is_using_command: bool) -> bool {
        match self {
            ProcessAttribute::Empty => true,
            ProcessAttribute::Pid(matcher) => matcher.is_match(process.pid.to_string().as_str()),
            ProcessAttribute::CpuPercentage(cmp) => cmp.check(process.cpu_usage_percent),
            ProcessAttribute::MemBytes(cmp) => cmp.check(process.mem_usage as f64),
            ProcessAttribute::MemPercentage(cmp) => cmp.check(process.mem_usage_percent),
            ProcessAttribute::ReadPerSecond(cmp) => cmp.check(process.read_per_sec as f64),
            ProcessAttribute::WritePerSecond(cmp) => cmp.check(process.write_per_sec as f64),
            ProcessAttribute::TotalRead(cmp) => cmp.check(process.total_read as f64),
            ProcessAttribute::TotalWrite(cmp) => cmp.check(process.total_write as f64),
            ProcessAttribute::Name(matcher) => matcher.is_match(if is_using_command {
                process.command.as_str()
            } else {
                process.name.as_str()
            }),
            ProcessAttribute::State(matcher) => matcher.is_match(process.process_state.0),
            ProcessAttribute::User(matcher) => match process.user.as_ref() {
                Some(user) => matcher.is_match(user),
                None => matcher.is_match("N/A"),
            },
            ProcessAttribute::Time(time) => time.check(process.time),
            // TODO: It's a bit silly for some of these, like nice/priority, where it's casted to an f64.
            #[cfg(unix)]
            ProcessAttribute::Nice(cmp) => cmp.check(process.nice as f64),
            ProcessAttribute::Priority(cmp) => cmp.check(process.priority as f64),
            #[cfg(feature = "gpu")]
            ProcessAttribute::GpuPercentage(cmp) => cmp.check(process.gpu_util as f64),
            #[cfg(feature = "gpu")]
            ProcessAttribute::GpuMemoryPercentage(cmp) => cmp.check(process.gpu_mem_percent as f64),
            #[cfg(feature = "gpu")]
            ProcessAttribute::GpuMemoryBytes(cmp) => cmp.check(process.gpu_mem as f64),
        }
    }
}

/// Given a string prefix type, obtain the appropriate [`ProcessAttribute`].
pub(super) fn new_string_attribute(
    prefix_type: PrefixType, base: &str, regex_options: &QueryOptions,
) -> QueryResult<ProcessAttribute> {
    match prefix_type {
        PrefixType::Pid | PrefixType::Name | PrefixType::State | PrefixType::User => {
            let matcher = StringMatcher::from_query(base, regex_options)?;

            match prefix_type {
                PrefixType::Pid => Ok(ProcessAttribute::Pid(matcher)),
                PrefixType::Name => Ok(ProcessAttribute::Name(matcher)),
                PrefixType::State => Ok(ProcessAttribute::State(matcher)),
                PrefixType::User => Ok(ProcessAttribute::User(matcher)),
                _ => unreachable!(),
            }
        }
        _ => Err(QueryError::new(format!(
            "process attribute type {prefix_type:?} is not a supported string attribute"
        ))),
    }
}

/// Given a time prefix type, obtain the appropriate [`ProcessAttribute`].
pub(super) fn new_time_attribute(
    prefix_type: PrefixType, query: TimeQuery,
) -> QueryResult<ProcessAttribute> {
    match prefix_type {
        PrefixType::Time => Ok(ProcessAttribute::Time(query)),
        _ => Err(QueryError::new(format!(
            "process attribute type {prefix_type:?} is not a supported time attribute"
        ))),
    }
}

/// Given a numerical prefix type, obtain the appropriate [`ProcessAttribute`].
pub(super) fn new_numerical_attribute(
    prefix_type: PrefixType, query: NumericalQuery,
) -> QueryResult<ProcessAttribute> {
    match prefix_type {
        PrefixType::CpuPercentage => Ok(ProcessAttribute::CpuPercentage(query)),
        PrefixType::MemBytes => Ok(ProcessAttribute::MemBytes(query)),
        PrefixType::MemPercentage => Ok(ProcessAttribute::MemPercentage(query)),
        PrefixType::ReadPerSecond => Ok(ProcessAttribute::ReadPerSecond(query)),
        PrefixType::WritePerSecond => Ok(ProcessAttribute::WritePerSecond(query)),
        PrefixType::TotalRead => Ok(ProcessAttribute::TotalRead(query)),
        PrefixType::TotalWrite => Ok(ProcessAttribute::TotalWrite(query)),
        #[cfg(unix)]
        PrefixType::Nice => Ok(ProcessAttribute::Nice(query)),
        PrefixType::Priority => Ok(ProcessAttribute::Priority(query)),
        #[cfg(feature = "gpu")]
        PrefixType::GpuPercentage => Ok(ProcessAttribute::GpuPercentage(query)),
        #[cfg(feature = "gpu")]
        PrefixType::GpuMemoryBytes => Ok(ProcessAttribute::GpuMemoryBytes(query)),
        #[cfg(feature = "gpu")]
        PrefixType::GpuMemoryPercentage => Ok(ProcessAttribute::GpuMemoryPercentage(query)),
        _ => Err(QueryError::new(format!(
            "process attribute type {prefix_type:?} is not a supported numerical attribute"
        ))),
    }
}

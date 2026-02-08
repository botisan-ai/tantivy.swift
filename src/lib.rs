use serde::{Deserialize, Serialize};
use std::ops::Bound;
use std::path::Path;
use std::sync::Mutex;

use tantivy::IndexReader;
use tantivy::IndexWriter;
use tantivy::TantivyDocument;
use tantivy::Term;
use tantivy::collector::Count;
use tantivy::collector::TopDocs;
use tantivy::directory::MmapDirectory;
use tantivy::query::Occur;
use tantivy::query::{
    AllQuery, BooleanQuery, BoostQuery, ConstScoreQuery, DisjunctionMaxQuery, EmptyQuery,
    ExistsQuery, FuzzyTermQuery, PhrasePrefixQuery, PhraseQuery, QueryParser, RangeQuery,
    RegexQuery, TermQuery, TermSetQuery,
};

use tantivy::schema::{
    DateOptions as TantivyDateOptions, DateTimePrecision, Facet, FacetOptions, FieldType,
    IndexRecordOption, JsonObjectOptions, NumericOptions as TantivyNumericOptions, OwnedValue,
    Schema, TextFieldIndexing, TextOptions as TantivyTextOptions, Value,
};
use tantivy::tokenizer::AsciiFoldingFilter;
use tantivy::tokenizer::LowerCaser;
use tantivy::tokenizer::TextAnalyzer;
use tantivy::{Document, Index};

mod unicode_tokenizer;
use crate::unicode_tokenizer::UnicodeTokenizer;

#[derive(Debug, thiserror::Error, uniffi::Error)]
#[uniffi(flat_error)]
pub enum TantivyIndexError {
    #[error("IO error: {0}")]
    IoError(#[from] std::io::Error),
    #[error("Open directory error: {0}")]
    OpenDirectoryError(#[from] tantivy::directory::error::OpenDirectoryError),
    #[error("Tantivy error: {0}")]
    TantivyError(#[from] tantivy::TantivyError),
    #[error("Serialization error: {0}")]
    SerializationError(#[from] serde_json::Error),
    #[error("Document parsing error: {0}")]
    DocParsingError(#[from] tantivy::schema::document::DocParsingError),
    #[error("Facet parse error: {0}")]
    FacetParseError(#[from] tantivy::schema::FacetParseError),
    #[error("TryFromInt error: {0}")]
    TryFromIntError(#[from] std::num::TryFromIntError),
    #[error("Index writer acquisition error")]
    WriterAcquisitionError,
    #[error("Document not found for: {0}")]
    DocRetrievalError(String),
    #[error("Schema builder error: {0}")]
    SchemaBuilderError(String),
    #[error("Query error: {0}")]
    QueryError(String),
}

#[derive(Debug, Clone, Copy, uniffi::Enum)]
pub enum TantivyTokenizer {
    Raw,
    Default,
    Unicode,
    EnStem,
    Whitespace,
}

impl TantivyTokenizer {
    fn as_str(&self) -> &'static str {
        match self {
            TantivyTokenizer::Raw => "raw",
            TantivyTokenizer::Default => "default",
            TantivyTokenizer::Unicode => "unicode",
            TantivyTokenizer::EnStem => "en_stem",
            TantivyTokenizer::Whitespace => "whitespace",
        }
    }
}

#[derive(Debug, Clone, Copy, uniffi::Enum)]
pub enum TantivyIndexRecordOption {
    Basic,
    WithFreqs,
    WithFreqsAndPositions,
}

impl From<TantivyIndexRecordOption> for IndexRecordOption {
    fn from(opt: TantivyIndexRecordOption) -> Self {
        match opt {
            TantivyIndexRecordOption::Basic => IndexRecordOption::Basic,
            TantivyIndexRecordOption::WithFreqs => IndexRecordOption::WithFreqs,
            TantivyIndexRecordOption::WithFreqsAndPositions => {
                IndexRecordOption::WithFreqsAndPositions
            }
        }
    }
}

#[derive(Debug, Clone, Copy, uniffi::Enum)]
pub enum TantivyDatePrecision {
    Seconds,
    Milliseconds,
    Microseconds,
}

impl From<TantivyDatePrecision> for DateTimePrecision {
    fn from(precision: TantivyDatePrecision) -> Self {
        match precision {
            TantivyDatePrecision::Seconds => DateTimePrecision::Seconds,
            TantivyDatePrecision::Milliseconds => DateTimePrecision::Milliseconds,
            TantivyDatePrecision::Microseconds => DateTimePrecision::Microseconds,
        }
    }
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct TextFieldOptions {
    pub tokenizer: TantivyTokenizer,
    pub record: TantivyIndexRecordOption,
    pub stored: bool,
    pub fast: bool,
    pub fieldnorms: bool,
}

impl Default for TextFieldOptions {
    fn default() -> Self {
        Self {
            tokenizer: TantivyTokenizer::Unicode,
            record: TantivyIndexRecordOption::WithFreqsAndPositions,
            stored: true,
            fast: false,
            fieldnorms: true,
        }
    }
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct NumericFieldOptions {
    pub indexed: bool,
    pub stored: bool,
    pub fast: bool,
    pub fieldnorms: bool,
}

impl Default for NumericFieldOptions {
    fn default() -> Self {
        Self {
            indexed: true,
            stored: true,
            fast: false,
            fieldnorms: false,
        }
    }
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct DateFieldOptions {
    pub indexed: bool,
    pub stored: bool,
    pub fast: bool,
    pub fieldnorms: bool,
    pub precision: TantivyDatePrecision,
}

impl Default for DateFieldOptions {
    fn default() -> Self {
        Self {
            indexed: true,
            stored: true,
            fast: false,
            fieldnorms: true,
            precision: TantivyDatePrecision::Seconds,
        }
    }
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct FacetFieldOptions {
    pub stored: bool,
}

impl Default for FacetFieldOptions {
    fn default() -> Self {
        Self { stored: true }
    }
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct JsonFieldOptions {
    pub stored: bool,
    pub indexed: bool,
    pub fast: bool,
    pub tokenizer: TantivyTokenizer,
    pub record: TantivyIndexRecordOption,
    pub fieldnorms: bool,
    pub expand_dots: bool,
    pub fast_tokenizer: Option<TantivyTokenizer>,
}

impl Default for JsonFieldOptions {
    fn default() -> Self {
        Self {
            stored: true,
            indexed: false,
            fast: false,
            tokenizer: TantivyTokenizer::Unicode,
            record: TantivyIndexRecordOption::WithFreqsAndPositions,
            fieldnorms: true,
            expand_dots: false,
            fast_tokenizer: None,
        }
    }
}

#[derive(uniffi::Object)]
pub struct TantivySchemaBuilder {
    builder: Mutex<Option<tantivy::schema::SchemaBuilder>>,
}

#[uniffi::export]
impl TantivySchemaBuilder {
    #[uniffi::constructor]
    pub fn new() -> Self {
        Self {
            builder: Mutex::new(Some(Schema::builder())),
        }
    }

    #[uniffi::method]
    pub fn add_text_field(&self, name: String, options: TextFieldOptions) {
        let mut guard = self.builder.lock().unwrap();
        if let Some(builder) = guard.as_mut() {
            let mut text_options = TantivyTextOptions::default();

            let indexing = TextFieldIndexing::default()
                .set_tokenizer(options.tokenizer.as_str())
                .set_index_option(options.record.into())
                .set_fieldnorms(options.fieldnorms);

            text_options = text_options.set_indexing_options(indexing);

            if options.stored {
                text_options = text_options.set_stored();
            }
            if options.fast {
                text_options = text_options.set_fast(None);
            }

            builder.add_text_field(&name, text_options);
        }
    }

    #[uniffi::method]
    pub fn add_u64_field(&self, name: String, options: NumericFieldOptions) {
        let mut guard = self.builder.lock().unwrap();
        if let Some(builder) = guard.as_mut() {
            let mut opts = TantivyNumericOptions::default();

            if options.indexed {
                opts = opts.set_indexed();
            }
            if options.stored {
                opts = opts.set_stored();
            }
            if options.fast {
                opts = opts.set_fast();
            }
            if options.fieldnorms {
                opts = opts.set_fieldnorm();
            }

            builder.add_u64_field(&name, opts);
        }
    }

    #[uniffi::method]
    pub fn add_i64_field(&self, name: String, options: NumericFieldOptions) {
        let mut guard = self.builder.lock().unwrap();
        if let Some(builder) = guard.as_mut() {
            let mut opts = TantivyNumericOptions::default();

            if options.indexed {
                opts = opts.set_indexed();
            }
            if options.stored {
                opts = opts.set_stored();
            }
            if options.fast {
                opts = opts.set_fast();
            }
            if options.fieldnorms {
                opts = opts.set_fieldnorm();
            }

            builder.add_i64_field(&name, opts);
        }
    }

    #[uniffi::method]
    pub fn add_f64_field(&self, name: String, options: NumericFieldOptions) {
        let mut guard = self.builder.lock().unwrap();
        if let Some(builder) = guard.as_mut() {
            let mut opts = TantivyNumericOptions::default();

            if options.indexed {
                opts = opts.set_indexed();
            }
            if options.stored {
                opts = opts.set_stored();
            }
            if options.fast {
                opts = opts.set_fast();
            }
            if options.fieldnorms {
                opts = opts.set_fieldnorm();
            }

            builder.add_f64_field(&name, opts);
        }
    }

    #[uniffi::method]
    pub fn add_date_field(&self, name: String, options: DateFieldOptions) {
        let mut guard = self.builder.lock().unwrap();
        if let Some(builder) = guard.as_mut() {
            let mut opts = TantivyDateOptions::default();

            if options.indexed {
                opts = opts.set_indexed();
            }
            if options.stored {
                opts = opts.set_stored();
            }
            if options.fast {
                opts = opts.set_fast();
            }
            if options.fieldnorms {
                opts = opts.set_fieldnorm();
            }
            opts = opts.set_precision(options.precision.into());

            builder.add_date_field(&name, opts);
        }
    }

    #[uniffi::method]
    pub fn add_bool_field(&self, name: String, options: NumericFieldOptions) {
        let mut guard = self.builder.lock().unwrap();
        if let Some(builder) = guard.as_mut() {
            let mut opts = TantivyNumericOptions::default();

            if options.indexed {
                opts = opts.set_indexed();
            }
            if options.stored {
                opts = opts.set_stored();
            }
            if options.fast {
                opts = opts.set_fast();
            }
            if options.fieldnorms {
                opts = opts.set_fieldnorm();
            }

            builder.add_bool_field(&name, opts);
        }
    }

    #[uniffi::method]
    pub fn add_bytes_field(&self, name: String, stored: bool, fast: bool, indexed: bool) {
        let mut guard = self.builder.lock().unwrap();
        if let Some(builder) = guard.as_mut() {
            let mut opts = tantivy::schema::BytesOptions::default();

            if stored {
                opts = opts.set_stored();
            }
            if fast {
                opts = opts.set_fast();
            }
            if indexed {
                opts = opts.set_indexed();
            }

            builder.add_bytes_field(&name, opts);
        }
    }

    #[uniffi::method]
    pub fn add_facet_field(&self, name: String, options: FacetFieldOptions) {
        let mut guard = self.builder.lock().unwrap();
        if let Some(builder) = guard.as_mut() {
            let mut opts = FacetOptions::default();
            if options.stored {
                opts = opts.set_stored();
            }
            builder.add_facet_field(&name, opts);
        }
    }

    #[uniffi::method]
    pub fn add_json_field(&self, name: String, options: JsonFieldOptions) {
        let mut guard = self.builder.lock().unwrap();
        if let Some(builder) = guard.as_mut() {
            let mut opts = JsonObjectOptions::default();

            if options.stored {
                opts = opts.set_stored();
            }

            if options.indexed {
                let indexing = TextFieldIndexing::default()
                    .set_tokenizer(options.tokenizer.as_str())
                    .set_index_option(options.record.into())
                    .set_fieldnorms(options.fieldnorms);
                opts = opts.set_indexing_options(indexing);
            }

            if options.fast {
                let tokenizer = options.fast_tokenizer.map(|tokenizer| tokenizer.as_str());
                opts = opts.set_fast(tokenizer);
            }

            if options.expand_dots {
                opts = opts.set_expand_dots_enabled();
            }

            builder.add_json_field(&name, opts);
        }
    }
}

impl TantivySchemaBuilder {
    fn take_and_build(&self) -> Option<Schema> {
        let mut guard = self.builder.lock().unwrap();
        guard.take().map(|b| b.build())
    }
}

// ============================================================================
// Native Field Value Types (no JSON for indexing)
// ============================================================================

/// A field value passed from Swift - no JSON serialization needed
#[derive(Debug, Clone, Serialize, Deserialize, uniffi::Enum)]
#[serde(tag = "type", content = "value", rename_all = "snake_case")]
pub enum FieldValue {
    Text(String),
    U64(u64),
    I64(i64),
    F64(f64),
    Bool(bool),
    /// Unix timestamp in microseconds
    Date(i64),
    Bytes(Vec<u8>),
    Facet(String),
    Json(String),
}

/// A single document field
#[derive(Debug, Clone, Serialize, Deserialize, uniffi::Record)]
pub struct DocumentField {
    pub name: String,
    pub value: FieldValue,
}

/// A complete document (scalar fields only)
#[derive(Debug, Clone, uniffi::Record)]
pub struct TantivyDocumentFields {
    pub fields: Vec<DocumentField>,
}

#[derive(Debug, Clone, Serialize, Deserialize, uniffi::Record)]
pub struct TantivySearchQuery {
    pub query_str: String,
    pub default_fields: Vec<String>,
    pub fuzzy_fields: Vec<TantivyFuzzyField>,
    pub top_doc_limit: u32,
    pub top_doc_offset: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize, uniffi::Record)]
pub struct TantivyFuzzyField {
    pub field_name: String,
    pub prefix: bool,
    pub distance: u8,
    pub transpose_cost_one: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TantivyOccur {
    Must,
    Should,
    MustNot,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TantivyBooleanClause {
    pub occur: TantivyOccur,
    pub query: Box<TantivyQueryDsl>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum TantivyQueryDsl {
    All,
    Empty,
    Term {
        term: DocumentField,
    },
    TermSet {
        terms: Vec<DocumentField>,
    },
    Boolean {
        clauses: Vec<TantivyBooleanClause>,
    },
    Phrase {
        field: String,
        terms: Vec<String>,
        slop: Option<u32>,
    },
    PhrasePrefix {
        field: String,
        terms: Vec<String>,
        max_expansions: Option<u32>,
    },
    Range {
        field: String,
        lower: Option<FieldValue>,
        upper: Option<FieldValue>,
        include_lower: bool,
        include_upper: bool,
    },
    Regex {
        field: String,
        pattern: String,
    },
    Fuzzy {
        field: String,
        term: String,
        distance: u8,
        transpose_cost_one: bool,
    },
    Exists {
        field: String,
    },
    Boost {
        query: Box<TantivyQueryDsl>,
        boost: f32,
    },
    ConstScore {
        query: Box<TantivyQueryDsl>,
        score: f32,
    },
    DisjunctionMax {
        queries: Vec<TantivyQueryDsl>,
        tie_breaker: Option<f32>,
    },
    QueryString {
        query: String,
        default_fields: Vec<String>,
        fuzzy_fields: Vec<TantivyFuzzyField>,
    },
}

#[derive(uniffi::Object)]
pub struct TantivyIndex {
    index: Index,
    writer: Mutex<IndexWriter>,
    reader: IndexReader,
}

fn add_field_value(
    doc: &mut TantivyDocument,
    field: tantivy::schema::Field,
    value: &FieldValue,
) -> Result<(), TantivyIndexError> {
    match value {
        FieldValue::Text(s) => doc.add_text(field, s),
        FieldValue::U64(v) => doc.add_u64(field, *v),
        FieldValue::I64(v) => doc.add_i64(field, *v),
        FieldValue::F64(v) => doc.add_f64(field, *v),
        FieldValue::Bool(v) => doc.add_bool(field, *v),
        FieldValue::Date(ts) => {
            let dt = tantivy::DateTime::from_timestamp_micros(*ts);
            doc.add_date(field, dt);
        }
        FieldValue::Bytes(b) => doc.add_bytes(field, &b),
        FieldValue::Facet(path) => {
            let facet = Facet::from_text(path)?;
            doc.add_facet(field, facet);
        }
        FieldValue::Json(json) => {
            let json_value: serde_json::Value = serde_json::from_str(json)?;
            let owned_value: OwnedValue = json_value.into();
            doc.add_field_value(field, &owned_value);
        }
    }
    Ok(())
}

fn term_from_field_value(
    schema: &Schema,
    field: tantivy::schema::Field,
    value: &FieldValue,
) -> Result<Term, TantivyIndexError> {
    let field_type = schema.get_field_entry(field).field_type();
    match (field_type, value) {
        (FieldType::Str(_), FieldValue::Text(text)) => Ok(Term::from_field_text(field, text)),
        (FieldType::U64(_), FieldValue::U64(val)) => Ok(Term::from_field_u64(field, *val)),
        (FieldType::I64(_), FieldValue::I64(val)) => Ok(Term::from_field_i64(field, *val)),
        (FieldType::F64(_), FieldValue::F64(val)) => Ok(Term::from_field_f64(field, *val)),
        (FieldType::Bool(_), FieldValue::Bool(val)) => Ok(Term::from_field_bool(field, *val)),
        (FieldType::Date(_), FieldValue::Date(ts)) => {
            let dt = tantivy::DateTime::from_timestamp_micros(*ts);
            Ok(Term::from_field_date(field, dt))
        }
        (FieldType::Bytes(_), FieldValue::Bytes(bytes)) => Ok(Term::from_field_bytes(field, bytes)),
        (FieldType::Facet(_), FieldValue::Facet(path)) => {
            let facet = Facet::from_text(path)?;
            Ok(Term::from_facet(field, &facet))
        }
        (FieldType::JsonObject(_), FieldValue::Json(_)) => Err(TantivyIndexError::QueryError(
            "JSON term queries are not supported yet".to_string(),
        )),
        (_, _) => Err(TantivyIndexError::QueryError(format!(
            "Field value type does not match schema field {}",
            schema.get_field_name(field)
        ))),
    }
}

fn term_from_document_field(
    schema: &Schema,
    doc_field: &DocumentField,
) -> Result<Term, TantivyIndexError> {
    let field = schema.get_field(&doc_field.name)?;
    term_from_field_value(schema, field, &doc_field.value)
}

fn occur_from_dsl(occur: &TantivyOccur) -> Occur {
    match occur {
        TantivyOccur::Must => Occur::Must,
        TantivyOccur::Should => Occur::Should,
        TantivyOccur::MustNot => Occur::MustNot,
    }
}

fn document_field_from_value(
    schema: &Schema,
    field: tantivy::schema::Field,
    value: OwnedValue,
) -> Result<Option<FieldValue>, TantivyIndexError> {
    match schema.get_field_entry(field).field_type() {
        FieldType::Str(_) => match value {
            OwnedValue::Str(text) => Ok(Some(FieldValue::Text(text))),
            OwnedValue::PreTokStr(pre_tok) => Ok(Some(FieldValue::Text(pre_tok.text))),
            _ => Ok(None),
        },
        FieldType::U64(_) => match value {
            OwnedValue::U64(val) => Ok(Some(FieldValue::U64(val))),
            _ => Ok(None),
        },
        FieldType::I64(_) => match value {
            OwnedValue::I64(val) => Ok(Some(FieldValue::I64(val))),
            _ => Ok(None),
        },
        FieldType::F64(_) => match value {
            OwnedValue::F64(val) => Ok(Some(FieldValue::F64(val))),
            _ => Ok(None),
        },
        FieldType::Bool(_) => match value {
            OwnedValue::Bool(val) => Ok(Some(FieldValue::Bool(val))),
            _ => Ok(None),
        },
        FieldType::Date(_) => match value {
            OwnedValue::Date(val) => Ok(Some(FieldValue::Date(val.into_timestamp_micros()))),
            _ => Ok(None),
        },
        FieldType::Facet(_) => match value {
            OwnedValue::Facet(facet) => Ok(Some(FieldValue::Facet(facet.to_path_string()))),
            _ => Ok(None),
        },
        FieldType::Bytes(_) => match value {
            OwnedValue::Bytes(bytes) => Ok(Some(FieldValue::Bytes(bytes))),
            _ => Ok(None),
        },
        FieldType::JsonObject(_) => {
            let json = serde_json::to_string(&value)?;
            Ok(Some(FieldValue::Json(json)))
        }
        FieldType::IpAddr(_) => Ok(None),
    }
}

fn doc_to_fields(
    schema: &Schema,
    doc: TantivyDocument,
) -> Result<TantivyDocumentFields, TantivyIndexError> {
    let mut fields = Vec::new();

    for (field, value) in doc.iter_fields_and_values() {
        let owned: OwnedValue = OwnedValue::from(value.as_value());
        if let Some(field_value) = document_field_from_value(schema, field, owned)? {
            fields.push(DocumentField {
                name: schema.get_field_name(field).to_string(),
                value: field_value,
            });
        }
    }

    Ok(TantivyDocumentFields { fields })
}

fn build_query_parser(
    index: &Index,
    schema: &Schema,
    default_fields: &[String],
    fuzzy_fields: &[TantivyFuzzyField],
) -> Result<QueryParser, TantivyIndexError> {
    let default_fields = default_fields
        .iter()
        .filter_map(|field_name| schema.get_field(field_name).ok())
        .collect::<Vec<_>>();

    let mut query_parser = QueryParser::for_index(index, default_fields);

    for fuzzy_field in fuzzy_fields {
        let field = schema.get_field(&fuzzy_field.field_name)?;
        query_parser.set_field_fuzzy(
            field,
            fuzzy_field.prefix,
            fuzzy_field.distance,
            fuzzy_field.transpose_cost_one,
        );
    }

    Ok(query_parser)
}

impl TantivyQueryDsl {
    fn to_query(
        &self,
        index: &Index,
        schema: &Schema,
    ) -> Result<Box<dyn tantivy::query::Query>, TantivyIndexError> {
        match self {
            TantivyQueryDsl::All => Ok(Box::new(AllQuery)),
            TantivyQueryDsl::Empty => Ok(Box::new(EmptyQuery)),
            TantivyQueryDsl::Term { term } => {
                let term = term_from_document_field(schema, term)?;
                Ok(Box::new(TermQuery::new(term, IndexRecordOption::Basic)))
            }
            TantivyQueryDsl::TermSet { terms } => {
                if terms.is_empty() {
                    return Ok(Box::new(EmptyQuery));
                }
                let mut parsed_terms = Vec::with_capacity(terms.len());
                for term in terms {
                    parsed_terms.push(term_from_document_field(schema, term)?);
                }
                Ok(Box::new(TermSetQuery::new(parsed_terms)))
            }
            TantivyQueryDsl::Boolean { clauses } => {
                let mut boolean_clauses = Vec::with_capacity(clauses.len());
                for clause in clauses {
                    let occur = occur_from_dsl(&clause.occur);
                    let subquery = clause.query.to_query(index, schema)?;
                    boolean_clauses.push((occur, subquery));
                }
                Ok(Box::new(BooleanQuery::from(boolean_clauses)))
            }
            TantivyQueryDsl::Phrase { field, terms, slop } => {
                if terms.len() < 2 {
                    return Err(TantivyIndexError::QueryError(
                        "Phrase query requires at least two terms".to_string(),
                    ));
                }
                let field = schema.get_field(field)?;
                let term_list = terms
                    .iter()
                    .map(|term| Term::from_field_text(field, term))
                    .collect::<Vec<_>>();
                let mut query = PhraseQuery::new(term_list);
                if let Some(slop) = slop {
                    query.set_slop(*slop);
                }
                Ok(Box::new(query))
            }
            TantivyQueryDsl::PhrasePrefix {
                field,
                terms,
                max_expansions,
            } => {
                if terms.is_empty() {
                    return Err(TantivyIndexError::QueryError(
                        "Phrase prefix query requires at least one term".to_string(),
                    ));
                }
                let field = schema.get_field(field)?;
                let term_list = terms
                    .iter()
                    .map(|term| Term::from_field_text(field, term))
                    .collect::<Vec<_>>();
                let mut query = PhrasePrefixQuery::new(term_list);
                if let Some(max_expansions) = max_expansions {
                    query.set_max_expansions(*max_expansions);
                }
                Ok(Box::new(query))
            }
            TantivyQueryDsl::Range {
                field,
                lower,
                upper,
                include_lower,
                include_upper,
            } => {
                let field = schema.get_field(field)?;

                let lower_bound = match lower {
                    Some(value) => {
                        let term = term_from_field_value(schema, field, value)?;
                        if *include_lower {
                            Bound::Included(term)
                        } else {
                            Bound::Excluded(term)
                        }
                    }
                    None => Bound::Unbounded,
                };

                let upper_bound = match upper {
                    Some(value) => {
                        let term = term_from_field_value(schema, field, value)?;
                        if *include_upper {
                            Bound::Included(term)
                        } else {
                            Bound::Excluded(term)
                        }
                    }
                    None => Bound::Unbounded,
                };

                if matches!(lower_bound, Bound::Unbounded)
                    && matches!(upper_bound, Bound::Unbounded)
                {
                    return Err(TantivyIndexError::QueryError(
                        "Range query requires at least one bound".to_string(),
                    ));
                }

                Ok(Box::new(RangeQuery::new(lower_bound, upper_bound)))
            }
            TantivyQueryDsl::Regex { field, pattern } => {
                let field = schema.get_field(field)?;
                let query = RegexQuery::from_pattern(pattern, field)?;
                Ok(Box::new(query))
            }
            TantivyQueryDsl::Fuzzy {
                field,
                term,
                distance,
                transpose_cost_one,
            } => {
                let field = schema.get_field(field)?;
                let term = Term::from_field_text(field, term);
                Ok(Box::new(FuzzyTermQuery::new(
                    term,
                    *distance,
                    *transpose_cost_one,
                )))
            }
            TantivyQueryDsl::Exists { field } => {
                let _ = schema.get_field(field)?;
                Ok(Box::new(ExistsQuery::new(field.clone(), false)))
            }
            TantivyQueryDsl::Boost { query, boost } => {
                let query = query.to_query(index, schema)?;
                Ok(Box::new(BoostQuery::new(query, *boost)))
            }
            TantivyQueryDsl::ConstScore { query, score } => {
                let query = query.to_query(index, schema)?;
                Ok(Box::new(ConstScoreQuery::new(query, *score)))
            }
            TantivyQueryDsl::DisjunctionMax {
                queries,
                tie_breaker,
            } => {
                if queries.is_empty() {
                    return Ok(Box::new(EmptyQuery));
                }
                let mut parsed_queries = Vec::with_capacity(queries.len());
                for query in queries {
                    parsed_queries.push(query.to_query(index, schema)?);
                }
                Ok(Box::new(DisjunctionMaxQuery::with_tie_breaker(
                    parsed_queries,
                    tie_breaker.unwrap_or(0.0),
                )))
            }
            TantivyQueryDsl::QueryString {
                query,
                default_fields,
                fuzzy_fields,
            } => {
                let query_parser = build_query_parser(index, schema, default_fields, fuzzy_fields)?;
                let parsed_query = query_parser.parse_query_lenient(query).0;
                Ok(parsed_query)
            }
        }
    }
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct TantivySearchHit {
    pub doc_id: u64,
    pub score: f32,
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct TantivySearchResult {
    pub score: f32,
    pub doc: TantivyDocumentFields,
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct TantivySearchResults {
    pub count: u64,
    pub docs: Vec<TantivySearchResult>,
}

#[uniffi::export]
impl TantivyIndex {
    #[uniffi::constructor]
    pub fn new_with_schema(
        path: String,
        schema_builder: &TantivySchemaBuilder,
    ) -> Result<Self, TantivyIndexError> {
        let index_path = Path::new(&path);

        let directory = match MmapDirectory::open(index_path) {
            Ok(dir) => dir,
            Err(_) => match std::fs::create_dir_all(index_path) {
                Ok(_) => match MmapDirectory::open(index_path) {
                    Ok(dir) => dir,
                    Err(e) => return Err(TantivyIndexError::OpenDirectoryError(e)),
                },
                Err(e) => return Err(TantivyIndexError::IoError(e)),
            },
        };

        let schema = schema_builder.take_and_build().ok_or_else(|| {
            TantivyIndexError::SchemaBuilderError("Schema already built or empty".to_string())
        })?;

        let index = match Index::open_or_create(directory, schema) {
            Ok(idx) => idx,
            Err(e) => return Err(TantivyIndexError::TantivyError(e)),
        };

        let tokenizer = TextAnalyzer::builder(UnicodeTokenizer::default())
            .filter(LowerCaser)
            .filter(AsciiFoldingFilter)
            .build();

        index.tokenizers().register("unicode", tokenizer);

        let writer = index.writer(100_000_000)?;
        let reader = index.reader()?;

        Ok(TantivyIndex {
            index,
            writer: Mutex::new(writer),
            reader,
        })
    }

    #[uniffi::method]
    fn clear_index(&self) -> Result<(), TantivyIndexError> {
        let mut writer = match self.writer.lock() {
            Ok(wtr) => wtr,
            Err(_) => return Err(TantivyIndexError::WriterAcquisitionError),
        };

        writer.delete_all_documents()?;
        writer.commit()?;
        self.reader.reload()?;

        Ok(())
    }

    #[uniffi::method]
    fn index_doc(&self, doc: TantivyDocumentFields) -> Result<(), TantivyIndexError> {
        let schema = self.index.schema();

        let writer = match self.writer.lock() {
            Ok(wtr) => wtr,
            Err(_) => return Err(TantivyIndexError::WriterAcquisitionError),
        };

        let mut tantivy_doc = TantivyDocument::default();
        for field in doc.fields {
            if let Ok(field_handle) = schema.get_field(&field.name) {
                add_field_value(&mut tantivy_doc, field_handle, &field.value)?;
            }
        }

        writer.add_document(tantivy_doc)?;

        Ok(())
    }

    #[uniffi::method]
    fn index_docs(&self, docs: Vec<TantivyDocumentFields>) -> Result<(), TantivyIndexError> {
        let schema = self.index.schema();

        let writer = match self.writer.lock() {
            Ok(wtr) => wtr,
            Err(_) => return Err(TantivyIndexError::WriterAcquisitionError),
        };

        for doc in docs {
            let mut tantivy_doc = TantivyDocument::default();
            for field in doc.fields {
                if let Ok(field_handle) = schema.get_field(&field.name) {
                    add_field_value(&mut tantivy_doc, field_handle, &field.value)?;
                }
            }
            writer.add_document(tantivy_doc)?;
        }

        Ok(())
    }

    #[uniffi::method]
    fn commit(&self) -> Result<(), TantivyIndexError> {
        let mut writer = match self.writer.lock() {
            Ok(wtr) => wtr,
            Err(_) => return Err(TantivyIndexError::WriterAcquisitionError),
        };

        writer.commit()?;
        self.reader.reload()?;

        Ok(())
    }

    #[uniffi::method]
    fn delete_doc(&self, id: DocumentField) -> Result<(), TantivyIndexError> {
        let schema = self.index.schema();
        let term = term_from_document_field(&schema, &id)?;

        let mut writer = match self.writer.lock() {
            Ok(wtr) => wtr,
            Err(_) => return Err(TantivyIndexError::WriterAcquisitionError),
        };

        writer.delete_term(term);
        writer.commit()?;
        self.reader.reload()?;

        Ok(())
    }

    #[uniffi::method]
    fn doc_exists(&self, id: DocumentField) -> Result<bool, TantivyIndexError> {
        let schema = self.index.schema();
        let term = term_from_document_field(&schema, &id)?;

        let searcher = self.reader.searcher();
        let query = TermQuery::new(term, IndexRecordOption::Basic);
        let top_docs = searcher.search(&query, &TopDocs::with_limit(1))?;

        Ok(!top_docs.is_empty())
    }

    #[uniffi::method]
    fn get_doc(&self, id: DocumentField) -> Result<TantivyDocumentFields, TantivyIndexError> {
        let schema = self.index.schema();
        let term = term_from_document_field(&schema, &id)?;

        let searcher = self.reader.searcher();
        let query = TermQuery::new(term, IndexRecordOption::Basic);
        let top_docs = searcher.search(&query, &TopDocs::with_limit(1))?;

        if let Some((_, doc_address)) = top_docs.first() {
            let retrieved_doc: TantivyDocument = searcher.doc(*doc_address)?;
            doc_to_fields(&schema, retrieved_doc)
        } else {
            Err(TantivyIndexError::DocRetrievalError(format!("{}", id.name)))
        }
    }

    #[uniffi::method]
    fn get_docs_by_ids(
        &self,
        ids: Vec<DocumentField>,
    ) -> Result<Vec<TantivyDocumentFields>, TantivyIndexError> {
        if ids.is_empty() {
            return Ok(Vec::new());
        }

        let schema = self.index.schema();
        let mut terms = Vec::with_capacity(ids.len());
        for id in &ids {
            terms.push(term_from_document_field(&schema, id)?);
        }

        let searcher = self.reader.searcher();
        let query = TermSetQuery::new(terms);
        let top_docs = searcher.search(&query, &TopDocs::with_limit(ids.len()))?;

        let mut docs = Vec::with_capacity(top_docs.len());
        for (_, doc_address) in top_docs {
            let retrieved_doc: TantivyDocument = searcher.doc(doc_address)?;
            docs.push(doc_to_fields(&schema, retrieved_doc)?);
        }

        Ok(docs)
    }

    #[uniffi::method]
    fn docs_count(&self) -> u64 {
        let searcher = self.reader.searcher();
        searcher.num_docs()
    }

    #[uniffi::method]
    fn search_doc_ids(
        &self,
        query: TantivySearchQuery,
        id_field: String,
    ) -> Result<Vec<TantivySearchHit>, TantivyIndexError> {
        let schema = self.index.schema();
        let query_parser = build_query_parser(
            &self.index,
            &schema,
            &query.default_fields,
            &query.fuzzy_fields,
        )?;

        let parsed_query = query_parser.parse_query_lenient(&query.query_str).0;

        let limit: usize = query.top_doc_limit.try_into()?;
        let offset: usize = query.top_doc_offset.try_into()?;

        let searcher = self.reader.searcher();
        let top_docs = searcher.search(
            &parsed_query,
            &TopDocs::with_limit(limit).and_offset(offset),
        )?;

        let _ = schema.get_field(&id_field)?;
        let mut hits = Vec::with_capacity(top_docs.len());

        for (score, doc_address) in top_docs {
            let segment_reader = searcher.segment_reader(doc_address.segment_ord);
            let fast_field = segment_reader.fast_fields().u64(&id_field)?;
            if let Some(doc_id) = fast_field.first(doc_address.doc_id) {
                hits.push(TantivySearchHit { doc_id, score });
            }
        }

        Ok(hits)
    }

    #[uniffi::method]
    fn search_dsl(
        &self,
        query_json: String,
        top_doc_limit: u32,
        top_doc_offset: u32,
    ) -> Result<TantivySearchResults, TantivyIndexError> {
        let schema = self.index.schema();
        let query_dsl: TantivyQueryDsl = serde_json::from_str(&query_json)?;
        let query = query_dsl.to_query(&self.index, &schema)?;

        let limit: usize = top_doc_limit.try_into()?;
        let offset: usize = top_doc_offset.try_into()?;

        let searcher = self.reader.searcher();
        let (doc_count, top_docs) = searcher.search(
            &query,
            &(Count, TopDocs::with_limit(limit).and_offset(offset)),
        )?;

        let mut docs = Vec::with_capacity(top_docs.len());
        for (score, doc_address) in top_docs {
            let retrieved_doc: TantivyDocument = searcher.doc(doc_address)?;
            let doc_fields = doc_to_fields(&schema, retrieved_doc)?;
            docs.push(TantivySearchResult {
                score,
                doc: doc_fields,
            });
        }

        Ok(TantivySearchResults {
            count: doc_count as u64,
            docs,
        })
    }

    #[uniffi::method]
    fn search(&self, query: TantivySearchQuery) -> Result<TantivySearchResults, TantivyIndexError> {
        let schema = self.index.schema();
        let query_parser = build_query_parser(
            &self.index,
            &schema,
            &query.default_fields,
            &query.fuzzy_fields,
        )?;

        let parsed_query = query_parser.parse_query_lenient(&query.query_str).0;

        let limit: usize = query.top_doc_limit.try_into()?;
        let offset: usize = query.top_doc_offset.try_into()?;

        let searcher = self.reader.searcher();
        let (doc_count, top_docs) = searcher.search(
            &parsed_query,
            &(Count, TopDocs::with_limit(limit).and_offset(offset)),
        )?;

        let mut top_doc_items: Vec<TantivySearchResult> = Vec::new();

        for (score, doc_address) in top_docs {
            let retrieved_doc: TantivyDocument = searcher.doc(doc_address)?;
            let doc_fields = doc_to_fields(&schema, retrieved_doc)?;
            top_doc_items.push(TantivySearchResult {
                doc: doc_fields,
                score,
            });
        }

        Ok(TantivySearchResults {
            count: doc_count as u64,
            docs: top_doc_items,
        })
    }
}

uniffi::setup_scaffolding!();

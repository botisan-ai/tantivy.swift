use serde::{Deserialize, Serialize};
use std::path::Path;
use std::sync::Mutex;

use tantivy::IndexReader;
use tantivy::IndexWriter;
use tantivy::TantivyDocument;
use tantivy::Term;
use tantivy::collector::Count;
use tantivy::collector::TopDocs;
use tantivy::directory::MmapDirectory;
use tantivy::query::QueryParser;

use tantivy::schema::{
    DateOptions as TantivyDateOptions, DateTimePrecision, IndexRecordOption,
    NumericOptions as TantivyNumericOptions, Schema, TextFieldIndexing,
    TextOptions as TantivyTextOptions,
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
    #[error("TryFromInt error: {0}")]
    TryFromIntError(#[from] std::num::TryFromIntError),
    #[error("Index writer acquisition error")]
    WriterAcquisitionError,
    #[error("Document not found for: {0}")]
    DocRetrievalError(String),
    #[error("Schema builder error: {0}")]
    SchemaBuilderError(String),
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
}

impl TantivySchemaBuilder {
    fn take_and_build(&self) -> Option<Schema> {
        let mut guard = self.builder.lock().unwrap();
        guard.take().map(|b| b.build())
    }
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct TantivySearchQuery {
    pub query_str: String,
    pub default_fields: Vec<String>,
    pub fuzzy_fields: Vec<TantivyFuzzyField>,
    pub top_doc_limit: u32,
    pub top_doc_offset: u32,
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct TantivyFuzzyField {
    pub field_name: String,
    pub prefix: bool,
    pub distance: u8,
    pub transpose_cost_one: bool,
}

#[derive(uniffi::Object)]
pub struct TantivyIndex {
    index: Index,
    writer: Mutex<IndexWriter>,
    reader: IndexReader,
}

#[derive(Serialize, Deserialize)]
struct TantivySearchResults {
    count: u32,
    docs: Vec<TopDoc>,
}

#[derive(Serialize, Deserialize)]
struct TopDoc {
    doc: serde_json::Value,
    score: f32,
}

#[uniffi::export]
impl TantivyIndex {
    #[uniffi::constructor]
    pub fn new(path: String, schema_json_str: String) -> Result<Self, TantivyIndexError> {
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

        let schema: Schema = serde_json::from_str(&schema_json_str)?;

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

        let schema = schema_builder.take_and_build()
            .ok_or_else(|| TantivyIndexError::SchemaBuilderError("Schema already built or empty".to_string()))?;

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
    fn index_doc(&self, doc_json: String) -> Result<(), TantivyIndexError> {
        let schema = self.index.schema();
        let doc = TantivyDocument::parse_json(&schema, &doc_json)?;

        let mut writer = match self.writer.lock() {
            Ok(wtr) => wtr,
            Err(_) => return Err(TantivyIndexError::WriterAcquisitionError),
        };

        writer.add_document(doc)?;
        writer.commit()?;
        self.reader.reload()?;

        Ok(())
    }

    #[uniffi::method]
    fn index_docs(&self, docs_json: String) -> Result<(), TantivyIndexError> {
        let schema = self.index.schema();

        let mut writer = match self.writer.lock() {
            Ok(wtr) => wtr,
            Err(_) => return Err(TantivyIndexError::WriterAcquisitionError),
        };

        let items_json_values: Vec<serde_json::Map<String, serde_json::Value>> =
            serde_json::from_str(&docs_json)?;

        for item_json_value in items_json_values {
            let doc = TantivyDocument::from_json_object(&schema, item_json_value)?;
            writer.add_document(doc)?;
        }

        writer.commit()?;
        self.reader.reload()?;

        Ok(())
    }

    #[uniffi::method]
    fn delete_doc(&self, id_field: String, id_value: String) -> Result<(), TantivyIndexError> {
        let schema = self.index.schema();

        let field = schema.get_field(&id_field)?;
        let term = Term::from_field_text(field, &id_value);

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
    fn doc_exists(&self, id_field: String, id_value: String) -> Result<bool, TantivyIndexError> {
        let schema = self.index.schema();

        let field = schema.get_field(&id_field)?;
        let term = Term::from_field_text(field, &id_value);

        let searcher = self.reader.searcher();
        let query = tantivy::query::TermQuery::new(term, IndexRecordOption::Basic);
        let top_docs = searcher.search(&query, &TopDocs::with_limit(1))?;

        Ok(!top_docs.is_empty())
    }

    #[uniffi::method]
    fn get_doc(&self, id_field: String, id_value: String) -> Result<String, TantivyIndexError> {
        let schema = self.index.schema();

        let field = schema.get_field(&id_field)?;
        let term = Term::from_field_text(field, &id_value);

        let searcher = self.reader.searcher();
        let query = tantivy::query::TermQuery::new(term, IndexRecordOption::Basic);
        let top_docs = searcher.search(&query, &TopDocs::with_limit(1))?;

        if let Some((_, doc_address)) = top_docs.first() {
            let retrieved_doc: TantivyDocument = searcher.doc(*doc_address)?;
            let doc_json_str = retrieved_doc.to_json(&schema);
            Ok(doc_json_str)
        } else {
            Err(TantivyIndexError::DocRetrievalError(format!(
                "{} = {}",
                id_field, id_value
            )))
        }
    }

    #[uniffi::method]
    fn docs_count(&self) -> u64 {
        let searcher = self.reader.searcher();
        searcher.num_docs()
    }

    #[uniffi::method]
    fn search(&self, query: TantivySearchQuery) -> Result<String, TantivyIndexError> {
        let schema = self.index.schema();

        let query_str = query.query_str;

        let default_fields = query
            .default_fields
            .iter()
            .filter_map(|field_name| schema.get_field(field_name).ok())
            .collect::<Vec<_>>();

        let searcher = self.reader.searcher();

        let mut query_parser = QueryParser::for_index(&self.index, default_fields.clone());

        for fuzzy_field in query.fuzzy_fields {
            let field = schema.get_field(&fuzzy_field.field_name)?;
            query_parser.set_field_fuzzy(
                field,
                fuzzy_field.prefix,
                fuzzy_field.distance,
                fuzzy_field.transpose_cost_one,
            );
        }

        let parsed_query = query_parser.parse_query_lenient(&query_str).0;

        let limit: usize = query.top_doc_limit.try_into()?;
        let offset: usize = query.top_doc_offset.try_into()?;

        let (doc_count, top_docs) = searcher.search(
            &parsed_query,
            &(Count, TopDocs::with_limit(limit).and_offset(offset)),
        )?;

        let mut top_doc_items: Vec<TopDoc> = Vec::new();

        for (score, doc_address) in top_docs {
            let retrieved_doc: TantivyDocument = searcher.doc(doc_address)?;
            let doc_json_str = retrieved_doc.to_json(&schema);
            let doc_value: serde_json::Value = serde_json::from_str(&doc_json_str)?;
            top_doc_items.push(TopDoc {
                doc: doc_value,
                score,
            });
        }

        let results = TantivySearchResults {
            count: doc_count as u32,
            docs: top_doc_items,
        };

        let results_json = serde_json::to_string(&results)?;

        Ok(results_json)
    }
}

uniffi::setup_scaffolding!();

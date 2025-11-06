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
use tantivy::doc;
use tantivy::query::QueryParser;
use tantivy::query::TermQuery;
use tantivy::schema::IndexRecordOption;
use tantivy::schema::Schema;
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

        // create schema
        let schema: Schema = serde_json::from_str(&schema_json_str)?;

        // this bit is commented out because it is being deserialized from JSON now
        // keeping this as notes

        let index = match Index::open_or_create(directory, schema) {
            Ok(idx) => idx,
            Err(e) => return Err(TantivyIndexError::TantivyError(e)),
        };

        // set up default tokenizers
        let tokenizer = TextAnalyzer::builder(UnicodeTokenizer::default())
            .filter(LowerCaser)
            .filter(AsciiFoldingFilter)
            .build();

        index.tokenizers().register("unicode", tokenizer);

        let writer = index.writer(
            // 100 MB heap size
            100_000_000,
        )?;

        let reader = index.reader()?;

        Ok(TantivyIndex {
            index,
            writer: Mutex::new(writer),
            reader,
        })
    }

    #[uniffi::method]
    fn clear_index(&self) -> Result<(), TantivyIndexError> {
        // acquire the writer lock
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

        // acquire the writer lock
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

        // acquire the writer lock
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

        // acquire the writer lock
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
        let query = TermQuery::new(term, IndexRecordOption::Basic);
        let top_docs = searcher.search(&query, &TopDocs::with_limit(1))?;

        Ok(!top_docs.is_empty())
    }

    #[uniffi::method]
    fn get_doc(&self, id_field: String, id_value: String) -> Result<String, TantivyIndexError> {
        let schema = self.index.schema();

        let field = schema.get_field(&id_field)?;
        let term = Term::from_field_text(field, &id_value);

        let searcher = self.reader.searcher();
        let query = TermQuery::new(term, IndexRecordOption::Basic);
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
        let doc_count = searcher.num_docs();
        doc_count
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

        // TODO: return the errors back
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

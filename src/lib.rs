use serde::{Deserialize, Serialize};
use std::path::Path;
use std::sync::Mutex;
use tantivy::tokenizer::AsciiFoldingFilter;

use tantivy::Index;
use tantivy::IndexReader;
use tantivy::IndexWriter;
use tantivy::TantivyDocument;
use tantivy::collector::TopDocs;
use tantivy::directory::MmapDirectory;
use tantivy::doc;
use tantivy::query::QueryParser;
use tantivy::query::TermQuery;
use tantivy::schema::FAST;
use tantivy::schema::INDEXED;
use tantivy::schema::IndexRecordOption;
use tantivy::schema::STORED;
use tantivy::schema::STRING;
use tantivy::schema::Schema;
use tantivy::schema::TextFieldIndexing;
use tantivy::schema::TextOptions;
use tantivy::schema::Value;
use tantivy::tokenizer::LowerCaser;
use tantivy::tokenizer::TextAnalyzer;

mod unicode_tokenizer;
use crate::unicode_tokenizer::UnicodeTokenizer;

#[derive(Serialize, Deserialize, uniffi::Record)]
pub struct ReceiptSearchResult {
    pub item: ReceiptIndexItem,
    pub score: f32,
}

#[derive(Serialize, Deserialize, uniffi::Record)]
pub struct ReceiptIndexItem {
    pub receipt_id: String,
    pub merchant_name: String,
    pub notes: String,
    pub transaction_date: String, // ISO 8601 format
    pub converted_total: f64,
    pub tags: Vec<String>,
}

impl ReceiptIndexItem {
    pub fn new(
        receipt_id: String,
        merchant_name: String,
        notes: String,
        transaction_date: String,
        converted_total: f64,
        tags: Vec<String>,
    ) -> Self {
        ReceiptIndexItem {
            receipt_id,
            merchant_name,
            notes,
            transaction_date,
            converted_total,
            tags,
        }
    }

    pub fn from_tantivy_doc(doc: TantivyDocument, schema: Schema) -> Self {
        ReceiptIndexItem {
            receipt_id: doc
                .get_first(schema.get_field("receipt_id").unwrap())
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string(),
            merchant_name: doc
                .get_first(schema.get_field("merchant_name").unwrap())
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string(),
            notes: doc
                .get_first(schema.get_field("notes").unwrap())
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string(),
            transaction_date: doc
                .get_first(schema.get_field("transaction_date").unwrap())
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string(),
            converted_total: doc
                .get_first(schema.get_field("converted_total").unwrap())
                .and_then(|v| v.as_f64())
                .unwrap_or(0.0),
            tags: doc
                .get_all(schema.get_field("tags").unwrap())
                .filter_map(|v| v.as_str().map(|s| s.to_string()))
                .collect(),
        }
    }
}

// uniffi is powerful, we can technically expose tantivy directly, but it's better to wrap it in our own types for development speed for now.
// this means that the schema is fixed for the build binary, and for each project we will need to recompile the rust code to change the schema.
#[derive(uniffi::Object)]
pub struct ReceiptIndex {
    index: Index,
    writer: Mutex<IndexWriter>,
    reader: IndexReader,
}

#[uniffi::export]
impl ReceiptIndex {
    #[uniffi::constructor]
    pub fn new(path: String) -> Self {
        let index_path = Path::new(&path);

        let directory = MmapDirectory::open(index_path).unwrap_or_else(|_| {
            std::fs::create_dir_all(index_path).unwrap();
            MmapDirectory::open(index_path).unwrap()
        });

        // create schema
        // TODO: make schema configurable
        let mut schema_builder = Schema::builder();

        let text_field_indexing = TextFieldIndexing::default()
            .set_tokenizer("unicode")
            .set_index_option(IndexRecordOption::WithFreqsAndPositions);
        let text_options = TextOptions::default()
            .set_indexing_options(text_field_indexing)
            .set_stored();

        schema_builder.add_text_field("receipt_id", STRING | STORED);
        schema_builder.add_text_field("merchant_name", text_options.clone());
        schema_builder.add_text_field("notes", text_options.clone());
        schema_builder.add_date_field("transaction_date", INDEXED | STORED);
        schema_builder.add_f64_field("converted_total", STORED | FAST);
        schema_builder.add_text_field("tags", STRING | STORED);

        let schema = schema_builder.build();

        let index = Index::open_or_create(directory, schema).unwrap();

        let tokenizer = TextAnalyzer::builder(UnicodeTokenizer::default())
            .filter(LowerCaser)
            .filter(AsciiFoldingFilter)
            .build();

        index.tokenizers().register("unicode", tokenizer);

        let writer = index
            .writer(
                // 100 MB heap size
                100_000_000,
            )
            .unwrap();

        // or, create a reader with reload policy that reloads on commit
        let reader = index.reader().unwrap();

        ReceiptIndex {
            index,
            writer: Mutex::new(writer),
            reader,
        }
    }

    #[uniffi::method]
    fn index_receipt(&self, item: ReceiptIndexItem) {
        let schema = self.index.schema();
        // a weird way to set up a doc, should probably just create the doc directly.
        let receipt_item_json = serde_json::to_string(&item).unwrap();
        let doc = TantivyDocument::parse_json(&schema, &receipt_item_json).unwrap();
        let mut writer = self.writer.lock().unwrap();
        writer.add_document(doc).unwrap();
        writer.commit().unwrap();
        self.reader.reload().unwrap();
    }

    #[uniffi::method]
    fn delete_receipt(&self, receipt_id: String) {
        let schema = self.index.schema();
        let receipt_id_field = schema.get_field("receipt_id").unwrap();
        let term = tantivy::Term::from_field_text(receipt_id_field, &receipt_id);
        let mut writer = self.writer.lock().unwrap();
        writer.delete_term(term);
        writer.commit().unwrap();
        self.reader.reload().unwrap();
    }

    #[uniffi::method]
    fn receipt_id_exists(&self, receipt_id: String) -> bool {
        let schema = self.index.schema();
        let receipt_id_field = schema.get_field("receipt_id").unwrap();
        let term = tantivy::Term::from_field_text(receipt_id_field, &receipt_id);

        let searcher = self.reader.searcher();

        let query = TermQuery::new(term, IndexRecordOption::Basic);

        let top_docs = searcher.search(&query, &TopDocs::with_limit(1)).unwrap();

        !top_docs.is_empty()
    }

    #[uniffi::method]
    fn search_receipts(&self, query_str: String) -> Vec<ReceiptSearchResult> {
        let schema = self.index.schema();
        let merchant_name_field = schema.get_field("merchant_name").unwrap();
        let notes_field = schema.get_field("notes").unwrap();
        let tags_field = schema.get_field("tags").unwrap();

        let searcher = self.reader.searcher();

        let mut query_parser = QueryParser::for_index(
            &self.index,
            vec![merchant_name_field, notes_field, tags_field],
        );

        query_parser.set_field_fuzzy(merchant_name_field, true, 2, false);
        query_parser.set_field_fuzzy(notes_field, true, 2, false);

        let query = query_parser.parse_query_lenient(&query_str).0;

        let top_docs = searcher.search(&query, &TopDocs::with_limit(20)).unwrap();

        let mut results: Vec<ReceiptSearchResult> = Vec::new();

        for (score, doc_address) in top_docs {
            let retrieved_doc: TantivyDocument = searcher.doc(doc_address).unwrap();
            let receipt_item = ReceiptIndexItem::from_tantivy_doc(retrieved_doc, schema.clone());
            results.push(ReceiptSearchResult {
                item: receipt_item,
                score,
            });
        }

        results
    }

    #[uniffi::method]
    fn clear_index(&self) {
        let mut writer = self.writer.lock().unwrap();
        writer.delete_all_documents().unwrap();
        writer.commit().unwrap();
        self.reader.reload().unwrap();
    }
}

uniffi::setup_scaffolding!();

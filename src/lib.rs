use std::path::Path;
use std::sync::Mutex;

use tantivy::Index;
use tantivy::IndexReader;
use tantivy::IndexWriter;
use tantivy::directory::MmapDirectory;
use tantivy::doc;
use tantivy::schema::*;

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

        schema_builder.add_text_field("receipt_id", STRING | STORED);
        schema_builder.add_text_field("merchant_name", TEXT | STORED);
        schema_builder.add_date_field("transaction_date", INDEXED | STORED);
        schema_builder.add_f64_field("converted_total", STORED | FAST);
        schema_builder.add_text_field("tags", STRING | STORED);

        let schema = schema_builder.build();

        let index = Index::open_or_create(directory, schema).unwrap();

        let mut writer = index
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
    fn index_receipt(&self, receipt_json: String) {
        let schema = self.index.schema();
        let doc = TantivyDocument::parse_json(&schema, &receipt_json).unwrap();
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

    fn search_receipts(&self, query_str: String) -> String {
        let schema = self.index.schema();
        let receipt_id_field = schema.get_field("receipt_id").unwrap();
        let merchant_name_field = schema.get_field("merchant_name").unwrap();
        let tags_field = schema.get_field("tags").unwrap();

        let searcher = self.reader.searcher();

        let query = tantivy::query::QueryParser::for_index(
            &self.index,
            vec![merchant_name_field, tags_field],
        )
        .parse_query_lenient(&query_str)
        .0;

        let top_docs = searcher
            .search(&query, &tantivy::collector::TopDocs::with_limit(20))
            .unwrap();

        let mut results: Vec<String> = Vec::new();

        for (_score, doc_address) in top_docs {
            let retrieved_doc: TantivyDocument = searcher.doc(doc_address).unwrap();
            let receipt_id = retrieved_doc
                .get_first(receipt_id_field)
                .unwrap()
                .as_str()
                .unwrap()
                .to_string();
            results.push(receipt_id);
        }

        serde_json::to_string(&results).unwrap()
    }
}

uniffi::setup_scaffolding!();

use std::path::Path;

use tantivy::Index;
use tantivy::directory::MmapDirectory;
use tantivy::doc;
use tantivy::schema::*;

uniffi::setup_scaffolding!();

#[uniffi::export]
fn index_test(path_str: String) -> String {
    let index_path = Path::new(&path_str);
    let directory = MmapDirectory::open(index_path).unwrap_or_else(|_| {
        std::fs::create_dir_all(index_path).unwrap();
        MmapDirectory::open(index_path).unwrap()
    });

    let mut schema_builder = Schema::builder();

    schema_builder.add_text_field("title", TEXT | STORED);
    let schema = schema_builder.build();

    let title = schema.get_field("title").unwrap();

    let index = Index::open_or_create(directory, schema).unwrap();

    let mut index_writer = index
        .writer(
            // 50 MB heap size
            50_000_000,
        )
        .unwrap();

    let _ = index_writer.add_document(doc!(
        title => "Hello World",
    ));

    index_writer.commit().unwrap();

    let reader = index.reader().unwrap();

    let searcher = reader.searcher();

    let query = tantivy::query::QueryParser::for_index(&index, vec![title])
        .parse_query("Hello")
        .unwrap();

    let top_docs = searcher
        .search(&query, &tantivy::collector::TopDocs::with_limit(10))
        .unwrap();

    let res = serde_json::to_string(&top_docs).unwrap();

    return res;
}

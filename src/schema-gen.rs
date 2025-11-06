use tantivy::schema::*;

fn main() {
    let mut schema_builder = Schema::builder();
    let text_field_indexing = TextFieldIndexing::default()
        .set_tokenizer("unicode")
        .set_index_option(IndexRecordOption::WithFreqsAndPositions);

    let text_options = TextOptions::default()
        .set_indexing_options(text_field_indexing)
        .set_stored();

    schema_builder.add_text_field("receiptId", STRING | STORED);
    schema_builder.add_text_field("merchantName", text_options.clone());
    schema_builder.add_text_field("notes", text_options.clone());
    schema_builder.add_date_field("transactionDate", INDEXED | STORED);
    schema_builder.add_f64_field("convertedTotal", STORED | FAST);
    schema_builder.add_text_field("tags", STRING | STORED);

    let schema = schema_builder.build();

    let schema_json = serde_json::to_string_pretty(&schema).unwrap();

    // write to ./schema.json

    std::fs::write("./schema.json", &schema_json).unwrap();

    println!("{}", schema_json);
}

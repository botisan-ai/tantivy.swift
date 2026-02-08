use std::collections::VecDeque;

use tantivy::tokenizer::*;
use unicode_segmentation::{UnicodeSegmentation, UnicodeWordIndices};

#[derive(Clone, Default)]
pub struct UnicodeTokenizer {
    token: Token,
}

#[derive(Debug, Clone)]
struct PendingToken {
    text: String,
    offset_from: usize,
    offset_to: usize,
}

pub struct UnicodeTokenStream<'a> {
    pending_tokens: VecDeque<PendingToken>,
    token: &'a mut Token,
}

impl Tokenizer for UnicodeTokenizer {
    type TokenStream<'a> = UnicodeTokenStream<'a>;

    fn token_stream<'a>(&'a mut self, text: &'a str) -> Self::TokenStream<'a> {
        UnicodeTokenStream {
            pending_tokens: tokenize_text(text),
            token: &mut self.token,
        }
    }
}

fn is_apostrophe_like(ch: char) -> bool {
    matches!(
        ch,
        '\''
            | '\u{2019}' // RIGHT SINGLE QUOTATION MARK
            | '\u{2018}' // LEFT SINGLE QUOTATION MARK
            | '\u{201B}' // SINGLE HIGH-REVERSED-9 QUOTATION MARK
            | '\u{02BC}' // MODIFIER LETTER APOSTROPHE
            | '\u{FF07}' // FULLWIDTH APOSTROPHE
            | '\u{0060}' // GRAVE ACCENT
            | '\u{00B4}' // ACUTE ACCENT
            | '\u{02B9}' // MODIFIER LETTER PRIME
            | '\u{2032}' // PRIME
    )
}

fn separator_is_apostrophe_run(separator: &str) -> bool {
    !separator.is_empty() && separator.chars().all(is_apostrophe_like)
}

fn is_dash_like(ch: char) -> bool {
    matches!(
        ch,
        '-'
            | '\u{2010}' // HYPHEN
            | '\u{2011}' // NON-BREAKING HYPHEN
            | '\u{2012}' // FIGURE DASH
            | '\u{2013}' // EN DASH
            | '\u{2014}' // EM DASH
            | '\u{2015}' // HORIZONTAL BAR
            | '\u{2212}' // MINUS SIGN
            | '\u{FE63}' // SMALL HYPHEN-MINUS
            | '\u{FF0D}' // FULLWIDTH HYPHEN-MINUS
    )
}

fn separator_is_dash_run(separator: &str) -> bool {
    !separator.is_empty() && separator.chars().all(is_dash_like)
}

fn flush_pending_token(
    tokens: &mut Vec<PendingToken>,
    word_offset: usize,
    current_text: &mut String,
    current_start: &mut Option<usize>,
    current_end: &mut usize,
) {
    if let Some(start) = *current_start {
        if !current_text.is_empty() {
            tokens.push(PendingToken {
                text: std::mem::take(current_text),
                offset_from: word_offset + start,
                offset_to: word_offset + *current_end,
            });
        }
    }

    *current_start = None;
    *current_end = 0;
}

fn split_word_tokens(word_offset: usize, word: &str) -> Vec<PendingToken> {
    let mut tokens = Vec::new();

    let chars: Vec<(usize, char)> = word.char_indices().collect();
    let mut current_text = String::new();
    let mut current_start: Option<usize> = None;
    let mut current_end: usize = 0;

    for (idx, &(byte_idx, ch)) in chars.iter().enumerate() {
        let next_byte_idx = chars
            .get(idx + 1)
            .map(|(next_idx, _)| *next_idx)
            .unwrap_or(word.len());

        let prev_is_alnum = idx > 0 && chars[idx - 1].1.is_alphanumeric();
        let next_is_alnum = idx + 1 < chars.len() && chars[idx + 1].1.is_alphanumeric();

        // Apostrophe-like characters in the middle of a token are dropped.
        // Example: sam's -> sams, sam’s -> sams, samʼs -> sams.
        if is_apostrophe_like(ch) && prev_is_alnum && next_is_alnum {
            // Keep the token span continuous in offsets.
            current_end = next_byte_idx;
            continue;
        }

        if ch.is_alphanumeric() {
            if current_start.is_none() {
                current_start = Some(byte_idx);
            }
            current_text.push(ch);
            current_end = next_byte_idx;
            continue;
        }

        // Any other punctuation or symbol splits the token.
        flush_pending_token(
            &mut tokens,
            word_offset,
            &mut current_text,
            &mut current_start,
            &mut current_end,
        );
    }

    flush_pending_token(
        &mut tokens,
        word_offset,
        &mut current_text,
        &mut current_start,
        &mut current_end,
    );

    tokens
}

fn expand_dash_compounds(tokens: Vec<PendingToken>, text: &str) -> Vec<PendingToken> {
    if tokens.is_empty() {
        return tokens;
    }

    let mut expanded: Vec<PendingToken> = Vec::with_capacity(tokens.len());
    let mut idx = 0;

    while idx < tokens.len() {
        expanded.push(tokens[idx].clone());

        let mut run_end = idx;
        let mut combined_text = tokens[idx].text.clone();
        let combined_start = tokens[idx].offset_from;
        let mut combined_end = tokens[idx].offset_to;
        let mut has_dash_bridge = false;

        while run_end + 1 < tokens.len() {
            let separator = &text[tokens[run_end].offset_to..tokens[run_end + 1].offset_from];
            if separator_is_dash_run(separator) {
                has_dash_bridge = true;
                run_end += 1;
                combined_text.push_str(&tokens[run_end].text);
                combined_end = tokens[run_end].offset_to;
                expanded.push(tokens[run_end].clone());
            } else {
                break;
            }
        }

        if has_dash_bridge {
            expanded.push(PendingToken {
                text: combined_text,
                offset_from: combined_start,
                offset_to: combined_end,
            });
            idx = run_end + 1;
        } else {
            idx += 1;
        }
    }

    expanded
}

fn tokenize_text(text: &str) -> VecDeque<PendingToken> {
    let mut merged_tokens: Vec<PendingToken> = Vec::new();

    let words: UnicodeWordIndices<'_> = text.unicode_word_indices();
    for (offset_from, word) in words {
        for token in split_word_tokens(offset_from, word) {
            if let Some(last_token) = merged_tokens.last_mut() {
                if token.offset_from >= last_token.offset_to {
                    let separator = &text[last_token.offset_to..token.offset_from];
                    if separator_is_apostrophe_run(separator) {
                        last_token.text.push_str(&token.text);
                        last_token.offset_to = token.offset_to;
                        continue;
                    }
                }
            }
            merged_tokens.push(token);
        }
    }

    let expanded = expand_dash_compounds(merged_tokens, text);
    VecDeque::from(expanded)
}

impl TokenStream for UnicodeTokenStream<'_> {
    fn advance(&mut self) -> bool {
        if let Some(next_token) = self.pending_tokens.pop_front() {
            self.token.text.clear();
            self.token.position = self.token.position.wrapping_add(1);
            self.token.offset_from = next_token.offset_from;
            self.token.offset_to = next_token.offset_to;
            self.token.text.push_str(&next_token.text);
            return true;
        }

        false
    }

    fn token(&self) -> &Token {
        &self.token
    }

    fn token_mut(&mut self) -> &mut Token {
        &mut self.token
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tantivy::tokenizer::{TextAnalyzer, Token};

    fn collect_tokens(text: &str) -> Vec<Token> {
        let mut analyzer = TextAnalyzer::from(UnicodeTokenizer::default());
        let mut stream = analyzer.token_stream(text);
        let mut tokens = Vec::new();
        stream.process(&mut |token| tokens.push(token.clone()));
        tokens
    }

    fn collect_token_texts(text: &str) -> Vec<String> {
        collect_tokens(text)
            .into_iter()
            .map(|token| token.text)
            .collect()
    }

    fn assert_token(
        token: &Token,
        position: usize,
        text: &str,
        offset_from: usize,
        offset_to: usize,
    ) {
        assert_eq!(
            token.position, position,
            "unexpected position for token {:?}",
            token
        );
        assert_eq!(token.text, text, "unexpected text for token {:?}", token);
        assert_eq!(
            token.offset_from, offset_from,
            "unexpected offset_from for token {:?}",
            token
        );
        assert_eq!(
            token.offset_to, offset_to,
            "unexpected offset_to for token {:?}",
            token
        );
    }

    #[test]
    fn unicode_tokenizer_basic_latin() {
        let tokens = collect_tokens("Hello, happy tax payer!");
        assert_eq!(tokens.len(), 4);
        assert_token(&tokens[0], 0, "Hello", 0, 5);
        assert_token(&tokens[1], 1, "happy", 7, 12);
        assert_token(&tokens[2], 2, "tax", 13, 16);
        assert_token(&tokens[3], 3, "payer", 17, 22);
    }

    #[test]
    fn unicode_tokenizer_multibyte_words() {
        let tokens = collect_tokens("naïve café δέλτα 123");
        assert_eq!(tokens.len(), 4);
        assert_token(&tokens[0], 0, "naïve", 0, 6);
        assert_token(&tokens[1], 1, "café", 7, 12);
        assert_token(&tokens[2], 2, "δέλτα", 13, 23);
        assert_token(&tokens[3], 3, "123", 24, 27);
    }

    #[test]
    fn unicode_tokenizer_chinese_japanese() {
        let tokens = collect_tokens("汉字 カタカナ 한글");
        assert_eq!(tokens.len(), 4);
        assert_token(&tokens[0], 0, "汉", 0, 3);
        assert_token(&tokens[1], 1, "字", 3, 6);
        assert_token(&tokens[2], 2, "カタカナ", 7, 19);
        assert_token(&tokens[3], 3, "한글", 20, 26);
    }

    #[test]
    fn unicode_tokenizer_drops_apostrophe_variants_inside_tokens() {
        let token_texts = collect_token_texts("Sam's Sam’s Samʼs Sam`s Sam´s");
        assert_eq!(token_texts, vec!["Sams", "Sams", "Sams", "Sams", "Sams"]);
    }

    #[test]
    fn unicode_tokenizer_splits_symbols_and_emits_dash_compounds() {
        let token_texts = collect_token_texts("co-op foo/bar baz—qux sam's-club");
        assert_eq!(
            token_texts,
            vec![
                "co", "op", "coop", "foo", "bar", "baz", "qux", "bazqux", "sams", "club",
                "samsclub"
            ]
        );
    }

    #[test]
    fn unicode_tokenizer_emits_single_compound_for_multi_dash_run() {
        let token_texts = collect_token_texts("state-of-the-art");
        assert_eq!(
            token_texts,
            vec!["state", "of", "the", "art", "stateoftheart"]
        );
    }
}

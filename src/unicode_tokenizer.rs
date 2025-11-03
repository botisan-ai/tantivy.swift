use tantivy::tokenizer::*;
use unicode_segmentation::{UnicodeSegmentation, UnicodeWordIndices};

#[derive(Clone, Default)]
pub struct UnicodeTokenizer {
    token: Token,
}

pub struct UnicodeTokenStream<'a> {
    words: UnicodeWordIndices<'a>,
    token: &'a mut Token,
}

impl Tokenizer for UnicodeTokenizer {
    type TokenStream<'a> = UnicodeTokenStream<'a>;

    fn token_stream<'a>(&'a mut self, text: &'a str) -> Self::TokenStream<'a> {
        UnicodeTokenStream {
            words: text.unicode_word_indices(),
            token: &mut self.token,
        }
    }
}

impl TokenStream for UnicodeTokenStream<'_> {
    fn advance(&mut self) -> bool {
        self.token.text.clear();
        self.token.position = self.token.position.wrapping_add(1);
        if let Some((offset_from, word)) = self.words.next() {
            self.token.offset_from = offset_from;
            self.token.offset_to = offset_from + word.len();
            self.token.text.push_str(word);
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
}

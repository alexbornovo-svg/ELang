class Token
  attr_reader :type, :value

  def initialize(type, value)
    @type = type
    @value = value
  end

  def to_s
    "Token(Type: #{@type}, Value: '#{@value}')"
  end
end

KEYWORDS = {
  "let" => "KEYWORDS_LET",
  "if" => "KEYWORDS_IF",
  "else" => "KEYWORDS_ELSE",
  "print" => "KEYWORDS_PRINT"
}.freeze

_msg = "let x = 10.2; print x"
parts = []
tokens = []

parts = _msg.scan(/\d+\.\d+|\w+|[=;]|\S/) # Array of things to be tokenized


# Basically all the tokenization process (aka Lexer)
parts.each_with_index do |c, index|
  if KEYWORDS.key?(c.downcase)
    tokens << Token.new(KEYWORDS[c.downcase], c)
  elsif c == "="
    tokens << Token.new("ASSIGN", c)
  elsif c == ";"
    tokens << Token.new("SEMICOLON", c)
  elsif c =~ /^\d+\.\d+$/                     # Decimal check
    tokens << Token.new("DECIMAL", c)
  elsif c =~ /^\d+$/                          # Integer check
    tokens << Token.new("INT", c)
  elsif c =~ /^[a-zA-Z_]\w*$/
    tokens << Token.new("IDENTIFIER", c)
  else
    tokens << Token.new("UNKNOWN", c)
  end
end

puts tokens



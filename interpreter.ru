!/usr/bin/env ruby

class Token
  attr_reader :type, :value

  def initialize(type, value)
    @type = type
    @value = value
  end

  def to_s
    "Token(Type: #{@type}, Value: '#{@value}')"
  end
  
  def show_type
    "#{@type}" 
  end

  def show_value
    "#{@value}" 
  end
end

class Block
	attr_reader :idx, :type, :indent
	attr_accessor :args
	
	def initialize(idx, type, args = [], indent = 0)
		@idx = idx
		@type = type
		@args = args
		@indent = indent
  	end

	def to_s
		"Block(##{@idx}: #{@type}, args=#{@args.inspect}, indent=#{@indent})"
	end

	def execute(env)
		case @type
		when "ASSIGN"
			name, raw = @args[0], @args[1]
			value = coerce(raw, env)
			env[name] = Variable.new(name, infer_type(raw), value)
		when "PRINT"
			raw = @args[0]
			if env.key?(raw)
				puts env[raw].show_value
			else
				puts coerce(raw, env)
			end
		when "GET_INPUT"
			name = @args[0]
			raw = $stdin.gets&.chomp
			if env.key?(name)
				var = env[name]
				env[name] = Variable.new(name, var.type, coerce_input(raw, var.type))
			else
				puts "ERROR: Undefined variable '#{name}'"
			end
		
		when "IF_BLOCK"
			raw = @args[0]
			val = env.key?(raw) ? env[raw].show_value : coerce(raw, env)
			val.to_f != 0
		when "ELSE_BLOCK"
			nil
		when "BRAKET_OPEN_CURL", "BRAKET_CLOSE_CURL"
			nil
		else
			raise "Unkwnow block type: #{@type}"
		end
	end

	private
	def coerce(raw, env)
		return env[raw].show_value if env.key?(raw)
		return raw.to_f if raw =~ /^\d+\.\d+$/
		return raw.to_i if raw =~ /^\d+$/
		raw
	end

	def coerce_input(raw, type)
		case type
		when "INT" then raw.to_i
		when "DECIMAL" then raw.to_f
		else raw
		end
	end

  	def infer_type(raw)
		return "DECIMAL" if raw =~ /^\d+\.\d+$/
		return "INT" if raw =~ /^\d+$/
    	"STRING"
	end
end

class Variable 
  attr_reader :name, :type, :value
  
  def initialize(name, type, value)
    @name = name 
    @type = type
    @value = value 
  end 
  
  def change_v(value)
    @value = value
  end 
  
  def show_value
    @value
  end
end

KEYWORDS = {
  "let" => "KEYWORDS_LET",
  "if" => "KEYWORDS_IF",
  "else" => "KEYWORDS_ELSE",
  "print" => "KEYWORDS_PRINT",
  "get" => "KEYWORDS_GET",

  # Brakets
  "{" => "BRAKET_OPEN_CURL",
  "}" => "BRAKET_CLOSE_CURL",
  "(" => "BRAKET_OPEN_ROUND",
  ")" => "BRAKET_CLOSE_ROUND"
}.freeze

EXITCODES = {
  "No errors" => 0,
  "Undefined reference" => 1,
  "Bracket error" => 2,
  "No source file" => 3
}.freeze

exitcode = 0

if ARGV[0]
	source_path = ARGV[0]
	
	unless File.exist?(source_path)
		puts "ERROR: File not found: #{source_path}"
		exit EXITCODES["No source file"]
	end

	_msg = File.read(source_path).gsub("\n", " ").strip
end

# _msg = "let x = 10.2; print(x); print(5); if (x) { print(1) } else { print(0) }"
parts = []
tokens = []
declared = []

parts = _msg.scan(/"[^"]*"|\d+\.\d+|\w+|[{}()=;]|\S/)  # Array of things to be tokenized

# Basically all the tokenization process (aka Lexer)
parts.each_with_index do |c, index|
	if KEYWORDS.key?(c.downcase)
		tokens << Token.new(KEYWORDS[c.downcase], c)
	elsif c == "="
		tokens << Token.new("ASSIGN", c)
	elsif c == ";"
		tokens << Token.new("SEMICOLON", c)
	elsif c =~ /^\d+\.\d+$/
		tokens << Token.new("DECIMAL", c)
	elsif c =~ /^".*"$/
		tokens << Token.new("STRING", c[1..-2]) 
	elsif c =~ /^\d+$/
		tokens << Token.new("INT", c)
	elsif c =~ /^[a-zA-Z_]\w*$/ && index > 0 && parts[index - 1].downcase == "let"
		tokens << Token.new("IDENTIFIER", c)
		declared << c
	else
		if not declared.include?(c)
			tokens << Token.new("UNKNOWN", c)
		else 
		 	tokens << Token.new("IDENTIFIER", c)
		end
	end
end

# AST creation process 
ast   = []
_idx  = 0

tokens.each_with_index do |token, i|
	block = case token.type

	when "KEYWORDS_LET"
		Block.new(_idx, "ASSIGN", [tokens[i+1]&.value, tokens[i+3]&.value])

	when "KEYWORDS_PRINT"
		Block.new(_idx, "PRINT", [tokens[i+2]&.value])

	when "KEYWORDS_GET"
		Block.new(_idx, "GET_INPUT", [tokens[i+2]&.value])

	when "KEYWORDS_IF"
		Block.new(_idx, "IF_BLOCK", [tokens[i+2]&.value])

	when "KEYWORDS_ELSE"
		Block.new(_idx, "ELSE_BLOCK")

	when "BRAKET_OPEN_CURL"
		Block.new(_idx, "BRAKET_OPEN_CURL")

	when "BRAKET_CLOSE_CURL"
		Block.new(_idx, "BRAKET_CLOSE_CURL")

	when "UNKNOWN"
		puts "ERROR: Undefined reference to #{token}"
		exitcode = EXITCODES["Undefined reference"]
		break

	else
		next  # IDENTIFIER, ASSIGN, SEMICOLON - To be implemented
	end

	_idx += 1
	ast << block
end

# Brackets and If-Else evaluation

_indentation = 0
_last = "BRAKET_CLOSE_CURL"

if exitcode == 0
	ast.each do |block|
	if block.type == "BRAKET_OPEN_CURL"
		if _last == "BRAKET_CLOSE_CURL"
		_indentation += 1
		_last = "BRAKET_OPEN_CURL"
		else
		puts "ERROR: Unexpected open bracket"; exitcode = EXITCODES["Bracket error"]; break
		end
	elsif block.type == "BRAKET_CLOSE_CURL"
		if _last == "BRAKET_OPEN_CURL"
		_indentation -= 1
		_last = "BRAKET_CLOSE_CURL"
		else
		puts "ERROR: Unexpected close bracket"; exitcode = EXITCODES["Bracket error"]; break
		end
	end

	if _indentation < 0
		puts "ERROR: Unmatched bracket"; exitcode = EXITCODES["Bracket error"]; break
	end

	block.args << _indentation
	end
end

# Interpreter part

if exitcode == 0
	env = {}
	skip_indent = nil
	else_pending = false

	ast.each do |block|
		if skip_indent && block.indent >= skip_indent &&
			block.type != "BRAKET_CLOSE_CURL"
			else_pending = (block.type == "ELSE_BLOCK")
			next
		end
		skip_indent  = nil if block.type == "BRAKET_CLOSE_CURL"

		result = block.execute(env)

		if block.type == "IF_BLOCK"
			unless result
				skip_indent  = block.indent + 1
				else_pending = true
			else
				else_pending = false
			end
		end

		if block.type == "ELSE_BLOCK"
			skip_indent = else_pending ? nil : block.indent + 1
			else_pending = false
		end
	end
end

puts "Ended with code #{exitcode}"




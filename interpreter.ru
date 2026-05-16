#!/usr/bin/env ruby

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
	attr_accessor :args, :target_idx, :source_idx

	def initialize(idx, type, args = [], indent = 0)
		@idx = idx
		@type = type
		@args = args
		@indent = indent
		@target_idx = nil
		@source_idx = nil
	end

	def to_s
		"Block(##{@idx}: #{@type}, args=#{@args.inspect}, indent=#{@indent})"
	end

	def execute(env)
		case @type
		when "ASSIGN", "REASSIGN"
			name = @args[0]
			raw  = @args[1]
			op   = @args[2]
			rhs  = @args[3]

			if op && MATH_OPS.include?(op)
				left  = env.key?(raw) ? env[raw].show_value : coerce(raw, env)
				right = env.key?(rhs) ? env[rhs].show_value : coerce(rhs, env)
				value = case op
				when "+" then left.to_f + right.to_f
				when "-" then left.to_f - right.to_f
				when "*" then left.to_f * right.to_f
				when "/" then right.to_f == 0 ? (puts "ERROR: Division by zero"; 0) : left.to_f / right.to_f
				when "%" then left.to_f % right.to_f
				end
				value = value % 1 == 0 ? value.to_i : value
			else
				value = coerce(raw, env)
			end

			if @type == "REASSIGN" && !env.key?(name)
				puts "ERROR: Undefined variable '#{name}'"
			else
				env[name] = Variable.new(name, infer_type(value.to_s), value)
			end

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

		when "IF_BLOCK", "WHILE_BLOCK"
			left_raw = @args[0]
			left = env.key?(left_raw) ? env[left_raw].show_value : coerce(left_raw, env)

			if LO_OPS.include?(@args[1])
				op        = @args[1]
				right_raw = @args[2]
				right = env.key?(right_raw) ? env[right_raw].show_value : coerce(right_raw, env)

				result = case op
				when "==" then left.to_f == right.to_f
				when "!=" then left.to_f != right.to_f
				when ">"  then left.to_f >  right.to_f
				when "<"  then left.to_f <  right.to_f
				when ">=" then left.to_f >= right.to_f
				when "<=" then left.to_f <= right.to_f
				end
				result ? 1 : 0
			else
				left.to_f != 0 ? 1 : 0
			end

		when "LOOP_BLOCK"
			# Restituisce il numero di iterazioni rimaste
			name  = @args[0]
			count = env.key?(name) ? env[name].show_value.to_i : name.to_i
			count

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
		return "DECIMAL" if raw.to_s =~ /^\d+\.\d+$/
		return "INT" if raw.to_s =~ /^\d+$/
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
	"let"   => "KEYWORDS_LET",
	"if"    => "KEYWORDS_IF",
	"else"  => "KEYWORDS_ELSE",
	"print" => "KEYWORDS_PRINT",
	"get"   => "KEYWORDS_GET",
	"while" => "KEYWORDS_WHILE",
	"loop"  => "KEYWORDS_LOOP",

	# Logic operators
	"==" => "LO_EQU",
	"!=" => "LO_DIF",
	">"  => "LO_GRE",
	"<"  => "LO_LOW",
	">=" => "LO_GEQ",
	"<=" => "LO_LEQ",

	# Math operators
	"+" => "MATH_ADD",
	"-" => "MATH_SUB",
	"*" => "MATH_MUL",
	"%" => "MATH_MOD",

	# Brakets
	"{" => "BRAKET_OPEN_CURL",
	"}" => "BRAKET_CLOSE_CURL",
	"(" => "BRAKET_OPEN_ROUND",
	")" => "BRAKET_CLOSE_ROUND",

	# Comments
	"/" => "COMMENT"
}.freeze

LO_OPS   = ["==", "!=", "<", ">", "<=", ">="].freeze
MATH_OPS = ["+", "-", "*", "/", "%"].freeze

EXITCODES = {
	"No errors"          => 0,
	"Undefined reference" => 1,
	"Bracket error"      => 2,
	"No source file"     => 3
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

parts = []
tokens = []
declared = []

parts = _msg.scan(/"[^"]*"|\d+\.\d+|\w+|==|!=|<=|>=|[{}()=<>+\-*%;]|\S/)  # Array of things to be tokenized

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
ast          = []
_idx         = 0
_open_comment = false

tokens.each_with_index do |token, i|
	if _open_comment
		if token.type == "COMMENT"
			_open_comment = false
		end
		next
	end

	block = case token.type

	when "KEYWORDS_LET"
		name = tokens[i+1]&.value
		raw  = tokens[i+3]&.value
		op   = tokens[i+4]&.value
		rhs  = tokens[i+5]&.value

		if op && MATH_OPS.include?(op)
			Block.new(_idx, "ASSIGN", [name, raw, op, rhs])
		else
			Block.new(_idx, "ASSIGN", [name, raw])
		end

	when "IDENTIFIER"
		# Riassegnazione: x = 20; oppure x = x + 1;
		if tokens[i+1]&.type == "ASSIGN"
			name = token.value
			raw  = tokens[i+2]&.value
			op   = tokens[i+3]&.value
			rhs  = tokens[i+4]&.value

			if op && MATH_OPS.include?(op)
				Block.new(_idx, "REASSIGN", [name, raw, op, rhs])
			else
				Block.new(_idx, "REASSIGN", [name, raw])
			end
		else
			next
		end

	when "KEYWORDS_PRINT"
		Block.new(_idx, "PRINT", [tokens[i+2]&.value])

	when "KEYWORDS_GET"
		Block.new(_idx, "GET_INPUT", [tokens[i+2]&.value])

	when "KEYWORDS_IF"
		left  = tokens[i+2]&.value
		op    = tokens[i+3]&.value
		right = tokens[i+4]&.value

		lo_types = ["LO_EQU", "LO_DIF", "LO_GRE", "LO_LOW", "LO_GEQ", "LO_LEQ"]
		if tokens[i+3] && lo_types.include?(tokens[i+3].type)
			Block.new(_idx, "IF_BLOCK", [left, op, right])
		else
			Block.new(_idx, "IF_BLOCK", [left])
		end

	when "KEYWORDS_WHILE"
		left  = tokens[i+2]&.value
		op    = tokens[i+3]&.value
		right = tokens[i+4]&.value

		lo_types = ["LO_EQU", "LO_DIF", "LO_GRE", "LO_LOW", "LO_GEQ", "LO_LEQ"]
		if tokens[i+3] && lo_types.include?(tokens[i+3].type)
			Block.new(_idx, "WHILE_BLOCK", [left, op, right])
		else
			Block.new(_idx, "WHILE_BLOCK", [left])
		end

	when "KEYWORDS_LOOP"
		# loop (n) { ... }
		Block.new(_idx, "LOOP_BLOCK", [tokens[i+2]&.value])

	when "KEYWORDS_ELSE"
		Block.new(_idx, "ELSE_BLOCK")

	when "BRAKET_OPEN_CURL"
		Block.new(_idx, "BRAKET_OPEN_CURL")

	when "BRAKET_CLOSE_CURL"
		Block.new(_idx, "BRAKET_CLOSE_CURL")

	when "COMMENT" # Skip comments
		_open_comment = true
		next

	when "UNKNOWN"
		puts "ERROR: Undefined reference to #{token}"
		exitcode = EXITCODES["Undefined reference"]
		break

	else
		next  # ASSIGN, SEMICOLON - To be implemented
	end

	if block.nil? || !block.is_a?(Block)  # Guard for unexpected types
		next
	end

	_idx += 1
	ast << block
end

# Bracket matching and indentation tracking

_indentation = 0
_last        = "BRAKET_CLOSE_CURL"

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

	# For each IF/ELSE/WHILE/LOOP, find the closing } at the same indent level
	# target_idx tells the interpreter where to jump when skipping a branch
	ast.each_with_index do |block, i|
		next unless ["IF_BLOCK", "ELSE_BLOCK", "WHILE_BLOCK", "LOOP_BLOCK"].include?(block.type)
		my_indent = block.args.last
		target = ast[(i+1)..].find { |b| b.type == "BRAKET_CLOSE_CURL" && b.args.last == my_indent }
		block.target_idx = target&.idx
		block.source_idx = block.idx
	end
end

# Interpreter part

if exitcode == 0
	env            = {}
	skip_until_idx = nil
	else_pending   = false
	loop_counters  = {}
	i              = 0

	while i < ast.length
		block = ast[i]

		# Skip blocks inside a branch we're not taking, up to and including the closing }
		if skip_until_idx && block.idx <= skip_until_idx
			else_pending   = true if block.type == "ELSE_BLOCK"
			skip_until_idx = nil  if block.idx == skip_until_idx
			i += 1
			next
		end

		result = block.execute(env)

		if block.type == "IF_BLOCK"
			if result == 0
				# Condition is false: skip to the closing } and wait for a possible else
				skip_until_idx = block.target_idx
				else_pending   = true
			else
				else_pending = false
			end
		end

		if block.type == "ELSE_BLOCK"
			if else_pending
				else_pending = false
			else
				skip_until_idx = block.target_idx
			end
		end

		if block.type == "WHILE_BLOCK"
			if result == 0
				# Condition is false: skip the body
				skip_until_idx = block.target_idx
			end
		end

		if block.type == "LOOP_BLOCK"
			key = block.idx
			loop_counters[key] ||= result
			if loop_counters[key] <= 0
				# Done: skip the body
				loop_counters.delete(key)
				skip_until_idx = block.target_idx
			end
		end

		# When hitting a closing } that belongs to a while/loop, jump back to the head
		if block.type == "BRAKET_CLOSE_CURL"
			owner = ast.find { |b| ["WHILE_BLOCK", "LOOP_BLOCK"].include?(b.type) && b.target_idx == block.idx }
			if owner
				if owner.type == "LOOP_BLOCK"
					loop_counters[owner.idx] -= 1
					if loop_counters[owner.idx] <= 0
						loop_counters.delete(owner.idx)
						i += 1
						next
					end
				end
				# Jump back to the while/loop block
				i = ast.index { |b| b.idx == owner.idx }
				next
			end
		end

		i += 1
	end
end

puts "Ended with code #{exitcode}"
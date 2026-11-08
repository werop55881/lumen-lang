# ============================================================================
# Lumen 0.3.0 - friendly, Python-like, interpreted language
# Implemented in PowerShell (tree-walk interpreter). No external runtime needed.
#
# Design goals:
#   1. Easy & friendly  - like Python but simpler: no required semicolons,
#                          single/double quotes, def, # comments, True/False/None
#   2. Fast to run      - single pass, no compile step, instant startup
#   3. Powerful         - classes + inheritance, try/catch/finally, throw,
#                          import modules, first-class closures
#
# Organizers: () [] {} "" '' : ;
#
# Usage:
#   pwsh -NoProfile -ExecutionPolicy Bypass -File lumen.ps1          # REPL
#   pwsh -NoProfile -ExecutionPolicy Bypass -File lumen.ps1 script.ln # run file
# ============================================================================

# ----------------------------------------------------------------------------
# 1. TOKENS
# ----------------------------------------------------------------------------
class Token {
    [string]  $Type
    [object]  $Lexeme
    [object]  $Literal
    [int]     $Line

    Token([string]$type, [object]$lexeme, [object]$literal, [int]$line) {
        $this.Type    = $type
        $this.Lexeme  = $lexeme
        $this.Literal = $literal
        $this.Line    = $line
    }

    [string] ToString() {
        return "{0} {1} {2}" -f $this.Type, $this.Lexeme, $this.Literal
    }
}

# ----------------------------------------------------------------------------
# 2. LEXER
# ----------------------------------------------------------------------------
class Lexer {
    [string]   $source
    [int[]]    $chars
    [int]      $start = 0
    [int]      $current = 0
    [int]      $line = 1
    [int]      $depth = 0          # bracket depth, so newlines inside (...) don't split
    [System.Collections.Generic.List[Token]] $tokens = [System.Collections.Generic.List[Token]]::new()

    static [string[]]  $keywords = @(
        "and", "break", "catch", "class", "def", "else", "false", "finally",
        "for", "fun", "from", "if", "import", "in", "is", "let", "nil", "None", "or", "print",
        "return", "super", "this", "throw", "try", "True", "while", "False"
    )
    static [hashtable] $keywordMap = @{}

    static [void] Init() {
        [Lexer]::keywordMap = @{}
        foreach ($kw in [Lexer]::keywords) {
            [Lexer]::keywordMap[$kw] = $kw
        }
    }

    Lexer([string]$source) {
        $this.source = $source
        $this.chars = @()
        foreach ($c in $source.ToCharArray()) {
            $this.chars += [int][char]$c
        }
    }

    [bool] IsAtEnd() { return $this.current -ge $this.chars.Count }
    [int] Peek() {
        if ($this.IsAtEnd()) { return 0 }
        return $this.chars[$this.current]
    }
    [int] PeekNext() {
        if ($this.current + 1 -ge $this.chars.Count) { return 0 }
        return $this.chars[$this.current + 1]
    }
    [bool] Match([int]$expected) {
        if ($this.IsAtEnd()) { return $false }
        if ($this.chars[$this.current] -ne $expected) { return $false }
        $this.current++
        return $true
    }
    [int] Advance() {
        $c = $this.chars[$this.current]
        $this.current++
        return $c
    }
    [void] AddToken([string]$type, [object]$literal = $null) {
        $text = $this.source.Substring($this.start, $this.current - $this.start)
        $tok = [Token]::new($type, $text, $literal, $this.line)
        $this.tokens.Add($tok)
    }

    [void] ScanToken() {
        $c = $this.Advance()
        switch ($c) {
            { $_ -eq 40 } { $this.depth++; $this.AddToken("LEFT_PAREN", $null)  }
            { $_ -eq 41 } { $this.depth--; $this.AddToken("RIGHT_PAREN", $null)  }
            { $_ -eq 123 } { $this.depth++; $this.AddToken("LEFT_BRACE", $null)  }
            { $_ -eq 125 } { $this.depth--; $this.AddToken("RIGHT_BRACE", $null)  }
            { $_ -eq 91 } { $this.depth++; $this.AddToken("LEFT_BRACKET", $null)  }
            { $_ -eq 93 } { $this.depth--; $this.AddToken("RIGHT_BRACKET", $null)  }

            { $_ -eq 44 } { $this.AddToken("COMMA", $null)  }
            { $_ -eq 46 } { $this.AddToken("DOT", $null)  }
            { $_ -eq 45 } { $this.AddToken("MINUS", $null)  }
            { $_ -eq 43 } { $this.AddToken("PLUS", $null)  }
            { $_ -eq 59 } { $this.AddToken("SEMICOLON", $null)  }
            { $_ -eq 42 } { if ($this.Match(42)) { $this.AddToken("EXPONENT", $null) } else { $this.AddToken("STAR", $null) } }
            { $_ -eq 37 } { $this.AddToken("MODULO", $null)  }
            { $_ -eq 58 } { $this.AddToken("COLON", $null)  }
            { $_ -eq 63 } {
                if ($this.Match(63)) {
                    if ($this.Match(61)) { $this.AddToken("QUESTION_QUESTION_EQUAL", $null)  }
                    else { $this.AddToken("QUESTION_QUESTION", $null)  }
                } else {
                    $this.AddToken("QUESTION", $null) 
                }
            }
            { $_ -eq 33 } {
                if ($this.Match(61)) { $this.AddToken("BANG_EQUAL", $null)  }
                else { $this.AddToken("BANG", $null)  }
            }
            { $_ -eq 61 } {
                if ($this.Match(61)) { $this.AddToken("EQUAL_EQUAL", $null)  }
                else { $this.AddToken("EQUAL", $null)  }
            }
            { $_ -eq 60 } {
                if ($this.Match(61)) { $this.AddToken("LESS_EQUAL", $null)  }
                else { $this.AddToken("LESS", $null)  }
            }
            { $_ -eq 62 } {
                if ($this.Match(61)) { $this.AddToken("GREATER_EQUAL", $null)  }
                else { $this.AddToken("GREATER", $null)  }
            }
            { $_ -eq 47 } {
                if ($this.Match(47)) {
                    while ($this.Peek() -ne 10 -and -not $this.IsAtEnd()) {
                        $this.Advance() | Out-Null
                    }
                } elseif ($this.Match(42)) {
                    $closed = $false
                    while (-not $this.IsAtEnd()) {
                        if ($this.Peek() -eq 10) { $this.line++ }
                        if ($this.Peek() -eq 42 -and $this.PeekNext() -eq 47) {
                            $this.Advance() | Out-Null
                            $this.Advance() | Out-Null
                            $closed = $true
                            break
                        }
                        $this.Advance() | Out-Null
                    }
                    if (-not $closed) {
                        Write-Warning ("[line {0}] Unterminated block comment." -f $this.line)
                    }
                } else {
                    $this.AddToken("SLASH", $null) 
                }
            }
            { $_ -eq 35 } {
                while ($this.Peek() -ne 10 -and -not $this.IsAtEnd()) {
                    $this.Advance() | Out-Null
                }
            }
            { $_ -eq 32 } { } { $_ -eq 13 } { } { $_ -eq 9 } { }

            { $_ -eq 10 } {
                if ($this.depth -eq 0) { $this.AddToken("NEWLINE", $null)  }
                $this.line++
            }

            { $_ -eq 34 } { $this.String(34) }
            { $_ -eq 39 } { $this.String(39) }

            default {
                if ($this.IsDigit($c)) { $this.Number() }
                elseif ($this.IsAlpha($c)) { $this.Identifier() }
                else { Write-Warning ("[line {0}] Unexpected character: {1}" -f $this.line, [char]$c) }
            }
        }
    }

    [void] String([int]$quote) {
        while ($this.Peek() -ne $quote -and -not $this.IsAtEnd()) {
            if ($this.Peek() -eq 10) { $this.line++ }
            $this.Advance() | Out-Null
        }
        if ($this.IsAtEnd()) {
            Write-Warning ("[line {0}] Unterminated string." -f $this.line)
            return
        }
        $this.Advance() | Out-Null
        $value = $this.source.Substring($this.start + 1, $this.current - $this.start - 2)
        $this.AddToken("STRING", $value)
    }

    [bool] IsDigit([int]$c) { return $c -ge 48 -and $c -le 57 }
    [bool] IsAlpha([int]$c) {
        return ($c -ge 65 -and $c -le 90) -or ($c -ge 97 -and $c -le 122) -or $c -eq 95
    }
    [bool] IsAlphaNumeric([int]$c) { return $this.IsAlpha($c) -or $this.IsDigit($c) }

    [void] Identifier() {
        while ($this.IsAlphaNumeric($this.Peek())) { $this.Advance() | Out-Null }
        $text = $this.source.Substring($this.start, $this.current - $this.start)
        $type = "IDENTIFIER"
        if ([Lexer]::keywordMap.ContainsKey($text)) {
            $type = "KEYWORD_" + $text
        }
        $this.AddToken($type, $null)
    }

    [void] Number() {
        while ($this.IsDigit($this.Peek())) { $this.Advance() | Out-Null }
        if ($this.Peek() -eq 46 -and $this.IsDigit($this.PeekNext())) {
            $this.Advance() | Out-Null
            while ($this.IsDigit($this.Peek())) { $this.Advance() | Out-Null }
        }
        $text = $this.source.Substring($this.start, $this.current - $this.start)
        $this.AddToken("NUMBER", [double]$text)
    }

    [System.Collections.Generic.List[Token]] ScanTokens() {
        while (-not $this.IsAtEnd()) {
            $this.start = $this.current
            $this.ScanToken()
        }
        $this.tokens.Add([Token]::new("EOF", $null, $null, $this.line))
        return $this.tokens
    }
}

# ----------------------------------------------------------------------------
# 3. AST NODES
# ----------------------------------------------------------------------------
class Expr { }
class Stmt  { }

class ExprBinary        : Expr { [Expr]$left; [Token]$op; [Expr]$right; ExprBinary([Expr]$l,[Token]$o,[Expr]$r){$this.left=$l;$this.op=$o;$this.right=$r} }
class ExprGrouping      : Expr { [Expr]$expression; ExprGrouping([Expr]$e){$this.expression=$e} }
class ExprLiteral       : Expr { [object]$value; ExprLiteral([object]$v){$this.value=$v} }
class ExprUnary         : Expr { [Token]$op; [Expr]$right; ExprUnary([Token]$o,[Expr]$r){$this.op=$o;$this.right=$r} }
class ExprVariable      : Expr { [Token]$name; ExprVariable([Token]$n){$this.name=$n} }
class ExprAssign        : Expr { [Token]$name; [Expr]$value; ExprAssign([Token]$n,[Expr]$v){$this.name=$n;$this.value=$v} }
class ExprLogical       : Expr { [Expr]$left; [Token]$op; [Expr]$right; ExprLogical([Expr]$l,[Token]$o,[Expr]$r){$this.left=$l;$this.op=$o;$this.right=$r} }
class ExprCall          : Expr { [Expr]$callee; [Token]$paren; [Expr[]]$arguments; ExprCall([Expr]$c,[Token]$p,[Expr[]]$a){$this.callee=$c;$this.paren=$p;$this.arguments=$a} }
class ExprGet           : Expr { [Expr]$object; [Token]$name; [bool]$isIndex; [Expr]$index; ExprGet([Expr]$o,[Token]$n,[bool]$i,[Expr]$ix){$this.object=$o;$this.name=$n;$this.isIndex=$i;$this.index=$ix} }
class ExprSet           : Expr { [Expr]$object; [Token]$name; [bool]$isIndex; [Expr]$index; [Expr]$value; ExprSet([Expr]$o,[Token]$n,[bool]$i,[Expr]$ix,[Expr]$v){$this.object=$o;$this.name=$n;$this.isIndex=$i;$this.index=$ix;$this.value=$v} }
class ExprList          : Expr { [Expr[]]$elements; ExprList([Expr[]]$e){$this.elements=$e} }
class ExprMap           : Expr { [string[]]$keys; [Expr[]]$values; ExprMap([string[]]$k,[Expr[]]$v){$this.keys=$k;$this.values=$v} }
class ExprCoalesce      : Expr { [Expr]$left; [Token]$op; [Expr]$right; ExprCoalesce([Expr]$l,[Token]$o,[Expr]$r){$this.left=$l;$this.op=$o;$this.right=$r} }

class StmtExpression    : Stmt { [Expr]$expression; StmtExpression([Expr]$e){$this.expression=$e} }
class StmtPrint         : Stmt { [Expr]$expression; StmtPrint([Expr]$e){$this.expression=$e} }
class StmtVar           : Stmt { [Token]$name; [Expr]$initializer; StmtVar([Token]$n,[Expr]$i){$this.name=$n;$this.initializer=$i} }
class StmtBlock         : Stmt { [Stmt[]]$statements; StmtBlock([Stmt[]]$s){$this.statements=$s} }
class StmtIf            : Stmt { [Expr]$condition; [Stmt]$thenBranch; [Stmt]$elseBranch; StmtIf([Expr]$c,[Stmt]$t,[Stmt]$e){$this.condition=$c;$this.thenBranch=$t;$this.elseBranch=$e} }
class StmtWhile         : Stmt { [Expr]$condition; [Stmt]$body; StmtWhile([Expr]$c,[Stmt]$b){$this.condition=$c;$this.body=$b} }
class StmtFor           : Stmt { [Token]$each; [Stmt]$initializer; [Expr]$condition; [Expr]$increment; [Expr]$iterable; [Stmt]$body;
                                StmtFor([Token]$e,[Stmt]$i,[Expr]$c,[Expr]$inc,[Expr]$it,[Stmt]$b){$this.each=$e;$this.initializer=$i;$this.condition=$c;$this.increment=$inc;$this.iterable=$it;$this.body=$b} }
class StmtFunction      : Stmt { [Token]$name; [Token[]]$parameters; [Stmt[]]$body; StmtFunction([Token]$n,[Token[]]$p,[Stmt[]]$b){$this.name=$n;$this.parameters=$p;$this.body=$b} }
class StmtReturn        : Stmt { [Token]$keyword; [Expr]$value; StmtReturn([Token]$k,[Expr]$v){$this.keyword=$k;$this.value=$v} }
class StmtBreak         : Stmt { [Token]$keyword; StmtBreak([Token]$k){$this.keyword=$k} }
class StmtClass         : Stmt { [Token]$name; [Token]$superclass; [StmtFunction[]]$methods; StmtClass([Token]$n,[Token]$s,[StmtFunction[]]$m){$this.name=$n;$this.superclass=$s;$this.methods=$m} }
class StmtTry           : Stmt { [Stmt[]]$tryBlock; [Token]$catchVar; [Stmt[]]$catchBlock; [Stmt[]]$finallyBlock;
                                StmtTry([Stmt[]]$tb,[Token]$cv,[Stmt[]]$cb,[Stmt[]]$fb){$this.tryBlock=$tb;$this.catchVar=$cv;$this.catchBlock=$cb;$this.finallyBlock=$fb} }
class StmtImport        : Stmt { [string]$path; StmtImport([string]$p){$this.path=$p} }
class StmtThrow         : Stmt { [Token]$keyword; [Expr]$value; StmtThrow([Token]$k,[Expr]$v){$this.keyword=$k;$this.value=$v} }

# ----------------------------------------------------------------------------
# 4. PARSER
# ----------------------------------------------------------------------------
class ParseError { [string]$Message; ParseError([string]$m){$this.Message=$m} }

class Parser {
    [System.Collections.Generic.List[Token]] $tokens
    [int] $current = 0

    Parser([System.Collections.Generic.List[Token]]$tokens) { $this.tokens = $tokens }

    [Stmt[]] Parse() {
        $statements = [System.Collections.Generic.List[Stmt]]::new()
        while (-not $this.IsAtEnd()) {
            $statements.Add($this.Declaration())
            $this.ConsumeStatementEnds()
        }
        return $statements.ToArray()
    }

    [void] ConsumeStatementEnds() {
        while ($this.Match("NEWLINE") -or $this.Match("SEMICOLON")) { }
    }

    [Stmt] Declaration() {
        try {
            $this.ConsumeStatementEnds()
            if ($this.IsAtEnd()) { return $null }
            if ($this.Check("RIGHT_BRACE")) { return $null }
            if ($this.Match("KEYWORD_class")) { return $this.ClassDeclaration() }
            if ($this.Match("KEYWORD_fun"))   { return $this.Function("function") }
            if ($this.Match("KEYWORD_def"))   { return $this.Function("function") }
            if ($this.Match("KEYWORD_let"))   { return $this.VarDeclaration() }
            return $this.Statement()
        } catch [ParseError] {
            $this.Synchronize()
            return $null
        }
    }

    [Stmt] ClassDeclaration() {
        $name = $this.Consume("IDENTIFIER", "Expect class name.")
        $superclass = $null
        if ($this.Match("LESS")) {
            $superclass = $this.Consume("IDENTIFIER", "Expect superclass name.")
        }
        $this.Match("COLON")
        $this.ConsumeStatementEnds()
        $this.Consume("LEFT_BRACE", "Expect '{' before class body.")
        $methods = [System.Collections.Generic.List[StmtFunction]]::new()
        while (-not $this.Check("RIGHT_BRACE") -and -not $this.IsAtEnd()) {
            $methods.Add($this.Function("method"))
        }
        $this.Consume("RIGHT_BRACE", "Expect '}' after class body.")
        return [StmtClass]::new([Token]$name, $superclass, $methods.ToArray())
    }

    [Stmt] Function([string]$kind) {
        $name = $this.Consume("IDENTIFIER", "Expect {0} name." -f $kind)
        $this.Consume("LEFT_PAREN", "Expect '(' after {0} name." -f $kind)
        $parameters = [System.Collections.Generic.List[Token]]::new()
        if (-not $this.Check("RIGHT_PAREN")) {
            do {
                if ($parameters.Count -ge 255) { throw [ParseError]::new("Can't have more than 255 parameters.") }
                $parameters.Add($this.Consume("IDENTIFIER", "Expect parameter name."))
            } while ($this.Match("COMMA"))
        }
        $this.Consume("RIGHT_PAREN", "Expect ')' after parameters.")
        $this.Match("COLON")
        $this.ConsumeStatementEnds()
        if ($this.Match("LEFT_BRACE")) {
            $body = $this.Block()
        } else {
            $body = $this.Statement()
        }
        return [StmtFunction]::new([Token]$name, $parameters.ToArray(), $body)
    }

    [Stmt] VarDeclaration() {
        $name = $this.Consume("IDENTIFIER", "Expect variable name.")
        $initializer = $null
        if ($this.Match("EQUAL")) { $initializer = $this.Assignment() }
        return [StmtVar]::new([Token]$name, $initializer)
    }

    [Stmt] Statement() {
        $this.ConsumeStatementEnds()
        if ($this.IsAtEnd()) { return $null }
        if ($this.Match("KEYWORD_for"))    { return $this.ForStatement() }
        if ($this.Match("KEYWORD_if"))     { return $this.IfStatement() }
        if ($this.Match("KEYWORD_while"))  { return $this.WhileStatement() }
        if ($this.Match("KEYWORD_print"))  { return $this.PrintStatement() }
        if ($this.Match("KEYWORD_return")) { return $this.ReturnStatement() }
        if ($this.Match("KEYWORD_break"))  { return $this.BreakStatement() }
        if ($this.Match("KEYWORD_try"))    { return $this.TryStatement() }
        if ($this.Match("KEYWORD_throw"))  { return $this.ThrowStatement() }
        if ($this.Match("KEYWORD_import")) { return $this.ImportStatement() }
        if ($this.Match("LEFT_BRACE")) { 
            return [StmtBlock]::new($this.Block()) 
        }
        return $this.ExpressionStatement()
    }

    [Stmt] ImportStatement() {
        $pathToken = $this.Consume("STRING", "Expect a string path after 'import'.")
        return [StmtImport]::new([string]$pathToken.Literal)
    }

    [Stmt] ThrowStatement() {
        $keyword = $this.Previous()
        $value = $this.Expression()
        return [StmtThrow]::new($keyword, $value)
    }

    [Stmt[]] Block() {
        $statements = [System.Collections.Generic.List[Stmt]]::new()
        while (-not $this.Check("RIGHT_BRACE") -and -not $this.IsAtEnd()) {
            $statements.Add($this.Declaration())
            if ($this.Check("RIGHT_BRACE")) { break }
        }
        $this.Consume("RIGHT_BRACE", "Expect '}' after block.")
        return $statements.ToArray()
    }

    [Stmt] ForStatement() {
        $hasParen = $this.Match("LEFT_PAREN")
        $initializer = $null
        $condition = $null
        $increment = $null
        # for (x in iterable) or for x in iterable
        if ($this.Check("IDENTIFIER") -and $this.PeekNext().Type -eq "KEYWORD_in") {
            $each = $this.Advance()
            $this.Consume("KEYWORD_in", "Expect 'in' after for variable.")
            $iterable = $this.Expression()
            if ($hasParen) { $this.Consume("RIGHT_PAREN", "Expect ')' after for clauses.") }
            $this.Match("COLON")
            $this.ConsumeStatementEnds()
            $body = $this.Statement()
            return [StmtFor]::new($each, $null, $null, $null, $iterable, $body)
        }
        # C-style: for (init; condition; increment)
        if ($hasParen) {
            $initializer = $null
            if ($this.Match("SEMICOLON")) { $initializer = $null }
            elseif ($this.Match("KEYWORD_let")) { $initializer = $this.VarDeclaration() }
            else { $initializer = $this.ExpressionStatement() }
            $condition = $null
            if (-not $this.Check("SEMICOLON")) { $condition = $this.Expression() }
            $this.Consume("SEMICOLON", "Expect ';' after loop condition.")
            $increment = $null
            if (-not $this.Check("RIGHT_PAREN")) { $increment = $this.Expression() }
            $this.Consume("RIGHT_PAREN", "Expect ')' after for clauses.")
        }
        $this.Match("COLON")
        $this.ConsumeStatementEnds()
        $body = $this.Statement()
        return [StmtFor]::new($null, $initializer, $condition, $increment, $null, $body)
    }

    [Stmt] WhileStatement() {
        $hasParen = $this.Match("LEFT_PAREN")
        $condition = $this.Expression()
        if ($hasParen) { $this.Consume("RIGHT_PAREN", "Expect ')' after condition.") }
        $this.Match("COLON")
        $this.ConsumeStatementEnds()
        $body = $this.Statement()
        return [StmtWhile]::new($condition, $body)
    }

    [Stmt] IfStatement() {
        $hasParen = $this.Match("LEFT_PAREN")
        $condition = $this.Expression()
        if ($hasParen) { $this.Consume("RIGHT_PAREN", "Expect ')' after if condition.") }
        $this.Match("COLON")
        $this.ConsumeStatementEnds()
        $thenBranch = $this.Statement()
        $this.ConsumeStatementEnds()
        $elseBranch = $null
        if ($this.Match("KEYWORD_else")) {
            $this.Match("COLON")
            $this.ConsumeStatementEnds()
            $elseBranch = $this.Statement()
        }
        return [StmtIf]::new($condition, $thenBranch, $elseBranch)
    }

    [Stmt] PrintStatement() {
        $this.Consume("COLON", "Expect ':' after 'print'.")
        $value = $this.Expression()
        return [StmtPrint]::new($value)
    }

    [Stmt] ReturnStatement() {
        $keyword = $this.Previous()
        $value = $null
        if (-not $this.Check("NEWLINE") -and -not $this.Check("SEMICOLON") -and -not $this.Check("RIGHT_BRACE") -and -not $this.IsAtEnd()) {
            $value = $this.Expression()
        }
        return [StmtReturn]::new($keyword, $value)
    }

    [Stmt] BreakStatement() {
        $keyword = $this.Previous()
        return [StmtBreak]::new($keyword)
    }

    [Stmt] TryStatement() {
        $this.Consume("LEFT_BRACE", "Expect '{' after 'try'.")
        $tryBlock = $this.Block()
        $catchVar = $null
        $catchBlock = $null
        if ($this.Match("KEYWORD_catch")) {
            if ($this.Match("LEFT_PAREN")) {
                $catchVar = $this.Consume("IDENTIFIER", "Expect catch variable name.")
                $this.Consume("RIGHT_PAREN", "Expect ')' after catch variable.")
            } else {
                $catchVar = $this.Consume("IDENTIFIER", "Expect catch variable name.")
            }
            $this.Match("COLON")
            $this.ConsumeStatementEnds()
            $this.Consume("LEFT_BRACE", "Expect '{' before catch body.")
            $catchBlock = $this.Block()
        }
        $finallyBlock = $null
        if ($this.Match("KEYWORD_finally")) {
            $this.Match("COLON")
            $this.ConsumeStatementEnds()
            $this.Consume("LEFT_BRACE", "Expect '{' before finally body.")
            $finallyBlock = $this.Block()
        }
        return [StmtTry]::new($tryBlock, $catchVar, $catchBlock, $finallyBlock)
    }

    [Stmt] ExpressionStatement() {
        $expr = $this.Expression()
        return [StmtExpression]::new($expr)
    }

    [Expr] Expression() { return $this.Assignment() }

    [Expr] Assignment() {
        $expr = $this.Or()
        if ($this.Match("EQUAL")) {
            $equals = $this.Previous()
            $value = $this.Assignment()
            if ($expr -is [ExprVariable]) { return [ExprAssign]::new($expr.name, $value) }
            if ($expr -is [ExprGet]) { return [ExprSet]::new($expr.object, $expr.name, $expr.isIndex, $expr.index, $value) }
            throw [ParseError]::new("Invalid assignment target.")
        }
        if ($this.Match("QUESTION_QUESTION_EQUAL")) {
            $equals = $this.Previous()
            $right = $this.Assignment()
            $left = [ExprVariable]::new($expr.name)
            $op = $equals
            return [ExprAssign]::new($expr.name, [ExprCoalesce]::new($left, $op, $right))
        }
        return $expr
    }

    [Expr] Or() {
        $expr = $this.And()
        while ($this.Match("KEYWORD_or")) {
            $op = $this.Previous()
            $right = $this.And()
            $expr = [ExprLogical]::new($expr, $op, $right)
        }
        return $expr
    }

    [Expr] And() {
        $expr = $this.Coalesce()
        while ($this.Match("KEYWORD_and")) {
            $op = $this.Previous()
            $right = $this.Coalesce()
            $expr = [ExprLogical]::new($expr, $op, $right)
        }
        return $expr
    }

    [Expr] Coalesce() {
        $expr = $this.Equality()
        while ($this.Match("QUESTION_QUESTION")) {
            $op = $this.Previous()
            $right = $this.Equality()
            $expr = [ExprCoalesce]::new($expr, $op, $right)
        }
        return $expr
    }

    [Expr] Equality() {
        $expr = $this.Comparison()
        while ($this.Match(@("BANG_EQUAL", "EQUAL_EQUAL"))) {
            $op = $this.Previous()
            $right = $this.Comparison()
            $expr = [ExprBinary]::new($expr, $op, $right)
        }
        return $expr
    }

    [Expr] Comparison() {
        $expr = $this.Term()
        while ($this.Match(@("GREATER", "GREATER_EQUAL", "LESS", "LESS_EQUAL"))) {
            $op = $this.Previous()
            $right = $this.Term()
            $expr = [ExprBinary]::new($expr, $op, $right)
        }
        return $expr
    }

    [Expr] Term() {
        $expr = $this.Factor()
        while ($this.Match(@("MINUS", "PLUS"))) {
            $op = $this.Previous()
            $right = $this.Factor()
            $expr = [ExprBinary]::new($expr, $op, $right)
        }
        return $expr
    }

    [Expr] Factor() {
        $expr = $this.Power()
        while ($this.Match(@("STAR", "SLASH", "MODULO"))) {
            $op = $this.Previous()
            $right = $this.Power()
            $expr = [ExprBinary]::new($expr, $op, $right)
        }
        return $expr
    }

    [Expr] Power() {
        $expr = $this.Unary()
        if ($this.Match("EXPONENT")) {
            $op = $this.Previous()
            $right = $this.Power()  # right-associative
            $expr = [ExprBinary]::new($expr, $op, $right)
        }
        return $expr
    }

    [Expr] Unary() {
        if ($this.Match(@("BANG", "MINUS"))) {
            $op = $this.Previous()
            $right = $this.Unary()
            return [ExprUnary]::new($op, $right)
        }
        return $this.Call()
    }

    [Expr] Call() {
        $expr = $this.Primary()
        while ($true) {
            if ($this.Match("LEFT_PAREN")) {
                $expr = $this.FinishCall($expr)
            } elseif ($this.Match("DOT")) {
                $name = $this.Consume("IDENTIFIER", "Expect property name after '.'.")
                $expr = [ExprGet]::new($expr, $name, $false, $null)
            } elseif ($this.Match("LEFT_BRACKET")) {
                $index = $this.Expression()
                $this.Consume("RIGHT_BRACKET", "Expect ']' after index.")
                $expr = [ExprGet]::new($expr, $null, $true, $index)
            } else {
                break
            }
        }
        return $expr
    }

    [Expr] FinishCall([Expr]$callee) {
        $arguments = [System.Collections.Generic.List[Expr]]::new()
        if (-not $this.Check("RIGHT_PAREN")) {
            do {
                if ($arguments.Count -ge 255) { throw [ParseError]::new("Can't have more than 255 arguments.") }
                $arguments.Add($this.Expression())
            } while ($this.Match("COMMA"))
        }
        $paren = $this.Consume("RIGHT_PAREN", "Expect ')' after arguments.")
        return [ExprCall]::new($callee, $paren, $arguments.ToArray())
    }

    [Expr] Primary() {
        if ($this.Match("KEYWORD_FALSE"))   { return [ExprLiteral]::new($false) }
        if ($this.Match("KEYWORD_TRUE"))    { return [ExprLiteral]::new($true)  }
        if ($this.Match("KEYWORD_NIL"))     { return [ExprLiteral]::new($null)  }
        if ($this.Match("KEYWORD_NONE"))    { return [ExprLiteral]::new($null)  }
        if ($this.Match("KEYWORD_THIS"))    { return [ExprVariable]::new($this.Previous()) }
        if ($this.Match(@("NUMBER", "STRING"))) {
            return [ExprLiteral]::new($this.Previous().Literal)
        }
        if ($this.Match("IDENTIFIER")) {
            $name = [string]$this.Previous().Lexeme
            if ($name -eq "True")  { return [ExprLiteral]::new($true) }
            if ($name -eq "False") { return [ExprLiteral]::new($false) }
            if ($name -eq "None")  { return [ExprLiteral]::new($null) }
            return [ExprVariable]::new($this.Previous())
        }
        if ($this.Match("LEFT_PAREN")) {
            $expr = $this.Expression()
            $this.Consume("RIGHT_PAREN", "Expect ')' after expression.")
            return [ExprGrouping]::new($expr)
        }
        if ($this.Match("LEFT_BRACKET")) {
            $elements = [System.Collections.Generic.List[Expr]]::new()
            if (-not $this.Check("RIGHT_BRACKET")) {
                do {
                    $elements.Add($this.Expression())
                } while ($this.Match("COMMA"))
            }
            $this.Consume("RIGHT_BRACKET", "Expect ']' after list elements.")
            return [ExprList]::new($elements.ToArray())
        }
        if ($this.Match("LEFT_BRACE")) {
            $keys = [System.Collections.Generic.List[string]]::new()
            $values = [System.Collections.Generic.List[Expr]]::new()
            if (-not $this.Check("RIGHT_BRACE")) {
                do {
                    $keyToken = $this.Consume("IDENTIFIER", "Expect map key.")
                    $this.Consume("COLON", "Expect ':' after map key.")
                    $keys.Add([string]$keyToken.Lexeme)
                    $values.Add($this.Expression())
                } while ($this.Match("COMMA"))
            }
            $this.Consume("RIGHT_BRACE", "Expect '}' after map entries.")
            return [ExprMap]::new($keys.ToArray(), $values.ToArray())
        }
        throw $this.Error($this.Peek(), "Expect expression.")
    }

    [bool] Match([string[]]$types) {
        foreach ($type in $types) {
            if ($this.Check($type)) { $this.Advance(); return $true }
        }
        return $false
    }

    [Token] Consume([string]$type, [string]$message) {
        if ($this.Check($type)) { return $this.Advance() }
        throw $this.Error($this.Peek(), $message)
    }
    [bool] Check([string]$type) {
        if ($this.IsAtEnd()) { return $false }
        return $this.Peek().Type -eq $type
    }
    [Token] Advance() {
        if (-not $this.IsAtEnd()) { $this.current++ }
        return $this.Previous()
    }
    [bool] IsAtEnd() { return $this.Peek().Type -eq "EOF" }
    [Token] Peek()    { return $this.tokens[$this.current] }
    [Token] PeekNext() {
        if ($this.current + 1 -ge $this.tokens.Count) { return [Token]::new("EOF", $null, $null, 0) }
        return $this.tokens[$this.current + 1]
    }
    [Token] Previous() { return $this.tokens[$this.current - 1] }

    [ParseError] Error([Token]$token, [string]$message) {
        $msg = if ($token.Type -eq "EOF") { " at end {0}" -f $message } else { " at '{0}' {1}" -f $token.Lexeme, $message }
        ReportError $token.Line $msg
        return [ParseError]::new($message)
    }

    [void] Synchronize() {
        $this.Advance() | Out-Null
        while (-not $this.IsAtEnd()) {
            if ($this.Previous().Type -eq "NEWLINE" -or $this.Previous().Type -eq "SEMICOLON") { return }
            switch ($this.Peek().Type) {
                "KEYWORD_class" { return }
                "KEYWORD_def"   { return }
                "KEYWORD_fun"   { return }
                "KEYWORD_let"   { return }
                "KEYWORD_for"   { return }
                "KEYWORD_if"    { return }
                "KEYWORD_while" { return }
                "KEYWORD_print" { return }
                "KEYWORD_return" { return }
            }
            $this.Advance() | Out-Null
        }
    }
}

# ----------------------------------------------------------------------------
# 5. RUNTIME CONTROL FLOW
# ----------------------------------------------------------------------------
class ReturnException : System.Exception {
    [object]$Value
    ReturnException([object]$value) { $this.Value = $value }
}
class BreakException : System.Exception { }

# ----------------------------------------------------------------------------
# 6. ENVIRONMENT
# ----------------------------------------------------------------------------
class Environment {
    [hashtable]$values = @{}
    [Environment]$parent = $null

    Environment() { }
    Environment([Environment]$parent) { $this.parent = $parent }

    [void] Define([string]$name, [object]$value) { $this.values[$name] = $value }
    [object] Get([Token]$name) {
        $lexeme = [string]$name.Lexeme
        if ($this.values.ContainsKey($lexeme)) { return $this.values[$lexeme] }
        if ($this.parent -ne $null) { return $this.parent.Get($name) }
        throw [System.Exception]::new("Undefined variable '{0}'." -f $lexeme)
    }
    [void] Assign([Token]$name, [object]$value) {
        $lexeme = [string]$name.Lexeme
        if ($this.values.ContainsKey($lexeme)) { $this.values[$lexeme] = $value; return }
        if ($this.parent -ne $null) { $this.parent.Assign($name, $value); return }
        $this.values[$lexeme] = $value
    }
}

# ----------------------------------------------------------------------------
# 7. CALLABLES / CLASSES / INSTANCES
# ----------------------------------------------------------------------------
class LumenNativeFunction {
    [scriptblock]$impl
    [int]$arity
    LumenNativeFunction([scriptblock]$impl, [int]$arity) { $this.impl = $impl; $this.arity = $arity }
    [object] Call([Interpreter]$interpreter, [object[]]$arguments) { return &$this.impl (,$arguments) }
    [int] Arity() { return $this.arity }
    [string] ToString() { return "<native fn>" }
}

class LumenFunction {
    [StmtFunction]$declaration
    [Environment]$closure
    LumenFunction([StmtFunction]$declaration, [Environment]$closure) {
        $this.declaration = $declaration
        $this.closure = $closure
    }
    [object] Call([Interpreter]$interpreter, [object[]]$arguments) {
        $env = [Environment]::new($this.closure)
        for ($i = 0; $i -lt $this.declaration.parameters.Count; $i++) {
            $env.Define([string]$this.declaration.parameters[$i].Lexeme, $arguments[$i])
        }
        try {
            $interpreter.ExecuteBlock($this.declaration.body, $env)
        } catch [ReturnException] {
            return $error[0].Exception.Value
        }
        return $null
    }
    [int] Arity() { return $this.declaration.parameters.Count }
    [string] ToString() { return "<fn {0}>" -f $this.declaration.name.Lexeme }
}

class LumenBoundMethod {
    [LumenInstance]$instance
    [LumenFunction]$method
    LumenBoundMethod([LumenInstance]$instance, [LumenFunction]$method) {
        $this.instance = $instance
        $this.method = $method
    }
    [object] Call([Interpreter]$interpreter, [object[]]$arguments) {
        $env = [Environment]::new($this.method.closure)
        $env.Define("this", $this.instance)
        for ($i = 0; $i -lt $this.method.declaration.parameters.Count; $i++) {
            $env.Define([string]$this.method.declaration.parameters[$i].Lexeme, $arguments[$i])
        }
        try {
            $interpreter.ExecuteBlock($this.method.declaration.body, $env)
        } catch [ReturnException] {
            return $error[0].Exception.Value
        }
        return $null
    }
    [int] Arity() { return $this.method.declaration.parameters.Count }
}

class LumenClass {
    [string]$name
    [LumenClass]$superclass
    [hashtable]$methods = @{}
    LumenClass([string]$name, [LumenClass]$superclass, [hashtable]$methods) {
        $this.name = $name
        $this.superclass = $superclass
        $this.methods = $methods
    }
    [object] Call([Interpreter]$interpreter, [object[]]$arguments) {
        $instance = [LumenInstance]::new($this)
        $initializer = $this.FindMethod("init")
        if ($initializer -ne $null) {
            $bound = [LumenBoundMethod]::new($instance, $initializer)
            $bound.Call($interpreter, $arguments) | Out-Null
        }
        return $instance
    }
    [int] Arity() {
        $init = $this.methods["init"]
        if ($init -ne $null) { return $init.Arity() }
        return 0
    }
    [LumenFunction] FindMethod([string]$name) {
        if ($this.methods.ContainsKey($name)) { return $this.methods[$name] }
        if ($this.superclass -ne $null) { return $this.superclass.FindMethod($name) }
        return $null
    }
    [string] ToString() { return "<class {0}>" -f $this.name }
}

class LumenInstance {
    [LumenClass]$klass
    [hashtable]$fields = @{}
    LumenInstance([LumenClass]$klass) { $this.klass = $klass }
    [object] Get([Token]$name) {
        $lexeme = [string]$name.Lexeme
        if ($this.fields.ContainsKey($lexeme)) { return $this.fields[$lexeme] }
        $method = $this.klass.FindMethod($lexeme)
        if ($method -ne $null) { return [LumenBoundMethod]::new($this, $method) }
        throw [System.Exception]::new("Undefined property '{0}'." -f $lexeme)
    }
    [void] Set([Token]$name, [object]$value) {
        $this.fields[[string]$name.Lexeme] = $value
    }
    [string] ToString() { return "<{0} instance>" -f $this.klass.name }
}

# ----------------------------------------------------------------------------
# 8. INTERPRETER
# ----------------------------------------------------------------------------
class Interpreter {
    [Environment]$globals = [Environment]::new()
    [Environment]$environment
    [string]$currentPath = ""

    Interpreter() {
        $this.environment = $this.globals
        $this.DefineNatives()
    }

    [void] DefineNatives() {
        $this.globals.Define("clock", [LumenNativeFunction]::new(
            { param($a) [double](Get-Date).ToUniversalTime().Subtract([datetime]"1970-01-01").TotalSeconds }, 0))
        $this.globals.Define("len", [LumenNativeFunction]::new(
            {
                $v = $args
                while ($v -is [System.Object[]] -and $v.Count -eq 1) { $v = $v[0] }
                if ($v -is [System.Collections.Generic.List[object]]) { return $v.Count }
                if ($v -is [hashtable]) { return $v.Count }
                if ($v -is [string]) { return $v.Length }
                throw [System.Exception]::new("len() expects a list, map, or string.")
            }, 1))
        $this.globals.Define("input", [LumenNativeFunction]::new(
            {
                $v = $args
                while ($v -is [System.Object[]] -and $v.Count -eq 1) { $v = $v[0] }
                $prompt = if ($v.Count -gt 0) { $v[0] } else { "" }
                [string](Read-Host -Prompt $prompt)
            }, 0))
        $this.globals.Define("range", [LumenNativeFunction]::new(
            {
                $v = $args
                while ($v -is [System.Object[]] -and $v.Count -eq 1) { $v = $v[0] }
                if ($v -is [double]) {
                    $n = [int]$v
                    $result = [System.Collections.Generic.List[object]]::new()
                    for ($i = 0; $i -lt $n; $i++) { $result.Add([double]$i) }
                    return $result
                }
                throw [System.Exception]::new("range() expects a number.")
            }, 1))
        $this.globals.Define("abs", [LumenNativeFunction]::new(
            {
                $v = $args
                while ($v -is [System.Object[]] -and $v.Count -eq 1) { $v = $v[0] }
                if ($v -is [double]) { return [math]::Abs([double]$v) }
                throw [System.Exception]::new("abs() expects a number.")
            }, 1))
        $this.globals.Define("max", [LumenNativeFunction]::new(
            {
                $v = $args
                while ($v -is [System.Object[]] -and $v.Count -eq 1) { $v = $v[0] }
                if ($v -is [System.Collections.Generic.List[object]] -or $v -is [System.Object[]]) {
                    $max = [double]$v[0]
                    for ($i = 1; $i -lt $v.Count; $i++) {
                        $x = [double]$v[$i]
                        if ($x -gt $max) { $max = $x }
                    }
                    return $max
                }
                if ($v.Count -ge 2) {
                    $a = [double]$v[0]
                    $b = [double]$v[1]
                    return [math]::Max($a, $b)
                }
                throw [System.Exception]::new("max() expects two numbers or a list.")
            }, 2))
        $this.globals.Define("min", [LumenNativeFunction]::new(
            {
                $v = $args
                while ($v -is [System.Object[]] -and $v.Count -eq 1) { $v = $v[0] }
                if ($v -is [System.Collections.Generic.List[object]] -or $v -is [System.Object[]]) {
                    $min = [double]$v[0]
                    for ($i = 1; $i -lt $v.Count; $i++) {
                        $x = [double]$v[$i]
                        if ($x -lt $min) { $min = $x }
                    }
                    return $min
                }
                if ($v.Count -ge 2) {
                    $a = [double]$v[0]
                    $b = [double]$v[1]
                    return [math]::Min($a, $b)
                }
                throw [System.Exception]::new("min() expects two numbers or a list.")
            }, 2))
        $this.globals.Define("str", [LumenNativeFunction]::new(
            {
                $v = $args
                while ($v -is [System.Object[]] -and $v.Count -eq 1) { $v = $v[0] }
                if ($v -is [string]) { return $v }
                return $v.ToString()
            }, 1))
        $this.globals.Define("int", [LumenNativeFunction]::new(
            {
                $v = $args
                while ($v -is [System.Object[]] -and $v.Count -eq 1) { $v = $v[0] }
                if ($v -is [double]) { return [double]([int]$v) }
                if ($v -is [string]) { return [double]([int]$v) }
                throw [System.Exception]::new("int() expects a number or string.")
            }, 1))
        $this.globals.Define("float", [LumenNativeFunction]::new(
            {
                $v = $args
                while ($v -is [System.Object[]] -and $v.Count -eq 1) { $v = $v[0] }
                if ($v -is [double]) { return $v }
                if ($v -is [string]) { return [double]$v }
                throw [System.Exception]::new("float() expects a number or string.")
            }, 1))
        $this.globals.Define("upper", [LumenNativeFunction]::new(
            {
                $v = $args
                while ($v -is [System.Object[]] -and $v.Count -eq 1) { $v = $v[0] }
                if ($v -is [string]) { return $v.ToUpper() }
                throw [System.Exception]::new("upper() expects a string.")
            }, 1))
        $this.globals.Define("lower", [LumenNativeFunction]::new(
            {
                $v = $args
                while ($v -is [System.Object[]] -and $v.Count -eq 1) { $v = $v[0] }
                if ($v -is [string]) { return $v.ToLower() }
                throw [System.Exception]::new("lower() expects a string.")
            }, 1))
        $this.globals.Define("split", [LumenNativeFunction]::new(
            {
                $v = $args
                while ($v -is [System.Object[]] -and $v.Count -eq 1) { $v = $v[0] }
                if ($v.Count -ne 2) { throw [System.Exception]::new("split() expects two arguments: string and separator.") }
                $s = [string]$v[0]
                $sep = [string]$v[1]
                $parts = $s.Split([string[]]@($sep), [System.StringSplitOptions]::None)
                $result = [System.Collections.Generic.List[object]]::new()
                foreach ($p in $parts) { $result.Add($p) }
                return $result
            }, 2))
        $this.globals.Define("append", [LumenNativeFunction]::new(
            {
                $v = $args
                while ($v -is [System.Object[]] -and $v.Count -eq 1) { $v = $v[0] }
                if ($v.Count -ne 2) { throw [System.Exception]::new("append() expects two arguments: list and item.") }
                $list = $v[0]
                $item = $v[1]
                if (-not ($list -is [System.Collections.Generic.List[object]])) { throw [System.Exception]::new("append() expects a list as first argument.") }
                $list.Add($item)
                return $list
            }, 2))
        $this.globals.Define("pop", [LumenNativeFunction]::new(
            {
                $v = $args
                $count = $v.Count
                while ($v -is [System.Object[]] -and $v.Count -eq 1) { $v = $v[0] }
                if ($count -ne 1) { throw [System.Exception]::new("pop() expects one argument: list.") }
                $list = $v
                if (-not ($list -is [System.Collections.Generic.List[object]])) { throw [System.Exception]::new("pop() expects a list as argument.") }
                if ($list.Count -eq 0) { throw [System.Exception]::new("pop() from empty list.") }
                $item = $list[$list.Count - 1]
                $list.RemoveAt($list.Count - 1)
                return $item
            }, 1))
        $this.globals.Define("sum", [LumenNativeFunction]::new(
            {
                $v = $args
                while ($v -is [System.Object[]] -and $v.Count -eq 1) { $v = $v[0] }
                if ($v -is [System.Collections.Generic.List[object]] -or $v -is [System.Object[]]) {
                    $total = [double]0
                    foreach ($x in $v) { $total = $total + [double]$x }
                    return $total
                }
                throw [System.Exception]::new("sum() expects a list.")
            }, 1))
        $this.globals.Define("read", [LumenNativeFunction]::new(
            {
                $v = $args
                $count = $v.Count
                while ($v -is [System.Object[]] -and $v.Count -eq 1) { $v = $v[0] }
                if ($count -ne 1) { throw [System.Exception]::new("read() expects one argument: file path.") }
                $path = [string]$v
                if (-not (Test-Path $path)) { throw [System.Exception]::new("read() file not found: " + $path) }
                return Get-Content -Path $path -Raw
            }, 1))
        $this.globals.Define("write", [LumenNativeFunction]::new(
            {
                $v = $args
                while ($v -is [System.Object[]] -and $v.Count -eq 1) { $v = $v[0] }
                if ($v.Count -ne 2) { throw [System.Exception]::new("write() expects two arguments: path and content.") }
                $path = [string]$v[0]
                $content = [string]$v[1]
                Set-Content -Path $path -Value $content
                return $null
            }, 2))
    }

    [void] Interpret([Stmt[]]$statements) {
        try {
            foreach ($stmt in $statements) { $this.Execute($stmt) }
        } catch [System.Exception] {
            RuntimeError($error[0].Exception)
        }
    }

    [void] InterpretSource([string]$source) {
        [Lexer]::Init()
        $lexer = [Lexer]::new($source)
        $tokens = $lexer.ScanTokens()
        $parser = [Parser]::new($tokens)
        $statements = $parser.Parse()
        if ($statements -eq $null) { return }
        foreach ($stmt in $statements) { $this.Execute($stmt) }
    }

    [void] ExecuteBlock([Stmt[]]$statements, [Environment]$environment) {
        $previous = $this.environment
        try {
            $this.environment = $environment
            foreach ($stmt in $statements) { $this.Execute($stmt) }
        } finally {
            $this.environment = $previous
        }
    }

    [void] Execute([Stmt]$stmt) {
        if ($stmt -eq $null) { return }
        if ($stmt -is [StmtBlock]) {
            $blockEnv = [Environment]::new($this.environment)
            $this.ExecuteBlock($stmt.statements, $blockEnv)
        } elseif ($stmt -is [StmtExpression]) {
            $this.Evaluate($stmt.expression) | Out-Null
        } elseif ($stmt -is [StmtFunction]) {
            $function = [LumenFunction]::new($stmt, $this.environment)
            $this.environment.Define([string]$stmt.name.Lexeme, $function)
        } elseif ($stmt -is [StmtClass]) {
            $methods = @{}
            foreach ($m in $stmt.methods) { $methods[[string]$m.name.Lexeme] = [LumenFunction]::new($m, $this.environment) }
            $superclass = $null
            if ($stmt.superclass -ne $null) {
                $super = $this.Evaluate([ExprVariable]::new($stmt.superclass))
                if ($super -is [LumenClass]) { $superclass = $super }
                else { throw [System.Exception]::new("Superclass must be a class.") }
            }
            $klass = [LumenClass]::new([string]$stmt.name.Lexeme, $superclass, $methods)
            $this.environment.Define([string]$stmt.name.Lexeme, $klass)
        } elseif ($stmt -is [StmtIf]) {
            if ($this.IsTruthy($this.Evaluate($stmt.condition))) { $this.Execute($stmt.thenBranch) }
            elseif ($stmt.elseBranch -ne $null) { $this.Execute($stmt.elseBranch) }
        } elseif ($stmt -is [StmtPrint]) {
            $value = $this.Evaluate($stmt.expression)
            [Console]::WriteLine($this.StringifyValue($value))
        } elseif ($stmt -is [StmtReturn]) {
            $value = $null
            if ($stmt.value -ne $null) { $value = $this.Evaluate($stmt.value) }
            throw [ReturnException]::new($value)
        } elseif ($stmt -is [StmtVar]) {
            $value = $null
            if ($stmt.initializer -ne $null) { $value = $this.Evaluate($stmt.initializer) }
            $this.environment.Define([string]$stmt.name.Lexeme, $value)
        } elseif ($stmt -is [StmtWhile]) {
            while ($this.IsTruthy($this.Evaluate($stmt.condition))) {
                try { $this.Execute($stmt.body) } catch [BreakException] { break }
            }
        } elseif ($stmt -is [StmtFor]) {
            if ($stmt.each -ne $null) {
                $iter = $this.Evaluate($stmt.iterable)
                if ($iter -is [System.Collections.Generic.List[object]]) {
                    foreach ($item in $iter) {
                        $child = [Environment]::new($this.environment)
                        $child.Define([string]$stmt.each.Lexeme, $item)
                        try { $this.ExecuteBlock(@($stmt.body), $child) } catch [BreakException] { break }
                    }
                } elseif ($iter -is [hashtable]) {
                    foreach ($key in $iter.Keys) {
                        $child = [Environment]::new($this.environment)
                        $child.Define([string]$stmt.each.Lexeme, $key)
                        try { $this.ExecuteBlock(@($stmt.body), $child) } catch [BreakException] { break }
                    }
                } else {
                    throw [System.Exception]::new("Can only iterate over a list or map.")
                }
            } else {
                $statements = [System.Collections.Generic.List[Stmt]]::new()
                if ($stmt.initializer -ne $null) { $statements.Add($stmt.initializer) }
                $whileBody = [System.Collections.Generic.List[Stmt]]::new()
                $whileBody.Add($stmt.body)
                if ($stmt.increment -ne $null) { $whileBody.Add([StmtExpression]::new($stmt.increment)) }
                $whileStmt = [StmtWhile]::new($stmt.condition, [StmtBlock]::new($whileBody.ToArray()))
                $statements.Add($whileStmt)
                $this.ExecuteBlock($statements.ToArray(), $this.environment)
            }
        } elseif ($stmt -is [StmtBreak]) {
            throw [BreakException]::new()
        } elseif ($stmt -is [StmtTry]) {
            try {
                $this.ExecuteBlock($stmt.tryBlock, $this.environment)
            } catch [System.Exception] {
                $ex = $error[0].Exception
                if ($ex -is [ReturnException] -or $ex -is [BreakException]) { throw $ex }
                if ($stmt.catchVar -ne $null -and $stmt.catchBlock -ne $null) {
                    $catchEnv = [Environment]::new($this.environment)
                    $catchEnv.Define([string]$stmt.catchVar.Lexeme, $ex)
                    $prev = $this.environment
                    $this.environment = $catchEnv
                    try { $this.ExecuteBlock($stmt.catchBlock, $catchEnv) } finally { $this.environment = $prev }
                }
            } finally {
                if ($stmt.finallyBlock -ne $null) {
                    $this.ExecuteBlock($stmt.finallyBlock, $this.environment)
                }
            }
        } elseif ($stmt -is [StmtImport]) {
            $importPath = $stmt.path
            if (-not [System.IO.Path]::IsPathRooted($importPath) -and $this.currentPath) {
                $importPath = Join-Path (Split-Path $this.currentPath -Parent) $importPath
            }
            if (-not (Test-Path $importPath)) {
                throw [System.Exception]::new("Cannot import '{0}': file not found." -f $stmt.path)
            }
            $src = Get-Content -Path $importPath -Raw
            $this.InterpretSource($src)
        } elseif ($stmt -is [StmtThrow]) {
            $value = $this.Evaluate($stmt.value)
            throw [System.Exception]::new($this.StringifyValue($value))
        }
    }

    [object] Evaluate([Expr]$expr) {
        if ($expr -is [ExprBinary])        { return $this.EvaluateBinary($expr) }
        if ($expr -is [ExprCall])          { return $this.EvaluateCall($expr) }
        if ($expr -is [ExprCoalesce])      { return $this.EvaluateCoalesce($expr) }
        if ($expr -is [ExprGet])           { return $this.EvaluateGet($expr) }
        if ($expr -is [ExprGrouping])      { return $this.Evaluate($expr.expression) }
        if ($expr -is [ExprLiteral]) {
            $v = $expr.value
            if ($v -is [string] -and $v.Contains("{")) { return $this.Interpolate($this.environment, $v) }
            return $v
        }
        if ($expr -is [ExprList]) {
            $list = [System.Collections.Generic.List[object]]::new()
            foreach ($e in $expr.elements) { $list.Add($this.Evaluate($e)) }
            return $list
        }
        if ($expr -is [ExprLogical])       { return $this.EvaluateLogical($expr) }
        if ($expr -is [ExprMap]) {
            $map = [hashtable]@{}
            for ($i = 0; $i -lt $expr.keys.Count; $i++) {
                $map[$expr.keys[$i]] = $this.Evaluate($expr.values[$i])
            }
            return $map
        }
        if ($expr -is [ExprSet])           { return $this.EvaluateSet($expr) }
        if ($expr -is [ExprUnary])         { return $this.EvaluateUnary($expr) }
        if ($expr -is [ExprVariable])      { return $this.environment.Get($expr.name) }
        if ($expr -is [ExprAssign])        { return $this.EvaluateAssign($expr) }
        throw [System.Exception]::new("Unknown expression type.")
    }

    [string] Interpolate([Environment]$env, [string]$template) {
        if (-not $template.Contains("{")) { return $template }
        return [System.Text.RegularExpressions.Regex]::Replace($template, "\{([A-Za-z_][A-Za-z0-9_]*)\}", {
            param($match)
            $name = $match.Groups[1].Value
            try {
                $val = $env.Get([Token]::new("IDENTIFIER", $name, $null, 0))
                return $this.StringifyValue($val)
            } catch { return $match.Value }
        })
    }

    [object] EvaluateBinary([ExprBinary]$expr) {
        $left  = $this.Evaluate($expr.left)
        $right = $this.Evaluate($expr.right)
        switch ($expr.op.Type) {
            "GREATER"    { if ($left -is [double] -and $right -is [double]) { return [double]$left -gt [double]$right } else { throw [System.Exception]::new("Operands must be numbers.") } }
            "GREATER_EQUAL" { if ($left -is [double] -and $right -is [double]) { return [double]$left -ge [double]$right } else { throw [System.Exception]::new("Operands must be numbers.") } }
            "LESS"       { if ($left -is [double] -and $right -is [double]) { return [double]$left -lt [double]$right } else { throw [System.Exception]::new("Operands must be numbers.") } }
            "LESS_EQUAL" { if ($left -is [double] -and $right -is [double]) { return [double]$left -le [double]$right } else { throw [System.Exception]::new("Operands must be numbers.") } }
            "BANG_EQUAL" { return !($left -eq $right) }
            "EQUAL_EQUAL" { return $left -eq $right }
            "MINUS"      { if ($left -is [double] -and $right -is [double]) { return [double]$left - [double]$right } else { throw [System.Exception]::new("Operands must be numbers.") } }
            "PLUS"       {
                if ($left -is [double] -and $right -is [double]) { return [double]$left + [double]$right }
                if ($left -is [string] -and $right -is [string]) { return [string]$left + [string]$right }
                if ($left -is [System.Collections.Generic.List[object]] -and $right -is [System.Collections.Generic.List[object]]) {
                    $result = [System.Collections.Generic.List[object]]::new()
                    foreach ($x in $left) { $result.Add($x) }
                    foreach ($x in $right) { $result.Add($x) }
                    return $result
                }
                throw [System.Runtime.InteropServices.ComException]::new("Operands must be two numbers, two strings, or two lists.")
            }
            "SLASH"      { if ($left -is [double] -and $right -is [double]) { return [double]$left / [double]$right } else { throw [System.Exception]::new("Operands must be numbers.") } }
            "STAR"       { if ($left -is [double] -and $right -is [double]) { return [double]$left * [double]$right } else { throw [System.Exception]::new("Operands must be numbers.") } }
            "MODULO"     { if ($left -is [double] -and $right -is [double]) { return [double]$left % [double]$right } else { throw [System.Exception]::new("Operands must be numbers.") } }
            "EXPONENT"   { if ($left -is [double] -and $right -is [double]) { return [math]::Pow([double]$left, [double]$right) } else { throw [System.Exception]::new("Operands must be numbers.") } }
        }
        return $null
    }

    [object] EvaluateCall([ExprCall]$expr) {
        $callee = $this.Evaluate($expr.callee)
        $arguments = [System.Collections.Generic.List[object]]::new()
        foreach ($arg in $expr.arguments) { $arguments.Add($this.Evaluate($arg)) }
        if ($callee -is [LumenFunction])       { return $callee.Call($this, $arguments.ToArray()) }
        if ($callee -is [LumenNativeFunction]) { return $callee.Call($this, $arguments.ToArray()) }
        if ($callee -is [LumenClass])          { return $callee.Call($this, $arguments.ToArray()) }
        if ($callee -is [LumenBoundMethod])    { return $callee.Call($this, $arguments.ToArray()) }
        throw [System.Exception]::new("Can only call functions, classes, and methods.")
    }

    [object] EvaluateCoalesce([ExprCoalesce]$expr) {
        $left = $this.Evaluate($expr.left)
        if ($left -eq $null) { return $this.Evaluate($expr.right) }
        return $left
    }

    [object] EvaluateGet([ExprGet]$expr) {
        $obj = $this.Evaluate($expr.object)
        if ($expr.isIndex) {
            $index = $this.Evaluate($expr.index)
            if ($obj -is [System.Collections.Generic.List[object]]) {
                return $obj[[int]$index - 1]
            }
            if ($obj -is [hashtable]) {
                $key = [string]$index
                if ($obj.ContainsKey($key)) { return $obj[$key] }
                throw [System.Exception]::new("Map has no key '{0}'." -f $key)
            }
            throw [System.Exception]::new("Cannot index into that type.")
        } else {
            if ($obj -is [LumenInstance]) { return $obj.Get($expr.name) }
            if ($obj -is [hashtable]) {
                $key = [string]$expr.name.Lexeme
                if ($obj.ContainsKey($key)) { return $obj[$key] }
                throw [System.Exception]::new("Map has no key '{0}'." -f $key)
            }
            throw [System.Exception]::new("Cannot get property on that type.")
        }
    }

    [object] EvaluateSet([ExprSet]$expr) {
        $value = $this.Evaluate($expr.value)
        if ($expr.isIndex) {
            $obj = $this.Evaluate($expr.object)
            $index = $this.Evaluate($expr.index)
            if ($obj -is [System.Collections.Generic.List[object]]) {
                $obj[[int]$index - 1] = $value
            } elseif ($obj -is [hashtable]) {
                $obj[[string]$index] = $value
            } else {
                throw [System.Exception]::new("Cannot index into that type.")
            }
        } else {
            $obj = $this.Evaluate($expr.object)
            if ($obj -is [LumenInstance]) {
                $obj.Set($expr.name, $value)
            } elseif ($obj -is [hashtable]) {
                $obj[[string]$expr.name.Lexeme] = $value
            } else {
                throw [System.Exception]::new("Cannot set property on that type.")
            }
        }
        return $value
    }

    [object] EvaluateLogical([ExprLogical]$expr) {
        $left = $this.Evaluate($expr.left)
        if ($expr.op.Type -eq "KEYWORD_or") {
            if ($this.IsTruthy($left)) { return $left }
        } else {
            if (-not $this.IsTruthy($left)) { return $left }
        }
        return $this.Evaluate($expr.right)
    }

    [object] EvaluateUnary([ExprUnary]$expr) {
        $right = $this.Evaluate($expr.right)
        switch ($expr.op.Type) {
            "BANG"   { return -not $this.IsTruthy($right) }
            "MINUS"  { if ($right -is [double]) { return -[double]$right } else { throw [System.Exception]::new("Operand must be a number.") } }
        }
        return $null
    }

    [object] EvaluateAssign([ExprAssign]$expr) {
        $value = $this.Evaluate($expr.value)
        $this.environment.Assign($expr.name, $value)
        return $value
    }

    [string] StringifyValue([object]$obj) {
        if ($obj -eq $null) { return "nil" }
        if ($obj -is [bool]) { return ([bool]$obj).ToString().ToLower() }
        if ($obj -is [double]) {
            $text = $obj.ToString()
            if ($text.Contains(".") -or $text.Contains("e")) {
                while ($text.EndsWith("0")) { $text = $text.Substring(0, $text.Length - 1) }
                if ($text.EndsWith(".")) { $text = $text.Substring(0, $text.Length - 1) }
            }
            return $text
        }
        if ($obj -is [LumenInstance]) { return $obj.ToString() }
        if ($obj -is [System.Collections.IList]) {
            $parts = @()
            foreach ($x in $obj) { $parts += $this.StringifyValue($x) }
            return "[" + ($parts -join ", ") + "]"
        }
        if ($obj -is [hashtable]) {
            $parts = @()
            foreach ($k in $obj.Keys) {
                $parts += ($k + ": " + $this.StringifyValue($obj[$k]))
            }
            return "{" + ($parts -join ", ") + "}"
        }
        return $obj.ToString()
    }

    [bool] IsTruthy([object]$obj) {
        if ($obj -eq $null) { return $false }
        if ($obj -is [bool]) { return [bool]$obj }
        return $true
    }
}

# ----------------------------------------------------------------------------
# 9. HELPERS
# ----------------------------------------------------------------------------
function ReportError([int]$line, [string]$message) {
    Write-Warning ("[line {0}] Error{1}" -f $line, $message)
}
function RuntimeError([System.Exception]$error) {
    Write-Warning ("[runtime] {0}" -f $error.Message)
}

# ----------------------------------------------------------------------------
# 10. MAIN / REPL / FILE RUNNER
# ----------------------------------------------------------------------------
function RunFile([string]$path) {
    if (-not (Test-Path $path)) {
        Write-Warning ("Could not find file: {0}" -f $path)
        exit 1
    }
    $source = Get-Content -Path $path -Raw
    $interpreter = [Interpreter]::new()
    $interpreter.currentPath = (Resolve-Path $path).Path
    $interpreter.InterpretSource($source)
}

function RunPrompt() {
    Write-Host "Lumen 0.3.0 - friendly, Python-like, powerful. Type 'exit' to quit." -ForegroundColor Cyan
    Write-Host "Note: the REPL reads one line at a time; use .ln files for multi-line blocks." -ForegroundColor DarkGray
    while ($true) {
        Write-Host "> " -NoNewline
        $line = Read-Host
        if ($line -eq $null -or $line -eq "exit") { break }
        try {
            $interpreter = [Interpreter]::new()
            $interpreter.InterpretSource($line)
        } catch {
            Write-Warning ("[runtime] {0}" -f $_.Exception.Message)
        }
    }
}

# ----------------------------------------------------------------------------
# Entry point
# ----------------------------------------------------------------------------
$argsCount = $args.Count
if ($argsCount -gt 1) {
    Write-Warning "Usage: lumen.ps1 [script.ln]"
    exit 1
} elseif ($argsCount -eq 1) {
    RunFile $args[0]
} else {
    RunPrompt
}





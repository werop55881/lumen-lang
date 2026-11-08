# Lumen

Lumen is a small, friendly programming language. It runs on PowerShell, which comes with Windows. You don't need to install anything else.

## What Lumen is good for

1. **Easy to learn** — It feels like Python. No confusing symbols. Short, clear code.
2. **Fast to run** — No separate "compile" step. Just save your file and run it.
3. **Powerful** — You can build classes, handle errors, import other files, and write functions that call themselves.

## How to run a Lumen file

Open PowerShell and type:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File lumen.ps1 examples\hello.ln
```

This runs the file `hello.ln`. You should see:

```
Hello, world!
```

To start the interactive mode (type one line at a time):

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File lumen.ps1
```

Type `exit` to quit.

## Using VS Code

Open the `lumen-lang` folder in VS Code. You get:

- **Colors** in your `.ln` files (keywords, strings, numbers)
- **Run button**: Press `Ctrl+Shift+R` to run the current file
- **Debug**: Press `F5` to step through your code

Your files must end with `.ln` (for example, `myprogram.ln`).

## Writing Lumen code

### Print something

```lumen
print "Hello, world!";
```

### Make a variable

You don't need a special word to start a variable. Just write it:

```lumen
name = "Lumen"
print name
```

You can also use `let` if you want:

```lumen
let age = 5
print age
```

### Use text (strings)

```lumen
print "Hello"
print 'Hello'           # single quotes also work
who = "Lumen"
print "Hello {who}!"    # put a variable inside {}
```

### Use numbers and math

```lumen
print 2 + 3             # 5
print 10 - 4            # 6
print 3 * 7             # 21
print 10 / 2            # 5
```

### Make a list

```lumen
nums = [1, 2, 3]
print nums[0]           # 1
print len(nums)         # 3
```

### Make a map (like a dictionary)

```lumen
person = {name: "Lumen", age: 1}
print person.name       # Lumen
person.age = 2
print person.age        # 2
```

### True, false, and nothing

- `true` / `false` — yes or no
- `nil` / `None` — nothing (empty)

### Make choices with `if`

```lumen
if n > 3 {
    print "big"
} else {
    print "small"
}
```

### Repeat with `while`

```lumen
i = 0
while i < 3 {
    print i
    i = i + 1
}
```

### Loop over a list with `for`

```lumen
for n in [1, 2, 3] {
    print n
}
```

### Make a function

```lumen
def add(a, b) {
    return a + b
}

print add(3, 4)         # 7
```

Short functions can go on one line:

```lumen
def square(x): return x * x
```

### Make a class

```lumen
class Dog {
    init(name) {
        this.name = name
    }
    speak() {
        return this.name + " barks!"
    }
}

d = Dog("Rex")
print d.speak()         # Rex barks!
```

### Handle errors with `try` and `catch`

```lumen
try {
    print 10 / 0
} catch e {
    print "Something went wrong: {e}"
}
```

### Import another file

```lumen
import "math_utils.ln"
print square(5)
```

## Built-in commands

| Command | What it does |
|---------|-------------|
| `print x` | Shows `x` on the screen |
| `len(x)` | Counts items in a list, map, or text |
| `clock` | Gives the current time in seconds |
| `abs(x)` | Absolute value of a number |
| `max(a, b)` | Larger of two numbers (or max of a list) |
| `min(a, b)` | Smaller of two numbers (or min of a list) |
| `str(x)` | Converts to text |
| `int(x)` | Converts to whole number |
| `float(x)` | Converts to decimal number |
| `range(n)` | List from 0 to n-1: `[0, 1, ..., n-1]` |
| `input(prompt)` | Reads text typed by the user |

## Example programs (copy-paste these)

Save any of these as `something.ln` and run with `lumen something.ln`.

### Hello, world!

```lumen
print "Hello, world!";
```

### Math

```lumen
print 40 + 2;
print 3 * (1 + 2);
print 10 / 4;
```

### If / while / for

```lumen
let n = 5;
if (n > 3) {
    print "big";
}

let i = 0;
while (i < 3) {
    print i;
    i = i + 1;
}

for (j in [0, 1, 2]) {
    print j;
}
```

### Functions

```lumen
fun fib(n) {
    if (n <= 1) {
        return n;
    }
    return fib(n - 1) + fib(n - 2);
}

print fib(10);   # 55

fun add(a, b) {
    return a + b;
}
print add(3, 4); # 7
```

### Lists and maps

```lumen
let nums = [1, 2, 3, 4, 5];
print len(nums);    # 5
print nums[0];      # 1

let person = {name: "Lumen", age: 1};
print person.name;  # Lumen
```

### Classes

```lumen
class Dog {
    init(name) {
        this.name = name;
    }
    speak() {
        return this.name + " barks!";
    }
}

let d = Dog("Rex");
print d.speak();    # Rex barks!
```

### Errors

```lumen
try {
    print 10 / 0;
} catch (e) {
    print "caught: {e}";
}
```

## How it works (for curious minds)

Lumen reads your code, understands it, and runs it — all in one step. It is written in PowerShell. It uses:

- A **lexer** that turns text into pieces (tokens)
- A **parser** that checks the pieces make sense
- An **interpreter** that runs the code step by step

If something goes wrong, Lumen tells you which line has the problem.

## Using Lumen on another machine

You can copy Lumen to any Windows machine and run it — no installation needed.

### Option 1: Copy and run (simplest)

1. Copy the `lumen-lang` folder to the other machine (USB, email, cloud drive, etc.)
2. Open PowerShell in that folder
3. Run:
   ```powershell
   pwsh -NoProfile -ExecutionPolicy Bypass -File lumen.ps1 something.ln
   ```

### Option 2: Install to PATH (run `lumen` from anywhere)

1. Copy the `lumen-lang` folder to the other machine (for example, `C:\Tools\lumen-lang`)
2. Open PowerShell as Administrator
3. Run the installer:
   ```powershell
   pwsh -NoProfile -ExecutionPolicy Bypass -File C:\Tools\lumen-lang\install.ps1
   ```
4. Open a **new** PowerShell window
5. Run Lumen from anywhere:
   ```powershell
   lumen something.ln
   ```

### What's in the folder

| File | What it does |
|------|-------------|
| `lumen.ps1` | The Lumen interpreter (required) |
| `lumen.bat` | Windows batch file to run Lumen from cmd |
| `install.ps1` | Adds Lumen to your PATH (run once) |
| `README.md` | This file |

### Requirements

- Windows with PowerShell (comes with Windows 10 and 11)
- No internet connection needed
- No other software to install

## License

Lumen is released under **three licenses** — you may choose any one:

| License | File | Best for |
|---------|------|----------|
| **MIT** | `LICENSE` | Maximum freedom. Permissive, simple, allows commercial use with attribution. |
| **Apache 2.0** | `LICENSE.APACHE-2.0` | Like MIT, plus explicit patent grant. Good for corporate/enterprise use. |
| **GPL-3.0** | `LICENSE.GPL-3.0` | Strong copyleft. Derivative works must also be open source under GPL-3.0. |

**You choose which license applies to your use of Lumen.** You are not bound by all three — just pick the one that fits your needs.

To see the full text of any license, open the corresponding `.LICENSE*` file in this repository.

If you contribute code to Lumen, your contributions will be covered under the same triple-license terms (you retain copyright, but license your contributions under all three licenses).


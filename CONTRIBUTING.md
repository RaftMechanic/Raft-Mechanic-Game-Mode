# Git conventions
This project uses git as its version control and GitHub as the platform for organisational aspects. There are several points to consider if you intend to contribute to the project. When contributing, we use the [GitHub flow](https://docs.github.com/en/get-started/quickstart/github-flow) as our workflow with some minor changes.

- Keep a clean and logically coherent commit history with sensible commit messages. Read [this](https://initialcommit.com/blog/git-commit-messages-best-practices) article for more information
- Use short and descriptive branch names
- Within the Maintainer team, branch names are prefixed with `username/` followed by the branch name. Long or complicated names can be shortened but must be unique

It's strongly recommended to read this chapter of the [Pro Git](https://git-scm.com/book/en/v2/Distributed-Git-Contributing-to-a-Project) book.

---
---
# Coding conventions
## Folder structure
The folder & file structures can be chosen as seen fit, but it is nevertheless important to have a clear and consistent structure. This segment describes the minimum requriements for these structures.

- One file per class
- Namespaces represent the folder structure and in which folder the files reside in
- Files are named after the class they contain
- Class files have the `.lua` file ending

**Example**  
Namespace: `Application.DataAccess.Json`  
Class name: `JsonWriter`  
File name: `JsonWriter.lua`  
File and folder structure: `Scripts/Application/DataAccess/Json/JsonWriter.lua`

```lua
-- Assume Application.DataAccess.Json is an existing table in the global environment
-- Application = {}; Application.DataAccess = {}; Application.DataAccess.Json = {};

-- Exporting class into namespace
local JsonWriter = class()
...
Application.DataAccess.Json.JsonWriter = JsonWriter
```
```lua
-- Importing class from namespace
local JsonWriter = Application.DataAccess.Json.JsonWriter
```
---
## Naming conventions
These naming conventions attempt to improve readability, maintability, and reusability of code. They guarantee to the reader a predictable naming scheme for typical code segments.

- Classes, data types, and public class properties are written in PascalCase
- Local variables and Class members, such as non-public properties and methods are written in camelCase
- All types of identifiers have descriptive names
- Keep the naming as short as possible without losing important information

**Example**
```lua
JsonWriter = class() -- PascalCase for classes and data types
JsonWriter.path = "" -- camelCase
JsonWriter.fileName = "" -- camelCase
JsonWriter.Version = 0 -- PascalCase for public properties

function JsonWriter:writeToDisk() -- camelCase, short and descriptive name
    --[[
        Method body
    ]]
end
```
---
## Layout conventions
- Use four spaces for indentation
- No spaces between parantheses and brackets
- One statement per line
- If applicable, group declarations logically
- Continuation lines are indented by one tab
- One blank line between method definitions
- Utilise parantheses to group expressions logically
- Method definition are written with the colon `:` notation
- Call methods whenever possible with the colon `:` notation
- Always Use parentheses for method calls

**Example**
```lua
JsonReader = class()
JsonReader.fileName = ""
JsonReader.path = ""

function JsonReader:readFile(fileName) -- Colon notation `:` in definition
    ...
end

function JsonReader:parse()
    self:readFile(self.fileName) -- Colon notation `:` when calling a method, `()` are required
end
```
---
## Commenting conventions
Comments help to explain code that is not sufficienty self-explanatory or as a tool to document method signatures, types, etc.
The following conventions help to make comments consistent throughout the whole codebase.

- Add documentation comments to public classes, methods
- Document class properties if necessary
- Write comments on separate lines
- Insert a single space character after the comment delimiter

**Example**
```lua
JsonReader = class()
--- @field IsReady bool Signifies whether the reader is ready to read
JsonReader.IsReady = false

--- Reads the specified file and returns the parsed JSON object
--- @param file string @Fully qualified file path and name
--- @return table @JSON object representing the read file
function JsonReader:readFile(file)
    local someBool = false
    -- Does something
    local someNumber = 0
end
```
---
## Language guidelines
The language guidelines do not have to be followed strictly and their interpretation is a matter of best judgement on a case by case basis. They aim to reduce the mental load for other developers reading and interpreting the code.

- Use string concatenations sparsly
- Use `string.format` whenever possible to simplify concatenations
- Keep table construction simple
- Access object members with the `.` notation. Only access them with the `[]` notation if absolutely necessary
- Do not overuse anonymous functions. Use them in ways that improve maintainability

**Example**
```lua
-- Simple concatenations can make the code more readable
local str = "Number of successful logins: " .. user.loginAmount

-- Longer concatenations decrease the maintainability
local msg2 = "Hello there " .. user.name .. "!\nYou've logged in " .. user.loginAmount .. " times, congratulations!"

-- Use string.format(str[, ...]) instead
local msg1 = ("Hello there %s!\nYou've logged in %i times, congratulations!"):format(user.name, user.loginAmount)
```

```lua
-- Simple array-like table construction
local objA = {
    "String A",
    "String B",
    "String C"
}

-- Associative array construction
local key = {}
local objB = {
    memberA = "A",
    memberB = "B",
    memberC = "C"
    [key] = "Table as a key"
}
```
```lua
-- Numerical array access
print(objA[1], objA[2])

-- Associative array access
print(objB.memberA, objB.memberB, objB[key])
```
```lua
-- Use this type of method/function definition sensibly
local func = function(self, a, b)

end
```
---
## Further resources and examples
- Example of [coding conventions](https://www.mediawiki.org/wiki/Manual:Coding_conventions/Lua)
- Style guide example on [lua-users.org](https://lua-users.org/wiki/LuaStyleGuide)

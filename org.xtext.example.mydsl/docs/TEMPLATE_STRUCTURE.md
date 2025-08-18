# Template Files Structure

## Directory Structure
```
src/resources/templates/
├── cpp/
│   ├── header.template           # Main C++ header file template
│   ├── struct.template          # C++ struct definition
│   ├── enum.template            # C++ enum definition
│   ├── enumerator.template      # C++ enum value
│   ├── typedef.template         # C++ typedef/using statement
│   ├── array.template           # C++ array type definition
│   ├── field.template           # C++ struct field
│   ├── includes.template        # C++ include statements
│   ├── comment.template         # C++ comment block
│   └── types_header.template    # Main Types.h file
├── proto/
│   ├── file.template            # Proto file structure
│   ├── message.template         # Proto message definition
│   ├── enum.template            # Proto enum definition
│   ├── enumerator.template      # Proto enum value
│   └── field.template           # Proto message field
└── cmake/
    └── CMakeLists.template      # CMake configuration file
```

## Template Variables

### C++ Header Template (`cpp/header.template`)
- `{{FILE_NAME}}` - Name of the file
- `{{DESCRIPTION}}` - File description
- `{{TIMESTAMP}}` - Generation timestamp
- `{{GUARD_NAME}}` - Include guard name
- `{{INCLUDES}}` - Include statements
- `{{NAMESPACE_BEGIN}}` - Namespace opening
- `{{NAMESPACE_END}}` - Namespace closing
- `{{FORWARD_DECLARATIONS}}` - Forward declarations
- `{{CONTENT}}` - Main content

### C++ Struct Template (`cpp/struct.template`)
- `{{COMMENT}}` - Documentation comment
- `{{STRUCT_NAME}}` - Name of the struct
- `{{BASE_CLASS}}` - Base class inheritance (e.g., ": public Base")
- `{{FIELDS}}` - Field declarations

### C++ Enum Template (`cpp/enum.template`)
- `{{COMMENT}}` - Documentation comment
- `{{ENUM_NAME}}` - Name of the enum
- `{{BASE_TYPE}}` - Underlying type (e.g., ": int32_t")
- `{{ENUMERATORS}}` - Enum values

### C++ Field Template (`cpp/field.template`)
- `{{FIELD_COMMENT}}` - Field documentation
- `{{FIELD_TYPE}}` - Field type
- `{{ARRAY_DECL}}` - Array declaration (e.g., "[10]")
- `{{FIELD_NAME}}` - Field name
- `{{INITIALIZER}}` - Field initializer

### Proto File Template (`proto/file.template`)
- `{{SOURCE_FILE}}` - Source file name
- `{{TIMESTAMP}}` - Generation timestamp
- `{{PACKAGE}}` - Package declaration
- `{{OPTIONS}}` - Proto options
- `{{IMPORTS}}` - Import statements
- `{{CONTENT}}` - Main content

### Proto Message Template (`proto/message.template`)
- `{{COMMENT}}` - Documentation comment
- `{{MESSAGE_NAME}}` - Message name
- `{{FIELDS}}` - Field definitions

### Proto Field Template (`proto/field.template`)
- `{{FIELD_COMMENT}}` - Field documentation
- `{{REPEATED}}` - "repeated " or empty
- `{{FIELD_TYPE}}` - Field type
- `{{FIELD_NAME}}` - Field name
- `{{FIELD_NUMBER}}` - Field number

### CMake Template (`cmake/CMakeLists.template`)
- `{{PROJECT_NAME}}` - Project name
- `{{VERSION}}` - Project version

## Template Usage Example

The generators use the TemplateLoader to process these templates:

```xtend
// Load and process a template
val variables = new HashMap<String, String>()
variables.put("STRUCT_NAME", "Person")
variables.put("FIELDS", fieldsContent)

val content = templateLoader.processTemplate(
    "/templates/cpp/struct.template", 
    variables
)
```

## Adding New Templates

1. Create a new `.template` file in the appropriate directory
2. Use `{{VARIABLE_NAME}}` syntax for placeholders
3. Update the generator to use the new template:
   ```xtend
   templateLoader.processTemplate("/templates/category/name.template", variables)
   ```

## Template Features

- **Variable Substitution**: `{{VARIABLE_NAME}}`
- **Comments**: Templates can contain any text/comments
- **Nested Templates**: Templates can include content from other templates
- **Conditional Content**: Handle in generator code before processing

## Benefits of Template System

1. **Separation of Concerns**: Logic in generators, formatting in templates
2. **Easy Customization**: Modify templates without changing code
3. **Reusability**: Templates can be reused across different generators
4. **Maintainability**: Changes to output format only require template updates
5. **Clarity**: Templates show exact output structure
# DataType DSL - Template-Based Code Generator

A domain-specific language (DSL) for defining data types and generating C++ headers and Protocol Buffer definitions using a template-based approach.

## Features

- **DataType DSL Syntax**: Based on the original DataType.xtext grammar
- **Template-Based Generation**: Separated templates for easy customization
- **C++ Generation**: Generates clean C++ header files with structs and enums
- **Protobuf Support**: Generates .proto files and binary descriptors
- **Package Organization**: Support for organizing types in packages
- **Type System**: Rich type system with primitives, structs, enums, arrays, and typedefs

## Quick Start

### 1. Setup Templates

**Unix/Linux/Mac:**
```bash
chmod +x setup-templates.sh
./setup-templates.sh
```

**Windows:**
```cmd
setup-templates.bat
```

### 2. Build the Project

**Using Maven:**
```bash
mvn clean compile
```

**Using Gradle:**
```bash
./gradlew build
```

**Using build.sh:**
```bash
./build.sh build
```

### 3. Create a DSL File

Create `example.mydsl`:
```dsl
define BasicTypes {
    type uint32
        category value
        length 32
        encoding LE
    
    type string
        category string
}

package com.example {
    public struct Person {
        type string name
        type uint32 age
        type float32 height
    }
    
    public enumeration Status {
        ACTIVE = 0,
        INACTIVE = 1
    }
}
```

### 4. Generate Code

```bash
java -cp "lib/*:out" org.xtext.example.mydsl.test.DataTypeGeneratorTest example.mydsl
```

Or using build script:
```bash
./build.sh generate example.mydsl
```

### 5. View Generated Files

```
generated/
├── include/
│   ├── Types.h
│   ├── com/
│   │   └── example/
│   │       ├── Person.h
│   │       └── Status.h
├── proto/
│   ├── datatypes.proto
│   ├── com_example.proto
│   └── datatypes.desc
└── CMakeLists.txt
```

## DSL Syntax Reference

### Primitive Type Definitions
```dsl
define TypeSet {
    type typename
        category value|string|fixed-length
        encoding NONE|LE|BE|IEEE754|SIGNED
        length <bits>
        emitter rte|ara|fundamental
}
```

### Structs
```dsl
<** Documentation comment **>
public struct StructName extends BaseStruct {
    type TypeName field_name
    type ArrayType[10] array_field
}
```

### Enumerations
```dsl
public enumeration EnumName {
    VALUE1 = 0,
    VALUE2 = 1,
    VALUE3 = 2
}
```

### Arrays
```dsl
public array ArrayName of ElementType
```

### Type Aliases
```dsl
public typedef AliasName is ActualType { len 32 }
```

### Packages
```dsl
package com.example.types {
    // Types defined here
}
```

## Template System

Templates are located in `src/resources/templates/`:

### C++ Templates
- `cpp/header.template` - Main header file structure
- `cpp/struct.template` - Struct definition
- `cpp/enum.template` - Enum definition
- `cpp/field.template` - Struct field
- `cpp/typedef.template` - Type alias
- `cpp/array.template` - Array type

### Protobuf Templates
- `proto/file.template` - Proto file structure
- `proto/message.template` - Proto message
- `proto/enum.template` - Proto enum
- `proto/field.template` - Message field

### Customizing Templates

Edit any template file to customize the output format:

```cpp
// Edit cpp/struct.template
{{COMMENT}}
class {{STRUCT_NAME}}{{BASE_CLASS}} {  // Changed from struct to class
private:
{{FIELDS}}
public:
    {{STRUCT_NAME}}();
    ~{{STRUCT_NAME}}();
};
```

No recompilation needed - just re-run the generator!

## Project Structure

```
org.xtext.example.mydsl/
├── src/
│   ├── org/xtext/example/mydsl/
│   │   ├── generator/
│   │   │   ├── DataTypeGenerator.xtend
│   │   │   ├── ProtobufGenerator.xtend
│   │   │   ├── TemplateLoader.xtend
│   │   │   └── MyDslGenerator.xtend
│   │   ├── MyDsl.xtext
│   │   └── MyDslRuntimeModule.java
│   └── resources/
│       └── templates/
│           ├── cpp/*.template
│           ├── proto/*.template
│           └── cmake/*.template
├── sample.mydsl
├── setup-templates.sh
├── setup-templates.bat
└── build.sh
```

## Advanced Usage

### Programmatic Generation

```java
// Load model
Resource resource = loadDslFile("input.mydsl");
Model model = (Model) resource.getContents().get(0);

// Setup generators
TemplateLoader loader = new TemplateLoader();
DataTypeGenerator cppGen = new DataTypeGenerator();
ProtobufGenerator protoGen = new ProtobufGenerator();

// Generate
IFileSystemAccess2 fsa = new InMemoryFileSystemAccess();
cppGen.generate(model, fsa);
protoGen.generate(model, fsa, true);
```

### Custom Templates

Create custom template sets:
```bash
cp -r src/resources/templates src/resources/templates-custom
# Edit templates-custom/*
# Update TemplateLoader path in code
```

### Integration with CMake

Generated CMakeLists.txt can be used directly:
```bash
cd generated
mkdir build && cd build
cmake ..
make
```

## Configuration Options

### Generator Options
```java
MyDslGenerator generator = new MyDslGenerator();
generator.setGenerationOptions(
    true,  // Generate C++
    true,  // Generate Protobuf
    true   // Generate binary descriptor
);
```

### Template Loader Options
```java
TemplateLoader loader = new TemplateLoader();
loader.setTemplateBasePath("/custom-templates/");
loader.setCacheEnabled(true);
```

## Troubleshooting

### Templates Not Found
Ensure templates are in classpath:
- Run `setup-templates.sh` or `setup-templates.bat`
- Check `src/resources/templates/` exists
- Verify templates are included in build

### Parse Errors
Check DSL syntax:
- Comments: `<** text **>`
- Enums: Must have value 0 or will get UNSPECIFIED added
- Arrays: Use `type[size]` for fixed arrays

### Generation Errors
Enable debug output:
```bash
java -Dtemplate.loader.debug=true ...
```

## License

[Your License Here]

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes (especially templates!)
4. Test with sample DSL files
5. Submit pull request

## Support

For issues or questions:
- Check TEMPLATE_STRUCTURE.md for template documentation
- Review CHANGES_SUMMARY.md for recent updates
- See sample.mydsl for syntax examples

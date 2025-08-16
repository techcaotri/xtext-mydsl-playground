# MyDsl Standalone Generator

A standalone executable JAR for generating C++ code and Protocol Buffer definitions from MyDsl files.

## Features

- **C++ Code Generation**: Generate complete C++ header and implementation files
- **Protocol Buffer Support**: Generate `.proto` files and binary descriptor sets
- **Command-line Interface**: Easy-to-use CLI with various options
- **Validation**: Built-in model validation with detailed error reporting
- **Flexible Output**: Configurable output directories for different file types

## Building

### Prerequisites

- Java 17 or higher
- Maven 3.6 or higher
- The parent project `org.xtext.example.mydsl` must be built first

### Build Steps

1. Build the parent project:
```bash
cd ../org.xtext.example.mydsl
mvn clean install
```

2. Build the standalone project:
```bash
cd ../org.xtext.example.mydsl.standalone
./build-standalone.sh
```

Or manually with Maven:
```bash
mvn clean package
```

This will create:
- `target/org.xtext.example.mydsl.standalone-1.0.0-SNAPSHOT-jar-with-dependencies.jar`
- A convenience symlink `mydsl-standalone.jar`

## Usage

### Basic Usage

```bash
java -jar mydsl-standalone.jar [options] <input.mydsl>
```

Or use the provided run script:
```bash
./run-mydsl.sh [options] <input.mydsl>
```

### Command-line Options

| Option | Long Option | Description | Default |
|--------|------------|-------------|---------|
| `-h` | `--help` | Show help message | - |
| `-v` | `--version` | Show version information | - |
| `-o` | `--output` | Output directory for C++ code | `generated` |
| `-m` | `--protobuf` | Generate Protobuf files | disabled |
| `-p` | `--proto-output` | Output directory for Protobuf files | `generated/proto` |
| `-b` | `--binary` | Generate binary .desc descriptor set | disabled |
| `-f` | `--force` | Force overwrite existing files | disabled |
| `-s` | `--skip-validation` | Skip model validation | disabled |
| `-n` | `--no-cpp` | Skip C++ generation (proto-only) | disabled |
| `-d` | `--debug` | Enable debug output and summary | disabled |

### Examples

#### Generate C++ Code Only
```bash
./run-mydsl.sh model.mydsl
```

#### Generate Both C++ and Protobuf
```bash
./run-mydsl.sh -m model.mydsl
```

#### Generate Protobuf with Binary Descriptor
```bash
./run-mydsl.sh -m -b model.mydsl
```

#### Custom Output Directories
```bash
./run-mydsl.sh -o src/generated -p proto/generated -m model.mydsl
```

#### Generate Only Protobuf (No C++)
```bash
./run-mydsl.sh -n -m model.mydsl
```

#### Force Overwrite with Debug Output
```bash
./run-mydsl.sh -f -d model.mydsl
```

## Input File Format

The generator accepts `.mydsl` files with the following structure:

```mydsl
model MyModel {
    
    entity Person {
        namespace: "com.example"
        description: "A person entity"
        
        attributes {
            private string name
            private int age = 0
            public string email
        }
        
        methods {
            public string getName() const
            public void setName(string& value)
        }
        
        options {
            copy_semantics: true
            move_semantics: true
            serialization: true
        }
    }
    
    enum Status {
        ACTIVE = 1,
        INACTIVE = 2
    }
}
```

## Generated Output

### C++ Files

The generator creates:
- **Header files** (`*.h`): Class declarations with proper include guards
- **Implementation files** (`*.cpp`): Method implementations
- **Test files** (`*Test.cpp`): Unit test stubs
- **CMakeLists.txt**: CMake build configuration
- **Main file** (`main.cpp`): Application entry point

Directory structure:
```
generated/
├── include/
│   ├── Person.h
│   └── Status.h
├── src/
│   ├── Person.cpp
│   └── main.cpp
├── test/
│   └── PersonTest.cpp
└── CMakeLists.txt
```

### Protobuf Files

When using `-m` option:
- **Proto file** (`*.proto`): Protocol Buffer definitions
- **Descriptor set** (`*.desc`): Binary descriptor (with `-b` option)

Directory structure:
```
generated/proto/
├── mymodel.proto
└── mymodel.desc  (if -b is used)
```

## Integration with Build Systems

### Maven Integration

Add to your `pom.xml`:
```xml
<plugin>
    <groupId>org.codehaus.mojo</groupId>
    <artifactId>exec-maven-plugin</artifactId>
    <version>3.1.0</version>
    <executions>
        <execution>
            <phase>generate-sources</phase>
            <goals>
                <goal>java</goal>
            </goals>
            <configuration>
                <mainClass>org.xtext.example.mydsl.standalone.Main</mainClass>
                <arguments>
                    <argument>-o</argument>
                    <argument>${project.build.directory}/generated-sources</argument>
                    <argument>${project.basedir}/src/main/mydsl/model.mydsl</argument>
                </arguments>
            </configuration>
        </execution>
    </executions>
</plugin>
```

### Gradle Integration

Add to your `build.gradle`:
```gradle
task generateCode(type: JavaExec) {
    main = '-jar'
    args = ['mydsl-standalone.jar', '-o', 'build/generated', 'src/main/mydsl/model.mydsl']
}

compileJava.dependsOn generateCode
```

## Error Handling

The generator provides detailed error messages:

- **Parse Errors**: Line-by-line syntax errors
- **Validation Errors**: Semantic validation issues
- **File I/O Errors**: Permission or path issues

Example error output:
```
[ERROR] Line 15: Entity 'Person' cannot extend undefined type 'Unknown'
[WARNING] Line 23: Attribute 'id' is never used
```

## Logging

The generator uses Log4j2 for logging. Configuration can be modified in `src/main/resources/log4j2.xml`.

Log levels:
- `ERROR`: Critical errors that prevent generation
- `WARN`: Issues that may cause unexpected behavior
- `INFO`: General information about the generation process
- `DEBUG`: Detailed information for troubleshooting

## Troubleshooting

### Common Issues

1. **JAR not found**
   - Ensure the project was built successfully
   - Check that you're in the correct directory

2. **Model validation fails**
   - Check your .mydsl file syntax
   - Use `-s` to skip validation (not recommended)

3. **Files not overwritten**
   - Use `-f` flag to force overwrite
   - Check file permissions

4. **Out of memory for large models**
   - Increase heap size: `java -Xmx2g -jar mydsl-standalone.jar ...`

## License

This project is part of the MyDsl Xtext framework.

## Support

For issues and questions, please refer to the main project documentation.
# Getting Started with DataType DSL

This guide will walk you through setting up and using the DataType DSL generator with templates.

## Prerequisites

- Java 17 or higher
- Maven 3.6+ or Gradle 7+ (optional)
- CMake 3.16+ (optional, for C++ compilation)
- Text editor or IDE (Eclipse, IntelliJ, VS Code)

## Step 1: Download and Setup

### Option A: Clone from Repository
```bash
git clone <repository-url>
cd org.xtext.example.mydsl
```

### Option B: Extract from Archive
```bash
unzip datatype-dsl.zip
cd org.xtext.example.mydsl
```

## Step 2: Initialize Templates

The project uses external template files for code generation. Set them up:

**On Unix/Linux/Mac:**
```bash
chmod +x setup-templates.sh
./setup-templates.sh
```

**On Windows:**
```cmd
setup-templates.bat
```

This creates the template files in `src/resources/templates/`.

## Step 3: Build the Project

### Using Maven
```bash
mvn clean compile
```

### Using Gradle
```bash
./gradlew build
```

### Using Shell Script
```bash
chmod +x build.sh
./build.sh build
```

### Manual Compilation
```bash
# Download dependencies
mkdir lib
curl -L -o lib/protobuf-java-3.21.12.jar \
     https://repo1.maven.org/maven2/com/google/protobuf/protobuf-java/3.21.12/protobuf-java-3.21.12.jar

# Compile (assumes Xtext libraries are available)
javac -cp "lib/*:..." -d out src/**/*.java
```

## Step 4: Create Your First DSL File

Create a file named `my_first.mydsl`:

```dsl
// Define basic types
define MyTypes {
    type int32
        category value
        length 32
        encoding SIGNED
    
    type float64
        category value
        length 64
        encoding IEEE754
    
    type string
        category string
        encoding NONE
}

// Define a simple struct
public struct Point {
    type float64 x
    type float64 y
    type float64 z
}

// Define an enumeration
public enumeration Color {
    RED = 0,
    GREEN = 1,
    BLUE = 2,
    YELLOW = 3
}

// Define a more complex struct
public struct Shape {
    type string name
    type Color color
    type Point center
    type float64 radius
}

// Define an array type
public array PointArray of Point

// Define a type alias
public typedef ShapeId is int32
```

## Step 5: Generate Code

Run the generator on your DSL file:

```bash
java -cp "lib/*:out" org.xtext.example.mydsl.test.DataTypeGeneratorTest my_first.mydsl
```

Or using the build script:
```bash
./build.sh generate my_first.mydsl
```

## Step 6: Explore Generated Files

After generation, you'll find:

```
generated/
├── include/
│   ├── Types.h           # Main header including all types
│   ├── Point.h           # Point struct definition
│   ├── Color.h           # Color enum definition
│   ├── Shape.h           # Shape struct definition
│   ├── PointArray.h      # Array type definition
│   └── ShapeId.h         # Type alias definition
├── proto/
│   ├── datatypes.proto   # Protobuf definitions
│   └── datatypes.desc    # Binary descriptor
└── CMakeLists.txt        # CMake build configuration
```

### Example Generated C++ (Point.h):
```cpp
#ifndef POINT_H
#define POINT_H

#include <cstdint>
#include <string>
#include <vector>
#include <array>
#include <memory>

struct Point {
    double x;
    double y;
    double z;

    // Default constructor
    Point() = default;
    
    // Destructor
    ~Point() = default;
    
    // Copy constructor and assignment
    Point(const Point&) = default;
    Point& operator=(const Point&) = default;
    
    // Move constructor and assignment
    Point(Point&&) = default;
    Point& operator=(Point&&) = default;
};

#endif // POINT_H
```

## Step 7: Use Generated Code in C++

Create a test program `test.cpp`:

```cpp
#include "Types.h"
#include <iostream>

int main() {
    Point p;
    p.x = 1.0;
    p.y = 2.0;
    p.z = 3.0;
    
    Shape shape;
    shape.name = "Circle";
    shape.color = Color::RED;
    shape.center = p;
    shape.radius = 5.0;
    
    std::cout << "Shape: " << shape.name << std::endl;
    std::cout << "Center: (" << shape.center.x << ", " 
              << shape.center.y << ", " 
              << shape.center.z << ")" << std::endl;
    
    return 0;
}
```

Compile and run:
```bash
cd generated
g++ -I include ../test.cpp -o test
./test
```

## Step 8: Customize Templates (Optional)

Want different output format? Edit the templates:

1. Navigate to `src/resources/templates/`
2. Edit the desired template file
3. Re-run the generator

Example: Change struct format in `cpp/struct.template`:
```cpp
{{COMMENT}}
class {{STRUCT_NAME}}{{BASE_CLASS}} {
private:
{{FIELDS}}
public:
    {{STRUCT_NAME}}();
    ~{{STRUCT_NAME}}();
    
    // Add custom methods here
    void print() const;
};
```

## Common Use Cases

### 1. Message Protocol Definition
```dsl
package protocol.messages {
    public struct Header {
        type uint32 version
        type uint32 message_id  
        type uint64 timestamp
        type uint32 payload_size
    }
    
    public struct Request extends Header {
        type string command
        type string[10] parameters
    }
    
    public struct Response extends Header {
        type uint32 status_code
        type string result
    }
}
```

### 2. Configuration Structures
```dsl
public struct Config {
    type string server_address
    type uint16 port
    type uint32 timeout_ms
    type bool enable_logging
    type string log_path
}
```

### 3. Sensor Data
```dsl
public struct SensorData {
    type uint32 sensor_id
    type float32[100] samples  // Array of 100 samples
    type uint64 timestamp
    type float32 average
    type float32 min_value
    type float32 max_value
}
```

## Troubleshooting

### Issue: "Cannot find template files"
**Solution:** Run `setup-templates.sh` or `setup-templates.bat`

### Issue: "Parse error in DSL file"
**Solution:** Check syntax:
- Enums need comma separation
- Arrays use `type[size]` syntax
- Comments use `<** ... **>` syntax

### Issue: "Java class not found"
**Solution:** Ensure all dependencies are in classpath:
```bash
java -cp "lib/*:src:out:src-gen:xtend-gen" ...
```

## Next Steps

1. **Explore Advanced Features**
   - Packages for organization
   - Type inheritance with `extends`
   - Complex type definitions

2. **Integrate with Your Project**
   - Add to build pipeline
   - Version control templates
   - Create custom type libraries

3. **Customize Output**
   - Modify templates for your coding style
   - Add company headers
   - Include custom functionality

4. **Generate Documentation**
   - Use annotation blocks for documentation
   - Generate Doxygen-compatible comments
   - Create API documentation

## Resources

- `sample.mydsl` - Complete example with all features
- `TEMPLATE_STRUCTURE.md` - Template system documentation
- `README.md` - Project overview
- `CHANGES_SUMMARY.md` - What's changed from previous versions

## Getting Help

If you encounter issues:
1. Check the generated logs
2. Verify template files exist
3. Ensure DSL syntax is correct
4. Enable debug mode: `-Dtemplate.loader.debug=true`

Happy code generation!
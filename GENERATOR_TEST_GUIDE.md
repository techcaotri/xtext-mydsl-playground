# MyDslGenerator Test Guide

## Setup

### 1. File Structure
```
HybridGeneratorWorkspace/
├── org.xtext.example.mydsl.parent/
│   ├── org.xtext.example.mydsl/
│   │   ├── src/
│   │   │   └── org/xtext/example/mydsl/
│   │   │       ├── generator/
│   │   │       │   └── MyDslGenerator.xtend
│   │   │       └── test/
│   │   │           └── MyDslGeneratorTest.xtend  <-- Your test class here
│   │   ├── xtend-gen/
│   │   ├── src-gen/
│   │   └── pom.xml
│   └── test.mydsl  <-- Your test DSL file here
└── generated/      <-- Output will go here
```

### 2. Prerequisites
- Java 17+
- Maven 3.6+
- Eclipse with Xtext plugin (for Eclipse UI method)

## Method 1: Eclipse UI

### Step 1: Import and Setup
1. Open Eclipse
2. Import the project: **File** → **Import** → **Existing Maven Projects**
3. Select the `org.xtext.example.mydsl.parent` directory
4. Click **Finish**

### Step 2: Create Test File
1. Right-click on project root
2. **New** → **File** → Name it `test.mydsl`
3. Add your DSL content

### Step 3: Run from Eclipse
1. Open `MyDslGeneratorTest.xtend` in Eclipse
2. Right-click in the editor
3. Select **Run As** → **Run Configurations...**
4. Create new "Java Application" configuration:
   - **Name**: MyDsl Generator Test
   - **Project**: org.xtext.example.mydsl
   - **Main class**: org.xtext.example.mydsl.test.MyDslGeneratorTest
   - **Arguments**: `${workspace_loc}/test.mydsl`
5. Click **Run**

### Step 4: View Output
- Check Console view for output
- Generated files will be in `generated/` folder
- Refresh project (F5) to see generated files in Package Explorer

### Debug Mode
1. Set breakpoints in generator classes
2. Right-click → **Debug As** → **Java Application**
3. Use Debug perspective to step through code

## Method 2: Command Line

### Option A: Using Scripts

#### Linux/Mac:
```bash
# Make script executable
chmod +x run-generator.sh

# Run generator
./run-generator.sh test.mydsl

# Or with custom file
./run-generator.sh path/to/your/model.mydsl
```

#### Windows:
```cmd
# Run generator
run-generator.bat test.mydsl

# Or with custom file
run-generator.bat path\to\your\model.mydsl
```

### Option B: Using Make
```bash
# Run with default test.mydsl
make run

# Run with specific file
make run TEST_FILE=my_model.mydsl

# Clean and run
make clean run

# Run with debug (port 5005)
make debug TEST_FILE=test.mydsl

# View generated files
make view
```

### Option C: Manual Commands
```bash
# Navigate to project
cd org.xtext.example.mydsl

# Compile
mvn clean compile

# Run generator
mvn exec:java \
  -Dexec.mainClass="org.xtext.example.mydsl.test.MyDslGeneratorTest" \
  -Dexec.args="../test.mydsl"
```

### Option D: Direct Java
```bash
# Compile first
cd org.xtext.example.mydsl
mvn compile

# Build classpath
CP="target/classes:xtend-gen:src-gen"
CP="$CP:$(mvn dependency:build-classpath -Dmdep.outputFile=/dev/stdout -q)"

# Run
java -cp "$CP" org.xtext.example.mydsl.test.MyDslGeneratorTest ../test.mydsl
```

## Method 3: Maven with pom.xml Configuration

### Step 1: Add to pom.xml
Add the exec plugin configuration to `org.xtext.example.mydsl/pom.xml`:

```xml
<build>
  <plugins>
    <!-- ... other plugins ... -->
    <plugin>
      <groupId>org.codehaus.mojo</groupId>
      <artifactId>exec-maven-plugin</artifactId>
      <version>3.0.0</version>
      <configuration>
        <mainClass>org.xtext.example.mydsl.test.MyDslGeneratorTest</mainClass>
      </configuration>
    </plugin>
  </plugins>
</build>
```

### Step 2: Run
```bash
cd org.xtext.example.mydsl
mvn compile exec:java -Dexec.args="../test.mydsl"
```

## Debugging

### Eclipse Debug
1. Set breakpoints in:
   - `MyDslGeneratorTest.xtend`
   - `MyDslGenerator.xtend`
   - `HybridGeneratorExample.xtend`
2. Use Debug configuration instead of Run

### Command Line Debug
```bash
# Start with debug port
java -Xdebug -Xrunjdwp:transport=dt_socket,server=y,suspend=y,address=5005 \
  -cp "$CP" org.xtext.example.mydsl.test.MyDslGeneratorTest test.mydsl

# In Eclipse: Run → Debug Configurations → Remote Java Application
# Host: localhost, Port: 5005
```

## Troubleshooting

### Common Issues

1. **"Class not found" error**
   - Solution: Run `mvn clean compile` first
   - Ensure xtend-gen folder has compiled Java files

2. **"File not found" error**
   - Solution: Use absolute path or correct relative path
   - Check working directory with `pwd` (Linux/Mac) or `cd` (Windows)

3. **"No main method" error**
   - Solution: Ensure MyDslGeneratorTest.xtend is compiled
   - Check xtend-gen folder for MyDslGeneratorTest.java

4. **Empty output**
   - Check if model parses correctly
   - Add debug prints in generator
   - Verify output directory permissions

### Verification Commands
```bash
# Check if class is compiled
find . -name "MyDslGeneratorTest.class"

# Check classpath
mvn dependency:tree

# Test with simple input
echo "model Test { entity E { } }" > simple.mydsl
java -cp "$CP" org.xtext.example.mydsl.test.MyDslGeneratorTest simple.mydsl
```

## Output Structure
```
generated/
├── include/
│   ├── Person.h
│   ├── Employee.h
│   └── Status.h
├── src/
│   ├── Person.cpp
│   ├── Employee.cpp
│   └── main.cpp
├── test/
│   ├── PersonTest.cpp
│   └── EmployeeTest.cpp
└── CMakeLists.txt
```

## Tips

1. **Quick Testing**: Use the Makefile for quick iterations
2. **Debugging**: Use Eclipse for complex debugging with breakpoints
3. **Automation**: Use shell scripts for CI/CD integration
4. **Validation**: Always check generated files match expectations

## Example Usage

### Simple Test
```bash
# Create simple test file
cat > simple.mydsl << EOF
model SimpleTest {
    entity User {
        attributes {
            private string username
            private string password
        }
    }
}
EOF

# Run generator
make run TEST_FILE=simple.mydsl

# Check output
ls -la generated/
```

### Complex Test
```bash
# Use the provided test.mydsl
make run TEST_FILE=test.mydsl

# View generated header
cat generated/include/Person.h
```
#!/bin/bash

# Script to run MyDslGeneratorTest from command line

# Configuration
PROJECT_DIR="org.xtext.example.mydsl"
TEST_FILE="${1:-test.mydsl}"
OUTPUT_DIR="generated"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Running MyDsl Generator Test ===${NC}"

# Check if test file exists
if [ ! -f "$TEST_FILE" ]; then
    echo -e "${RED}Error: Test file '$TEST_FILE' not found${NC}"
    echo "Usage: $0 <input.mydsl>"
    exit 1
fi

# Step 1: Compile the project
echo -e "${YELLOW}Step 1: Compiling project...${NC}"
cd $PROJECT_DIR
mvn clean compile -T 12

if [ $? -ne 0 ]; then
    echo -e "${RED}Compilation failed${NC}"
    exit 1
fi

# Step 2: Build classpath
echo -e "${YELLOW}Step 2: Building classpath...${NC}"
CP="target/classes"
CP="$CP:xtend-gen"
CP="$CP:src-gen"

# Add Maven dependencies
MAVEN_CP=$(mvn dependency:build-classpath -Dmdep.outputFile=/dev/stdout -q -T 12)
if [ ! -z "$MAVEN_CP" ]; then
    CP="$CP:$MAVEN_CP"
fi

# Step 3: Create output directory
echo -e "${YELLOW}Step 3: Creating output directory...${NC}"
mkdir -p $OUTPUT_DIR

# Step 4: Run the generator
echo -e "${YELLOW}Step 4: Running generator on $TEST_FILE...${NC}"
java -cp "$CP" org.xtext.example.mydsl.test.MyDslGeneratorTest "../$TEST_FILE"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Generation complete!${NC}"
    echo -e "${GREEN}Generated files are in: $OUTPUT_DIR/${NC}"
    
    # List generated files
    echo -e "${YELLOW}Generated files:${NC}"
    find $OUTPUT_DIR -type f -name "*.h" -o -name "*.cpp" -o -name "*.txt" | while read file; do
        echo "  - $file"
    done
else
    echo -e "${RED}Generation failed${NC}"
    exit 1
fi
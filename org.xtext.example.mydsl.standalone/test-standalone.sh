#!/bin/bash

# Test script for MyDsl Standalone Generator

echo "========================================="
echo "Testing MyDsl Standalone Generator"
echo "========================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if JAR exists
JAR_FILE="mydsl-standalone.jar"
if [ ! -f "$JAR_FILE" ]; then
    JAR_FILE="target/org.xtext.example.mydsl.standalone-1.0.0-SNAPSHOT-jar-with-dependencies.jar"
fi

if [ ! -f "$JAR_FILE" ]; then
    echo -e "${RED}Error: JAR file not found. Please run build-standalone.sh first.${NC}"
    exit 1
fi

# Create test directory
TEST_DIR="test-output"
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"

echo -e "\n${YELLOW}Test 1: Display help${NC}"
java -jar "$JAR_FILE" -h
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Help displayed successfully${NC}"
else
    echo -e "${RED}✗ Failed to display help${NC}"
fi

echo -e "\n${YELLOW}Test 2: Display version${NC}"
java -jar "$JAR_FILE" -v
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Version displayed successfully${NC}"
else
    echo -e "${RED}✗ Failed to display version${NC}"
fi

echo -e "\n${YELLOW}Test 3: Generate C++ code only${NC}"
if [ -f "examples/company.mydsl" ]; then
    java -jar "$JAR_FILE" -o "$TEST_DIR/cpp" examples/company.mydsl
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ C++ generation successful${NC}"
        echo "Generated files:"
        find "$TEST_DIR/cpp" -type f | head -10
    else
        echo -e "${RED}✗ C++ generation failed${NC}"
    fi
else
    echo -e "${YELLOW}Skipping - examples/company.mydsl not found${NC}"
fi

echo -e "\n${YELLOW}Test 4: Generate C++ and Protobuf${NC}"
if [ -f "examples/company.mydsl" ]; then
    java -jar "$JAR_FILE" -o "$TEST_DIR/cpp2" -p "$TEST_DIR/proto" -m examples/company.mydsl
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ C++ and Protobuf generation successful${NC}"
        echo "Proto files:"
        find "$TEST_DIR/proto" -name "*.proto" | head -5
    else
        echo -e "${RED}✗ Generation failed${NC}"
    fi
else
    echo -e "${YELLOW}Skipping - examples/company.mydsl not found${NC}"
fi

echo -e "\n${YELLOW}Test 5: Generate Protobuf with binary descriptor${NC}"
if [ -f "examples/company.mydsl" ]; then
    java -jar "$JAR_FILE" -n -m -b -p "$TEST_DIR/proto-binary" examples/company.mydsl
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Protobuf with descriptor generation successful${NC}"
        if [ -f "$TEST_DIR/proto-binary/companymodel.desc" ]; then
            echo -e "${GREEN}✓ Binary descriptor file created${NC}"
        fi
    else
        echo -e "${RED}✗ Generation failed${NC}"
    fi
else
    echo -e "${YELLOW}Skipping - examples/company.mydsl not found${NC}"
fi

echo -e "\n${YELLOW}Test 6: Test with invalid file${NC}"
java -jar "$JAR_FILE" nonexistent.mydsl 2>/dev/null
if [ $? -ne 0 ]; then
    echo -e "${GREEN}✓ Correctly failed for non-existent file${NC}"
else
    echo -e "${RED}✗ Should have failed for non-existent file${NC}"
fi

echo -e "\n${YELLOW}Test 7: Create simple test file and process${NC}"
cat > "$TEST_DIR/simple.mydsl" << 'EOF'
model SimpleTest {
    entity TestEntity {
        attributes {
            private string name
            private int value = 42
        }
        
        methods {
            public string getName() const
        }
    }
    
    enum TestEnum {
        FIRST = 1,
        SECOND = 2
    }
}
EOF

java -jar "$JAR_FILE" -o "$TEST_DIR/simple-out" -m -d "$TEST_DIR/simple.mydsl"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Simple model processed successfully${NC}"
else
    echo -e "${RED}✗ Failed to process simple model${NC}"
fi

echo -e "\n========================================="
echo -e "${GREEN}Testing completed!${NC}"
echo -e "========================================="
echo ""
echo "Test output directory: $TEST_DIR"
echo "You can examine the generated files there."
echo ""

# Summary
echo "Generated structure:"
tree -L 3 "$TEST_DIR" 2>/dev/null || find "$TEST_DIR" -type f | head -20
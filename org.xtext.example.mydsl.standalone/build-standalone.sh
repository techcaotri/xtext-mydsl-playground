#!/bin/bash

# Build script for MyDsl Standalone Generator

echo "========================================="
echo "Building MyDsl Standalone Generator"
echo "========================================="

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if we're in the right directory
if [ ! -f "pom.xml" ]; then
    echo -e "${RED}Error: pom.xml not found. Please run this script from the org.xtext.example.mydsl.standalone directory${NC}"
    exit 1
fi

# Step 1: Build the parent project first
echo -e "\n${YELLOW}Step 1: Building parent project...${NC}"
cd "$PARENT_DIR/org.xtext.example.mydsl" || exit 1

if mvn clean install -DskipTests -T 12; then
    echo -e "${GREEN}✓ Parent project built successfully${NC}"
else
    echo -e "${RED}✗ Failed to build parent project${NC}"
    exit 1
fi

# Step 2: Build the standalone project
echo -e "\n${YELLOW}Step 2: Building standalone project...${NC}"
cd "$SCRIPT_DIR" || exit 1

if mvn clean package -T 12; then
    echo -e "${GREEN}✓ Standalone project built successfully${NC}"
else
    echo -e "${RED}✗ Failed to build standalone project${NC}"
    exit 1
fi

# Step 3: Verify the JAR was created
JAR_FILE="target/org.xtext.example.mydsl.standalone-1.0.0-SNAPSHOT-jar-with-dependencies.jar"
if [ -f "$JAR_FILE" ]; then
    echo -e "\n${GREEN}✓ Standalone JAR created successfully:${NC}"
    echo "  $JAR_FILE"
    echo "  Size: $(du -h "$JAR_FILE" | cut -f1)"
    
    # Create convenience symlink
    ln -sf "$JAR_FILE" mydsl-standalone.jar
    echo -e "\n${GREEN}✓ Created symlink: mydsl-standalone.jar${NC}"
else
    echo -e "${RED}✗ JAR file not found: $JAR_FILE${NC}"
    exit 1
fi

# Step 4: Create run script
echo -e "\n${YELLOW}Creating run script...${NC}"
cat > run-mydsl.sh << 'EOF'
#!/bin/bash
# Run script for MyDsl Standalone Generator

JAR_FILE="mydsl-standalone.jar"

if [ ! -f "$JAR_FILE" ]; then
    JAR_FILE="target/org.xtext.example.mydsl.standalone-1.0.0-SNAPSHOT-jar-with-dependencies.jar"
fi

if [ ! -f "$JAR_FILE" ]; then
    echo "Error: JAR file not found. Please run build-standalone.sh first."
    exit 1
fi

java -jar "$JAR_FILE" "$@"
EOF

chmod +x run-mydsl.sh
echo -e "${GREEN}✓ Created run script: run-mydsl.sh${NC}"

echo -e "\n========================================="
echo -e "${GREEN}Build completed successfully!${NC}"
echo -e "========================================="
echo ""
echo "To run the generator:"
echo "  ./run-mydsl.sh <input.mydsl>"
echo ""
echo "For help:"
echo "  ./run-mydsl.sh -h"
echo ""
echo "Examples:"
echo "  ./run-mydsl.sh test.mydsl"
echo "  ./run-mydsl.sh -m -o generated -p proto test.mydsl"
echo ""

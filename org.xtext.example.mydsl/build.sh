#!/bin/bash

# DataType DSL Build Script
# Simple build script for DataType DSL without Gradle

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
XTEXT_VERSION="2.39.0"
PROTOBUF_VERSION="3.21.12"
OUTPUT_DIR="out"
GENERATED_DIR="generated"
LIB_DIR="lib"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Function to check if Java is installed
check_java() {
    if ! command -v java &> /dev/null; then
        print_error "Java is not installed. Please install Java 17 or higher."
        exit 1
    fi
    
    JAVA_VERSION=$(java -version 2>&1 | head -n 1 | cut -d'"' -f2 | cut -d'.' -f1)
    if [[ "$JAVA_VERSION" -lt 17 ]]; then
        print_warning "Java 17 or higher is recommended. Current version: $JAVA_VERSION"
    fi
}

# Function to download dependencies
download_dependencies() {
    print_status "Checking dependencies..."
    
    if [ ! -d "$LIB_DIR" ]; then
        mkdir -p "$LIB_DIR"
    fi
    
    # Check if protobuf JAR exists
    if [ ! -f "$LIB_DIR/protobuf-java-${PROTOBUF_VERSION}.jar" ]; then
        print_status "Downloading Protobuf library..."
        curl -L -o "$LIB_DIR/protobuf-java-${PROTOBUF_VERSION}.jar" \
            "https://repo1.maven.org/maven2/com/google/protobuf/protobuf-java/${PROTOBUF_VERSION}/protobuf-java-${PROTOBUF_VERSION}.jar"
    fi
    
    print_status "Dependencies ready."
}

# Function to compile Xtend files
compile_xtend() {
    print_status "Compiling Xtend files..."
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    mkdir -p "xtend-gen"
    
    # Find all .xtend files
    XTEND_FILES=$(find src -name "*.xtend" -type f)
    
    if [ -z "$XTEND_FILES" ]; then
        print_warning "No Xtend files found to compile"
        return
    fi
    
    # For simplicity, we'll compile Xtend to Java manually
    # In a real scenario, you'd use the Xtend compiler
    print_warning "Xtend compilation requires the Xtend compiler. Please use Gradle or Maven for full build."
    print_status "Assuming Xtend files are pre-compiled to xtend-gen/"
}

# Function to compile Java files
compile_java() {
    print_status "Compiling Java files..."
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    # Build classpath
    CLASSPATH="$LIB_DIR/*:src:src-gen:xtend-gen"
    
    # Find all Java files
    JAVA_FILES=$(find src src-gen xtend-gen -name "*.java" -type f 2>/dev/null | tr '\n' ' ')
    
    if [ -z "$JAVA_FILES" ]; then
        print_error "No Java files found to compile"
        exit 1
    fi
    
    # Compile
    javac -cp "$CLASSPATH" -d "$OUTPUT_DIR" $JAVA_FILES
    
    if [ $? -eq 0 ]; then
        print_status "Compilation successful!"
    else
        print_error "Compilation failed!"
        exit 1
    fi
}

# Function to run the generator
run_generator() {
    local DSL_FILE="$1"
    
    if [ -z "$DSL_FILE" ]; then
        DSL_FILE="sample.mydsl"
    fi
    
    if [ ! -f "$DSL_FILE" ]; then
        print_error "DSL file not found: $DSL_FILE"
        exit 1
    fi
    
    print_status "Running generator on: $DSL_FILE"
    
    # Build classpath
    CLASSPATH="$OUTPUT_DIR:$LIB_DIR/*:src:src-gen:xtend-gen"
    
    # Run the generator
    java -cp "$CLASSPATH" org.xtext.example.mydsl.test.DataTypeGeneratorTest "$DSL_FILE"
    
    if [ $? -eq 0 ]; then
        print_status "Generation completed!"
        print_status "Output files are in: $GENERATED_DIR/"
        
        # List generated files
        if [ -d "$GENERATED_DIR" ]; then
            echo ""
            print_status "Generated files:"
            find "$GENERATED_DIR" -type f | head -20
            
            TOTAL_FILES=$(find "$GENERATED_DIR" -type f | wc -l)
            if [ $TOTAL_FILES -gt 20 ]; then
                echo "... and $((TOTAL_FILES - 20)) more files"
            fi
        fi
    else
        print_error "Generation failed!"
        exit 1
    fi
}

# Function to compile generated C++ code
compile_cpp() {
    if [ ! -d "$GENERATED_DIR" ]; then
        print_error "No generated code found. Run the generator first."
        exit 1
    fi
    
    if ! command -v cmake &> /dev/null; then
        print_warning "CMake is not installed. Skipping C++ compilation."
        return
    fi
    
    print_status "Compiling generated C++ code..."
    
    cd "$GENERATED_DIR"
    
    # Create build directory
    mkdir -p build
    cd build
    
    # Run CMake
    cmake ..
    
    if [ $? -eq 0 ]; then
        # Build
        make
        
        if [ $? -eq 0 ]; then
            print_status "C++ compilation successful!"
        else
            print_error "C++ compilation failed!"
        fi
    else
        print_error "CMake configuration failed!"
    fi
    
    cd "$SCRIPT_DIR"
}

# Function to clean build artifacts
clean() {
    print_status "Cleaning build artifacts..."
    
    rm -rf "$OUTPUT_DIR"
    rm -rf "$GENERATED_DIR"
    rm -rf "xtend-gen"
    rm -rf "src-gen"
    
    print_status "Clean completed!"
}

# Function to show usage
show_usage() {
    echo "DataType DSL Build Script"
    echo "========================="
    echo ""
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  build              - Compile the DSL processor"
    echo "  generate <file>    - Generate code from DSL file"
    echo "  compile-cpp        - Compile generated C++ code"
    echo "  clean              - Clean build artifacts"
    echo "  full <file>        - Full pipeline: build, generate, compile-cpp"
    echo "  help               - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 build"
    echo "  $0 generate sample.mydsl"
    echo "  $0 full my_types.mydsl"
    echo ""
}

# Main script logic
main() {
    case "$1" in
        build)
            check_java
            download_dependencies
            compile_xtend
            compile_java
            ;;
        generate)
            check_java
            run_generator "$2"
            ;;
        compile-cpp)
            compile_cpp
            ;;
        clean)
            clean
            ;;
        full)
            check_java
            download_dependencies
            compile_xtend
            compile_java
            run_generator "$2"
            compile_cpp
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            if [ -z "$1" ]; then
                show_usage
            else
                print_error "Unknown command: $1"
                echo ""
                show_usage
                exit 1
            fi
            ;;
    esac
}

# Run main function
main "$@"
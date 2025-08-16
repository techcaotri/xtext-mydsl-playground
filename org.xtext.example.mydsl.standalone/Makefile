# Makefile for MyDsl Standalone Generator

.PHONY: all clean build test run help install

# Variables
VERSION = 1.0.0-SNAPSHOT
JAR_NAME = org.xtext.example.mydsl.standalone-$(VERSION)-jar-with-dependencies.jar
JAR_PATH = target/$(JAR_NAME)
LINK_NAME = mydsl-standalone.jar
PARENT_DIR = ../org.xtext.example.mydsl
EXAMPLE_FILE = examples/company.mydsl

# Default target
all: build

# Help target
help:
	@echo "MyDsl Standalone Generator - Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  make build    - Build the standalone JAR"
	@echo "  make clean    - Clean all generated files"
	@echo "  make test     - Run tests"
	@echo "  make run      - Run with example file"
	@echo "  make install  - Install to local Maven repository"
	@echo "  make help     - Show this help message"
	@echo ""
	@echo "Usage examples:"
	@echo "  make build"
	@echo "  make run ARGS='test.mydsl'"
	@echo "  make run ARGS='-m -o generated examples/company.mydsl'"

# Build the parent project first, then standalone
build:
	@echo "Building parent project..."
	cd $(PARENT_DIR) && mvn clean install -DskipTests
	@echo "Building standalone project..."
	mvn clean package
	@if [ -f $(JAR_PATH) ]; then \
		ln -sf $(JAR_PATH) $(LINK_NAME); \
		echo "Build successful! JAR created at: $(JAR_PATH)"; \
		echo "Symlink created: $(LINK_NAME)"; \
	else \
		echo "Build failed! JAR not found."; \
		exit 1; \
	fi

# Clean target
clean:
	mvn clean
	rm -rf generated/ test-output/ *.log
	rm -f $(LINK_NAME)
	@echo "Clean complete"

# Test target
test: build
	@echo "Running tests..."
	@if [ -f test-standalone.sh ]; then \
		chmod +x test-standalone.sh; \
		./test-standalone.sh; \
	else \
		java -jar $(JAR_PATH) -h; \
		if [ -f $(EXAMPLE_FILE) ]; then \
			java -jar $(JAR_PATH) -d $(EXAMPLE_FILE); \
		fi; \
	fi

# Run target
run: build
	@if [ -z "$(ARGS)" ]; then \
		if [ -f $(EXAMPLE_FILE) ]; then \
			java -jar $(JAR_PATH) $(EXAMPLE_FILE); \
		else \
			echo "Usage: make run ARGS='<arguments>'"; \
			echo "Example: make run ARGS='test.mydsl'"; \
		fi; \
	else \
		java -jar $(JAR_PATH) $(ARGS); \
	fi

# Install to local Maven repository
install: build
	mvn install
	@echo "Installed to local Maven repository"

# Generate only C++ code
cpp: build
	@if [ -f $(EXAMPLE_FILE) ]; then \
		java -jar $(JAR_PATH) -o generated/cpp $(EXAMPLE_FILE); \
	else \
		echo "Example file not found: $(EXAMPLE_FILE)"; \
	fi

# Generate only Protobuf
proto: build
	@if [ -f $(EXAMPLE_FILE) ]; then \
		java -jar $(JAR_PATH) -n -m -b -p generated/proto $(EXAMPLE_FILE); \
	else \
		echo "Example file not found: $(EXAMPLE_FILE)"; \
	fi

# Generate both C++ and Protobuf
both: build
	@if [ -f $(EXAMPLE_FILE) ]; then \
		java -jar $(JAR_PATH) -m -b -o generated/cpp -p generated/proto $(EXAMPLE_FILE); \
	else \
		echo "Example file not found: $(EXAMPLE_FILE)"; \
	fi

# Show version
version:
	@java -jar $(JAR_PATH) -v 2>/dev/null || echo "JAR not built yet. Run 'make build' first."

# Create example directory if it doesn't exist
examples:
	@mkdir -p examples
	@echo "Created examples directory"
	@echo "Add your .mydsl files to the examples/ directory"

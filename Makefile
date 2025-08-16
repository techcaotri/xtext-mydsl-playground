# Makefile for running MyDslGeneratorTest

# Variables
PROJECT_DIR = org.xtext.example.mydsl
TEST_FILE ?= test.mydsl
OUTPUT_DIR = generated
MAIN_CLASS = org.xtext.example.mydsl.test.MyDslGeneratorTest

# Java settings
JAVA = java
JAVAC = javac
MVN = mvn

# Colors
GREEN = \033[0;32m
RED = \033[0;31m
YELLOW = \033[1;33m
NC = \033[0m # No Color

.PHONY: all clean compile run test help

# Default target
all: compile run

# Clean generated files and build artifacts
clean:
	@echo "$(YELLOW)Cleaning build artifacts...$(NC)"
	cd $(PROJECT_DIR) && $(MVN) clean
	rm -rf $(OUTPUT_DIR)
	@echo "$(GREEN)Clean complete$(NC)"

# Compile the project
compile:
	@echo "$(YELLOW)Compiling project...$(NC)"
	cd $(PROJECT_DIR) && $(MVN) compile
	@echo "$(GREEN)Compilation complete$(NC)"

# Run the generator
run: compile
	@echo "$(YELLOW)Running generator on $(TEST_FILE)...$(NC)"
	@if [ ! -f "$(TEST_FILE)" ]; then \
		echo "$(RED)Error: Test file '$(TEST_FILE)' not found$(NC)"; \
		echo "Usage: make run TEST_FILE=your_file.mydsl"; \
		exit 1; \
	fi
	@mkdir -p $(OUTPUT_DIR)
	cd $(PROJECT_DIR) && $(JAVA) -cp "$$($(MVN) dependency:build-classpath -Dmdep.outputFile=/dev/stdout -q):target/classes:xtend-gen:src-gen" \
		$(MAIN_CLASS) ../$(TEST_FILE)
	@echo "$(GREEN)Generation complete!$(NC)"
	@echo "$(GREEN)Generated files:$(NC)"
	@find $(OUTPUT_DIR) -type f \( -name "*.h" -o -name "*.cpp" -o -name "*.txt" \) -exec echo "  - {}" \;

# Run with debug output
debug: compile
	@echo "$(YELLOW)Running generator with debug output...$(NC)"
	cd $(PROJECT_DIR) && $(JAVA) -Xdebug -Xrunjdwp:transport=dt_socket,server=y,suspend=n,address=5005 \
		-cp "$$($(MVN) dependency:build-classpath -Dmdep.outputFile=/dev/stdout -q):target/classes:xtend-gen:src-gen" \
		$(MAIN_CLASS) ../$(TEST_FILE)

# Test with sample file
test:
	@echo "$(YELLOW)Running test with sample DSL file...$(NC)"
	@echo "model TestModel {" > test_sample.mydsl
	@echo "    entity TestEntity {" >> test_sample.mydsl
	@echo "        attributes {" >> test_sample.mydsl
	@echo "            private string name" >> test_sample.mydsl
	@echo "        }" >> test_sample.mydsl
	@echo "    }" >> test_sample.mydsl
	@echo "}" >> test_sample.mydsl
	$(MAKE) run TEST_FILE=test_sample.mydsl
	@rm -f test_sample.mydsl

# View generated files
view:
	@if [ -d "$(OUTPUT_DIR)" ]; then \
		echo "$(YELLOW)Generated files:$(NC)"; \
		find $(OUTPUT_DIR) -type f -exec echo {} \; -exec head -20 {} \; -exec echo "---" \;; \
	else \
		echo "$(RED)No generated files found. Run 'make run' first.$(NC)"; \
	fi

# Help
help:
	@echo "$(GREEN)Available targets:$(NC)"
	@echo "  make all              - Compile and run generator (default)"
	@echo "  make clean            - Clean build artifacts and generated files"
	@echo "  make compile          - Compile the project only"
	@echo "  make run              - Run generator on TEST_FILE (default: test.mydsl)"
	@echo "  make run TEST_FILE=file.mydsl - Run generator on specific file"
	@echo "  make debug            - Run with remote debugging enabled (port 5005)"
	@echo "  make test             - Run with a sample DSL file"
	@echo "  make view             - View generated files"
	@echo "  make help             - Show this help message"
	@echo ""
	@echo "$(YELLOW)Examples:$(NC)"
	@echo "  make run TEST_FILE=my_model.mydsl"
	@echo "  make debug TEST_FILE=complex_model.mydsl"

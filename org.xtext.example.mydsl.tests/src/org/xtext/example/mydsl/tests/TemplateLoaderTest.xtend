package org.xtext.example.mydsl.tests

import org.junit.jupiter.api.Test
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.DisplayName
import org.junit.jupiter.api.Tag
import org.junit.jupiter.api.io.TempDir
import org.xtext.example.mydsl.generator.TemplateLoader
import java.nio.file.Path
import java.nio.file.Files
import java.nio.charset.StandardCharsets
import java.util.HashMap

import static org.junit.jupiter.api.Assertions.*

/**
 * Unit tests for TemplateLoader
 * Tests template loading, caching, and variable replacement functionality
 * 
 * This test class is included in: UnitTestSuite, AllTestsSuite, FastTestsSuite
 */
@DisplayName("TemplateLoader Unit Tests")
class TemplateLoaderTest {
    
    TemplateLoader templateLoader
    
    @TempDir
    Path tempDir
    
    @BeforeEach
    def void setUp() {
        templateLoader = new TemplateLoader()
        // Clear any cached templates
        templateLoader.clearCache()
    }
    
    @AfterEach
    def void tearDown() {
        if (templateLoader !== null) {
            templateLoader.clearCache()
        }
    }
    
    @Test
    @DisplayName("Should load template from filesystem")
    def void testLoadTemplateFromFileSystem() {
        // Create a test template file
        val templatePath = tempDir.resolve("test.template")
        val templateContent = "This is a test template with {{VARIABLE}}"
        Files.write(templatePath, templateContent.getBytes(StandardCharsets.UTF_8))
        
        // Set the base path to temp directory
        templateLoader.setTemplateBasePath(tempDir.toString() + "/")
        
        // Load the template
        val loaded = templateLoader.loadTemplate("test.template")
        
        assertNotNull(loaded, "Template should be loaded")
        assertEquals(templateContent, loaded, "Template content should match")
    }
    
    @Test
    @DisplayName("Should cache templates when caching is enabled")
    def void testTemplateCaching() {
        // Create a test template
        val templatePath = tempDir.resolve("cached.template")
        val initialContent = "Initial content"
        Files.write(templatePath, initialContent.getBytes(StandardCharsets.UTF_8))
        
        templateLoader.setTemplateBasePath(tempDir.toString() + "/")
        templateLoader.setCacheEnabled(true)
        
        // First load
        val firstLoad = templateLoader.loadTemplate("cached.template")
        assertEquals(initialContent, firstLoad)
        
        // Modify the file
        val modifiedContent = "Modified content"
        Files.write(templatePath, modifiedContent.getBytes(StandardCharsets.UTF_8))
        
        // Second load should return cached content
        val secondLoad = templateLoader.loadTemplate("cached.template")
        assertEquals(initialContent, secondLoad, "Should return cached content")
        
        // Clear cache and load again
        templateLoader.clearCache()
        val thirdLoad = templateLoader.loadTemplate("cached.template")
        assertEquals(modifiedContent, thirdLoad, "Should load fresh content after cache clear")
    }
    
    @Test
    @DisplayName("Should not cache when caching is disabled")
    def void testNoCachingWhenDisabled() {
        val templatePath = tempDir.resolve("nocache.template")
        val initialContent = "Initial"
        Files.write(templatePath, initialContent.getBytes(StandardCharsets.UTF_8))
        
        templateLoader.setTemplateBasePath(tempDir.toString() + "/")
        templateLoader.setCacheEnabled(false)
        
        // First load
        val firstLoad = templateLoader.loadTemplate("nocache.template")
        assertEquals(initialContent, firstLoad)
        
        // Modify the file
        val modifiedContent = "Modified"
        Files.write(templatePath, modifiedContent.getBytes(StandardCharsets.UTF_8))
        
        // Second load should return new content
        val secondLoad = templateLoader.loadTemplate("nocache.template")
        assertEquals(modifiedContent, secondLoad, "Should load fresh content when cache disabled")
    }
    
    @Test
    @DisplayName("Should process template with variable replacement")
    def void testProcessTemplate() {
        // Create template with variables
        val templatePath = tempDir.resolve("variables.template")
        val templateContent = '''
            Hello {{NAME}}!
            Your age is {{AGE}}.
            {{GREETING}}
        '''
        Files.write(templatePath, templateContent.getBytes(StandardCharsets.UTF_8))
        
        templateLoader.setTemplateBasePath(tempDir.toString() + "/")
        
        // Create variables map
        val variables = new HashMap<String, String>()
        variables.put("NAME", "John")
        variables.put("AGE", "25")
        variables.put("GREETING", "Welcome!")
        
        // Process template
        val processed = templateLoader.processTemplate("variables.template", variables)
        
        assertNotNull(processed)
        assertTrue(processed.contains("Hello John!"))
        assertTrue(processed.contains("Your age is 25."))
        assertTrue(processed.contains("Welcome!"))
        assertFalse(processed.contains("{{"))
    }
    
    @Test
    @DisplayName("Should handle null values in variable map")
    def void testProcessTemplateWithNullValues() {
        val templatePath = tempDir.resolve("nulltest.template")
        val templateContent = "Name: {{NAME}}, Value: {{VALUE}}"
        Files.write(templatePath, templateContent.getBytes(StandardCharsets.UTF_8))
        
        templateLoader.setTemplateBasePath(tempDir.toString() + "/")
        
        val variables = new HashMap<String, String>()
        variables.put("NAME", "Test")
        variables.put("VALUE", null)
        
        val processed = templateLoader.processTemplate("nulltest.template", variables)
        
        assertEquals("Name: Test, Value: ", processed, "Null values should be replaced with empty string")
    }
    
    @Test
    @DisplayName("Should return empty string for non-existent template")
    def void testNonExistentTemplate() {
        templateLoader.setTemplateBasePath(tempDir.toString() + "/")
        
        val result = templateLoader.loadTemplate("nonexistent.template")
        
        assertNotNull(result)
        assertEquals("", result, "Should return empty string for missing template")
    }
    
    @Test
    @DisplayName("Should check if template exists")
    def void testTemplateExists() {
        val existingPath = tempDir.resolve("existing.template")
        Files.write(existingPath, "content".getBytes(StandardCharsets.UTF_8))
        
        templateLoader.setTemplateBasePath(tempDir.toString() + "/")
        
        assertTrue(templateLoader.templateExists("existing.template"))
        assertFalse(templateLoader.templateExists("nonexistent.template"))
    }
    
    @Test
    @DisplayName("Should handle leading slash in template path")
    def void testLeadingSlashHandling() {
        val templatePath = tempDir.resolve("test.template")
        val content = "Test content"
        Files.write(templatePath, content.getBytes(StandardCharsets.UTF_8))
        
        templateLoader.setTemplateBasePath(tempDir.toString() + "/")
        
        val variables = new HashMap<String, String>()
        
        // Test with leading slash
        val result1 = templateLoader.processTemplate("/test.template", variables)
        assertEquals(content, result1)
        
        // Test without leading slash
        val result2 = templateLoader.processTemplate("test.template", variables)
        assertEquals(content, result2)
    }
    
    @Test
    @DisplayName("Should handle nested directory templates")
    def void testNestedDirectoryTemplates() {
        // Create nested directory structure
        val nestedDir = tempDir.resolve("cpp")
        Files.createDirectories(nestedDir)
        
        val templatePath = nestedDir.resolve("header.template")
        val content = "Header: {{GUARD_NAME}}"
        Files.write(templatePath, content.getBytes(StandardCharsets.UTF_8))
        
        templateLoader.setTemplateBasePath(tempDir.toString() + "/")
        
        val variables = new HashMap<String, String>()
        variables.put("GUARD_NAME", "TEST_H")
        
        val result = templateLoader.processTemplate("cpp/header.template", variables)
        assertEquals("Header: TEST_H", result)
    }
    
    @Test
    @DisplayName("Should handle empty template")
    def void testEmptyTemplate() {
        val templatePath = tempDir.resolve("empty.template")
        Files.write(templatePath, "".getBytes(StandardCharsets.UTF_8))
        
        templateLoader.setTemplateBasePath(tempDir.toString() + "/")
        
        val loaded = templateLoader.loadTemplate("empty.template")
        assertEquals("", loaded)
        
        val processed = templateLoader.processTemplate("empty.template", new HashMap())
        assertEquals("", processed)
    }
    
    @Test
    @DisplayName("Should handle template with no variables")
    def void testTemplateWithNoVariables() {
        val templatePath = tempDir.resolve("static.template")
        val content = "This is static content with no variables"
        Files.write(templatePath, content.getBytes(StandardCharsets.UTF_8))
        
        templateLoader.setTemplateBasePath(tempDir.toString() + "/")
        
        val processed = templateLoader.processTemplate("static.template", new HashMap())
        assertEquals(content, processed)
    }
    
    @Test
    @DisplayName("Should handle multiple occurrences of same variable")
    def void testMultipleVariableOccurrences() {
        val templatePath = tempDir.resolve("multi.template")
        val content = "{{NAME}} is {{NAME}} and {{NAME}} again"
        Files.write(templatePath, content.getBytes(StandardCharsets.UTF_8))
        
        templateLoader.setTemplateBasePath(tempDir.toString() + "/")
        
        val variables = new HashMap<String, String>()
        variables.put("NAME", "Alice")
        
        val processed = templateLoader.processTemplate("multi.template", variables)
        assertEquals("Alice is Alice and Alice again", processed)
    }
    
    @Test
    @DisplayName("Should preserve template structure")
    def void testPreserveTemplateStructure() {
        val templatePath = tempDir.resolve("structured.template")
        val content = '''
            #ifndef {{GUARD}}
            #define {{GUARD}}
            
            class {{CLASS_NAME}} {
            public:
                {{CLASS_NAME}}();
                ~{{CLASS_NAME}}();
            };
            
            #endif // {{GUARD}}
        '''
        Files.write(templatePath, content.getBytes(StandardCharsets.UTF_8))
        
        templateLoader.setTemplateBasePath(tempDir.toString() + "/")
        
        val variables = new HashMap<String, String>()
        variables.put("GUARD", "MY_CLASS_H")
        variables.put("CLASS_NAME", "MyClass")
        
        val processed = templateLoader.processTemplate("structured.template", variables)
        
        assertTrue(processed.contains("#ifndef MY_CLASS_H"))
        assertTrue(processed.contains("class MyClass"))
        assertTrue(processed.contains("MyClass();"))
        assertTrue(processed.contains("~MyClass();"))
        assertTrue(processed.contains("#endif // MY_CLASS_H"))
    }
}

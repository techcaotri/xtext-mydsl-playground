package org.xtext.example.mydsl.generator

import com.github.jknack.handlebars.Handlebars
import com.github.jknack.handlebars.Template
import com.github.jknack.handlebars.io.ClassPathTemplateLoader
import com.github.jknack.handlebars.io.FileTemplateLoader
import com.github.jknack.handlebars.io.CompositeTemplateLoader
import com.github.jknack.handlebars.cache.ConcurrentMapTemplateCache
import com.google.inject.Singleton
import java.util.Map
import java.io.File
import java.util.concurrent.ConcurrentHashMap
import com.github.jknack.handlebars.Helper
import com.github.jknack.handlebars.Options
import java.util.HashMap
import java.nio.charset.StandardCharsets
import java.nio.charset.Charset

/**
 * Handlebars-based template loader for DataType DSL Generator
 * 
 * @author DataType DSL Generator Framework
 */
@Singleton
class HandlebarsTemplateLoader {
    
    // Handlebars engine instance
    var Handlebars handlebars
    
    // Template cache
    val compiledTemplates = new ConcurrentHashMap<String, Template>()
    
    // Partial templates cache
    val partialTemplates = new ConcurrentHashMap<String, String>()
    
    // Configuration
    var boolean cacheEnabled = true
    var String templateBasePath = "templates/"
    
    /**
     * Initialize Handlebars engine
     */
    new() {
        initializeHandlebars()
    }
    
    /**
     * Initialize Handlebars with composite template loader
     */
    def private void initializeHandlebars() {
        // Create template loaders
        val classPathLoader = new ClassPathTemplateLoader()
        classPathLoader.prefix = "/resources/" + templateBasePath
        classPathLoader.suffix = ""
        
        // Alternative classpath loader without /resources prefix
        val altClassPathLoader = new ClassPathTemplateLoader()
        altClassPathLoader.prefix = "/" + templateBasePath
        altClassPathLoader.suffix = ""
        
        // File system loader for development
        val fileLoader = new FileTemplateLoader("src/resources/" + templateBasePath)
        fileLoader.suffix = ""
        
        // Composite loader tries multiple sources
        val compositeLoader = new CompositeTemplateLoader(
            classPathLoader,
            altClassPathLoader, 
            fileLoader
        )
        
        // Create Handlebars instance
        handlebars = new Handlebars(compositeLoader)
        
        // Enable caching
        if (cacheEnabled) {
            handlebars.with(new ConcurrentMapTemplateCache())
        }
        
        // Register custom helpers
        registerHelpers()
    }
    
    /**
     * Register custom Handlebars helpers for code generation
     */
    def private void registerHelpers() {
        // Helper to convert to uppercase
        handlebars.registerHelper("uppercase", new Helper<String>() {
            override CharSequence apply(String value, Options options) {
                return value?.toUpperCase ?: ""
            }
        })
        
        // Helper to convert to lowercase
        handlebars.registerHelper("lowercase", new Helper<String>() {
            override CharSequence apply(String value, Options options) {
                return value?.toLowerCase ?: ""
            }
        })
        
        // Helper for conditional rendering
        handlebars.registerHelper("if_not_empty", new Helper<Object>() {
            override CharSequence apply(Object value, Options options) {
                if (value !== null) {
                    val str = value.toString
                    if (!str.empty) {
                        return options.fn()
                    }
                }
                return options.inverse()
            }
        })
        
        // Helper to check if a collection has items
        handlebars.registerHelper("has_items", new Helper<Object>() {
            override CharSequence apply(Object value, Options options) {
                if (value instanceof Iterable<?>) {
                    val iter = value as Iterable<?>
                    if (!iter.empty) {
                        return options.fn()
                    }
                }
                return options.inverse()
            }
        })
        
        // Helper for safe string concatenation
        handlebars.registerHelper("concat", new Helper<String>() {
            override CharSequence apply(String value, Options options) {
                val result = new StringBuilder()
                if (value !== null) {
                    result.append(value)
                }
                for (param : options.params) {
                    if (param !== null) {
                        result.append(param.toString)
                    }
                }
                return result.toString
            }
        })
        
        // Helper to indent text
        handlebars.registerHelper("indent", new Helper<String>() {
            override CharSequence apply(String text, Options options) {
                if (text === null || text.empty) {
                    return ""
                }
                val indent = if (options.params.length > 0) {
                    options.param(0).toString
                } else {
                    "    "
                }
                val lines = text.split("\n")
                val result = new StringBuilder()
                for (var i = 0; i < lines.length; i++) {
                    result.append(indent).append(lines.get(i))
                    if (i < lines.length - 1) {
                        result.append("\n")
                    }
                }
                return result.toString
            }
        })
        
        // Helper to include partials dynamically
        handlebars.registerHelper("include_partial", new Helper<String>() {
            override CharSequence apply(String partialName, Options options) {
                val partialContent = partialTemplates.get(partialName)
                if (partialContent !== null) {
                    try {
                        val template = handlebars.compileInline(partialContent)
                        return template.apply(options.context)
                    } catch (Exception e) {
                        System.err.println("Error applying partial " + partialName + ": " + e.message)
                    }
                }
                return ""
            }
        })
    }
    
    /**
     * Enable or disable template caching
     */
    def void setCacheEnabled(boolean enabled) {
        this.cacheEnabled = enabled
        if (!enabled) {
            compiledTemplates.clear()
        }
        // Reinitialize Handlebars with new cache settings
        initializeHandlebars()
    }
    
    /**
     * Set base path for templates
     */
    def void setTemplateBasePath(String basePath) {
        this.templateBasePath = basePath
        compiledTemplates.clear()
        initializeHandlebars()
    }
    
    /**
     * Process template with variable replacements
     */
def String processTemplate(String templatePath, Map<String, String> variables) {
    // Remove leading slash if present to avoid double slashes
    val cleanPath = if (templatePath.startsWith("/")) {
        templatePath.substring(1)
    } else {
        templatePath
    }
    
    var template = loadTemplate(cleanPath)
    
    if (template.empty) {
        return ""
    }
    
    // Debug: Check if template or variables contain HTML entities
    if (template.contains("&amp;") || template.contains("&#x")) {
        System.err.println("WARNING: Template contains HTML entities before processing!")
    }
    
    // Replace variables in format {{VARIABLE_NAME}}
    for (entry : variables.entrySet) {
        val placeholder = "{{" + entry.key + "}}"
        val value = entry.value ?: ""
        
        // Debug problematic replacements
        if (value.contains("&amp;") || value.contains("&#x")) {
            System.err.println("WARNING: Variable " + entry.key + " contains HTML entities: " + value)
        }
        
        template = template.replace(placeholder, value)
    }
    
    // Final check
    if (template.contains("&amp;") || template.contains("&#x")) {
        System.err.println("WARNING: Final template contains HTML entities after processing!")
        // Try to decode HTML entities
        template = template.replace("&amp;", "&")
        template = template.replace("&#x3D;", "=")
        template = template.replace("&lt;", "<")
        template = template.replace("&gt;", ">")
        template = template.replace("&quot;", "\"")
    }
    
    return template
}
    
    /**
     * Get compiled template (with caching if enabled)
     */
    def private Template getCompiledTemplate(String templatePath) {
        if (cacheEnabled) {
            var template = compiledTemplates.get(templatePath)
            if (template !== null) {
                return template
            }
        }
        
        try {
            val template = handlebars.compile(templatePath)
            if (cacheEnabled && template !== null) {
                compiledTemplates.put(templatePath, template)
            }
            return template
        } catch (Exception e) {
            // Try with .template extension as fallback
            try {
                val template = handlebars.compile(templatePath + ".template")
                if (cacheEnabled && template !== null) {
                    compiledTemplates.put(templatePath, template)
                }
                return template
            } catch (Exception e2) {
                System.err.println("Failed to compile template: " + templatePath)
                return null
            }
        }
    }
    
    /**
     * Load a template and return its source (for debugging)
     */
    def String loadTemplate(String templatePath) {
        try {
            // Clean path
            val cleanPath = if (templatePath.startsWith("/")) {
                templatePath.substring(1)
            } else {
                templatePath
            }
            
            // Try to load the template source directly
            val loader = handlebars.loader
            val source = loader.sourceAt(cleanPath)
            if (source !== null) {
                // Use StandardCharsets.UTF_8 as the charset parameter
                return source.content(StandardCharsets.UTF_8)
            }
            
            // Try with .template extension
            val sourceWithExt = loader.sourceAt(cleanPath + ".template")
            if (sourceWithExt !== null) {
                return sourceWithExt.content(StandardCharsets.UTF_8)
            }
        } catch (Exception e) {
            System.err.println("Failed to load template: " + templatePath)
        }
        return ""
    }
    
    /**
     * Check if a template exists
     */
    def boolean templateExists(String templatePath) {
        try {
            val cleanPath = if (templatePath.startsWith("/")) {
                templatePath.substring(1)
            } else {
                templatePath
            }
            
            val loader = handlebars.loader
            
            // Check without extension
            val source = loader.sourceAt(cleanPath)
            if (source !== null) {
                return true
            }
            
            // Check with .template extension
            val sourceWithExt = loader.sourceAt(cleanPath + ".template")
            return sourceWithExt !== null
            
        } catch (Exception e) {
            return false
        }
    }
    
    /**
     * Clear template cache
     */
    def void clearCache() {
        compiledTemplates.clear()
        partialTemplates.clear()
        // Handlebars internal cache is also cleared by reinitializing
        if (cacheEnabled) {
            initializeHandlebars()
        }
    }
    
    /**
     * Register a partial template
     */
    def void registerPartial(String name, String content) {
        try {
            // Store in our partial cache
            partialTemplates.put(name, content)
            
            // Also register as a helper for direct use
            handlebars.registerHelper(name, new Helper<Object>() {
                override CharSequence apply(Object context, Options options) {
                    try {
                        val template = handlebars.compileInline(content)
                        return template.apply(context)
                    } catch (Exception e) {
                        System.err.println("Error in partial " + name + ": " + e.message)
                        return ""
                    }
                }
            })
            
        } catch (Exception e) {
            System.err.println("Failed to register partial: " + name + " - " + e.message)
        }
    }
    
    /**
     * Load and register common partials
     */
    def void loadCommonPartials() {
        // Register common partials
        registerPartial("cpp_file_header", '''
            /**
             * @file {{fileName}}
             * @brief {{description}}
             * 
             * Generated by DataType DSL Generator
             * Generation time: {{timestamp}}
             * 
             * DO NOT EDIT THIS FILE MANUALLY
             */''')
        
        registerPartial("cpp_guard_begin", '''
            #ifndef {{guardName}}
            #define {{guardName}}''')
        
        registerPartial("cpp_guard_end", '''
            #endif // {{guardName}}''')
        
        // Register standard includes partial
        registerPartial("cpp_standard_includes", '''
            #include <cstdint>
            #include <string>
            #include <vector>
            #include <array>
            #include <memory>''')
    }
    
    /**
     * Process template string directly (for inline templates)
     */
    def String processInlineTemplate(String templateContent, Map<String, ?> variables) {
        try {
            val template = handlebars.compileInline(templateContent)
            
            // Create a proper context map
            val context = if (variables !== null) {
                new HashMap<String, Object>(variables)
            } else {
                new HashMap<String, Object>()
            }
            
            return template.apply(context)
        } catch (Exception e) {
            System.err.println("Error processing inline template: " + e.message)
            return ""
        }
    }
}

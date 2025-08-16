package org.xtext.example.mydsl.generator

import java.util.Map
import java.util.HashMap
import java.util.List
import java.util.ArrayList
import java.util.regex.Pattern
import java.util.regex.Matcher
import com.google.inject.Singleton
import java.util.Stack

/**
 * Advanced template processor with support for:
 * - Variable substitution: {{VARIABLE}}
 * - Conditionals: {{#IF condition}} ... {{#ELSE}} ... {{/IF}}
 * - Loops: {{#FOREACH collection AS item}} ... {{/FOREACH}}
 * - Method calls: {{CALL:method(params)}}
 * - Includes: {{INCLUDE:file}}
 * - Comments: {{! comment }}
 * 
 * @author Xtext/Xtend Generator Framework
 */
@Singleton
class AdvancedTemplateProcessor {
    
    // Regex patterns for different template constructs
    static val VARIABLE_PATTERN = Pattern.compile("\\{\\{([A-Za-z_][A-Za-z0-9_.]*?)\\}\\}")
    static val IF_PATTERN = Pattern.compile("\\{\\{#IF\\s+([^}]+)\\}\\}([\\s\\S]*?)(?:\\{\\{#ELSE\\}\\}([\\s\\S]*?))?\\{\\{/IF\\}\\}")
    static val FOREACH_PATTERN = Pattern.compile("\\{\\{#FOREACH\\s+(\\S+)\\s+AS\\s+(\\S+)\\}\\}([\\s\\S]*?)\\{\\{/FOREACH\\}\\}")
    static val CALL_PATTERN = Pattern.compile("\\{\\{CALL:([^}(]+)\\(([^})]*)\\)\\}\\}")
    static val INCLUDE_PATTERN = Pattern.compile("\\{\\{INCLUDE:([^}]+)\\}\\}")
    static val COMMENT_PATTERN = Pattern.compile("\\{\\{![^}]*\\}\\}")
    
    // Template functions registry
    val Map<String, (List<String>)=>String> functions = new HashMap()
    
    // Template loader for includes
    TemplateLoader templateLoader
    
    new() {
        registerBuiltInFunctions()
    }
    
    new(TemplateLoader loader) {
        this()
        this.templateLoader = loader
    }
    
    /**
     * Main entry point for template processing
     */
    def String processTemplate(String template, Map<String, Object> context) {
        if (template === null || template.empty) {
            return ""
        }
        
        var result = template
        
        // Remove comments first
        result = removeComments(result)
        
        // Process includes
        result = processIncludes(result, context)
        
        // Process loops (outer to inner)
        result = processLoops(result, context)
        
        // Process conditionals
        result = processConditionals(result, context)
        
        // Process method calls
        result = processMethodCalls(result, context)
        
        // Process variables (last, as other constructs might generate variables)
        result = processVariables(result, context)
        
        return result
    }
    
    /**
     * Remove template comments
     */
    private def String removeComments(String template) {
        return COMMENT_PATTERN.matcher(template).replaceAll("")
    }
    
    /**
     * Process variable substitutions
     */
    private def String processVariables(String template, Map<String, Object> context) {
        val matcher = VARIABLE_PATTERN.matcher(template)
        val buffer = new StringBuffer()
        
        while (matcher.find()) {
            val varPath = matcher.group(1)
            val value = resolveVariable(varPath, context)
            val replacement = if (value !== null) value.toString else ""
            matcher.appendReplacement(buffer, Matcher.quoteReplacement(replacement))
        }
        matcher.appendTail(buffer)
        
        return buffer.toString()
    }
    
    /**
     * Resolve nested variable paths (e.g., "object.property.subproperty")
     */
    private def Object resolveVariable(String path, Map<String, Object> context) {
        val parts = path.split("\\.")
        var Object current = context.get(parts.get(0))
        
        for (var i = 1; i < parts.length && current !== null; i++) {
            val part = parts.get(i)
            
            if (current instanceof Map<?, ?>) {
                // Fixed: Cast to Map<String, Object> properly
                val map = current as Map<?, ?>
                current = map.get(part)
            } else {
                // Try to access property via reflection
                try {
                    val field = current.class.getField(part)
                    current = field.get(current)
                } catch (Exception e) {
                    // Try getter method
                    try {
                        val getterName = "get" + part.substring(0, 1).toUpperCase + part.substring(1)
                        val method = current.class.getMethod(getterName)
                        current = method.invoke(current)
                    } catch (Exception e2) {
                        return null
                    }
                }
            }
        }
        
        return current
    }
    
    /**
     * Process conditional statements
     */
    private def String processConditionals(String template, Map<String, Object> context) {
        val matcher = IF_PATTERN.matcher(template)
        val buffer = new StringBuffer()
        
        while (matcher.find()) {
            val condition = matcher.group(1).trim
            val ifBlock = matcher.group(2)
            val elseBlock = matcher.group(3) ?: ""
            
            val result = if (evaluateCondition(condition, context)) {
                processTemplate(ifBlock, context)
            } else {
                processTemplate(elseBlock, context)
            }
            
            matcher.appendReplacement(buffer, Matcher.quoteReplacement(result))
        }
        matcher.appendTail(buffer)
        
        return buffer.toString()
    }
    
    /**
     * Evaluate a condition expression
     */
    private def boolean evaluateCondition(String condition, Map<String, Object> context) {
        // Handle negation
        if (condition.startsWith("!")) {
            return !evaluateCondition(condition.substring(1).trim, context)
        }
        
        // Handle comparisons
        if (condition.contains("==")) {
            val parts = condition.split("==")
            val left = evaluateExpression(parts.get(0).trim, context)
            val right = evaluateExpression(parts.get(1).trim, context)
            return left == right
        }
        
        if (condition.contains("!=")) {
            val parts = condition.split("!=")
            val left = evaluateExpression(parts.get(0).trim, context)
            val right = evaluateExpression(parts.get(1).trim, context)
            return left != right
        }
        
        // Handle AND/OR operations
        if (condition.contains("&&")) {
            val parts = condition.split("&&")
            return parts.forall[evaluateCondition(it.trim, context)]
        }
        
        if (condition.contains("||")) {
            val parts = condition.split("\\|\\|")
            return parts.exists[evaluateCondition(it.trim, context)]
        }
        
        // Simple boolean evaluation
        val value = evaluateExpression(condition, context)
        
        if (value === null) return false
        if (value instanceof Boolean) return value
        if (value instanceof String) return !value.empty
        if (value instanceof Number) return value.intValue != 0
        if (value instanceof List<?>) return !value.empty
        if (value instanceof Map<?, ?>) return !value.empty
        
        return true
    }
    
    /**
     * Evaluate an expression to get its value
     */
    private def Object evaluateExpression(String expression, Map<String, Object> context) {
        val trimmed = expression.trim
        
        // Handle string literals
        if (trimmed.startsWith('"') && trimmed.endsWith('"')) {
            return trimmed.substring(1, trimmed.length - 1)
        }
        
        // Handle boolean literals
        if (trimmed == "true") return true
        if (trimmed == "false") return false
        
        // Handle numeric literals
        try {
            return Integer.parseInt(trimmed)
        } catch (Exception e) {
            // Not a number
        }
        
        // Handle variables
        return resolveVariable(trimmed, context)
    }
    
    /**
     * Process foreach loops - Fixed
     */
    private def String processLoops(String template, Map<String, Object> context) {
        val matcher = FOREACH_PATTERN.matcher(template)
        val buffer = new StringBuffer()
        
        while (matcher.find()) {
            val collectionName = matcher.group(1)
            val itemName = matcher.group(2)
            val loopBody = matcher.group(3)
            
            val collection = resolveVariable(collectionName, context)
            val result = new StringBuilder()
            
            if (collection instanceof Iterable<?>) {
                var index = 0
                val list = if (collection instanceof List<?>) collection else collection.toList
                for (item : collection) {
                    val loopContext = new HashMap<String, Object>(context)
                    loopContext.put(itemName, item)
                    loopContext.put(itemName + "_index", index)
                    loopContext.put(itemName + "_first", index == 0)
                    loopContext.put(itemName + "_last", index == list.size - 1)
                    
                    result.append(processTemplate(loopBody, loopContext))
                    index++
                }
            } else if (collection instanceof Map<?, ?>) {
                // Fixed: Handle Map entries properly
                val map = collection as Map<?, ?>
                for (key : map.keySet) {
                    val loopContext = new HashMap<String, Object>(context)
                    val entry = new HashMap<String, Object>()
                    entry.put("key", key)
                    entry.put("value", map.get(key))
                    loopContext.put(itemName, entry)
                    loopContext.put(itemName + "_key", key)
                    loopContext.put(itemName + "_value", map.get(key))
                    
                    result.append(processTemplate(loopBody, loopContext))
                }
            }
            
            matcher.appendReplacement(buffer, Matcher.quoteReplacement(result.toString))
        }
        matcher.appendTail(buffer)
        
        return buffer.toString()
    }
    
    /**
     * Process method calls
     */
    private def String processMethodCalls(String template, Map<String, Object> context) {
        val matcher = CALL_PATTERN.matcher(template)
        val buffer = new StringBuffer()
        
        while (matcher.find()) {
            val methodName = matcher.group(1).trim
            val params = matcher.group(2).trim
            
            val result = invokeMethod(methodName, params, context)
            matcher.appendReplacement(buffer, Matcher.quoteReplacement(result))
        }
        matcher.appendTail(buffer)
        
        return buffer.toString()
    }
    
    /**
     * Invoke a template method
     */
    private def String invokeMethod(String methodName, String params, Map<String, Object> context) {
        // Parse parameters
        val paramList = parseParameters(params, context)
        
        // Check if function is registered
        if (functions.containsKey(methodName)) {
            val function = functions.get(methodName)
            return function.apply(paramList)
        }
        
        // Fallback: return unchanged
        return '''{{CALL:«methodName»(«params»)}}'''
    }
    
    /**
     * Parse method parameters
     */
    private def List<String> parseParameters(String params, Map<String, Object> context) {
        val result = new ArrayList<String>()
        
        if (params.empty) {
            return result
        }
        
        // Simple parameter parsing (can be enhanced for complex cases)
        val parts = params.split(",")
        for (part : parts) {
            val trimmed = part.trim
            val value = evaluateExpression(trimmed, context)
            result.add(if (value !== null) value.toString else trimmed)
        }
        
        return result
    }
    
    /**
     * Process include statements
     */
    private def String processIncludes(String template, Map<String, Object> context) {
        if (templateLoader === null) {
            return template
        }
        
        val matcher = INCLUDE_PATTERN.matcher(template)
        val buffer = new StringBuffer()
        
        while (matcher.find()) {
            val includePath = matcher.group(1).trim
            
            try {
                val includedContent = templateLoader.loadTemplate(includePath)
                val processedContent = processTemplate(includedContent, context)
                matcher.appendReplacement(buffer, Matcher.quoteReplacement(processedContent))
            } catch (Exception e) {
                // If include fails, leave a comment
                matcher.appendReplacement(buffer, 
                    '''<!-- Failed to include: «includePath» - «e.message» -->''')
            }
        }
        matcher.appendTail(buffer)
        
        return buffer.toString()
    }
    
    /**
     * Register built-in template functions
     */
    private def void registerBuiltInFunctions() {
        // String manipulation functions
        functions.put("toUpper", [params | 
            if (!params.empty) params.get(0).toUpperCase else ""
        ])
        
        functions.put("toLower", [params | 
            if (!params.empty) params.get(0).toLowerCase else ""
        ])
        
        functions.put("capitalize", [params | 
            if (!params.empty && !params.get(0).empty) {
                val str = params.get(0)
                str.substring(0, 1).toUpperCase + str.substring(1)
            } else ""
        ])
        
        functions.put("trim", [params | 
            if (!params.empty) params.get(0).trim else ""
        ])
        
        functions.put("replace", [params | 
            if (params.size >= 3) {
                params.get(0).replace(params.get(1), params.get(2))
            } else if (!params.empty) params.get(0) else ""
        ])
        
        // Numeric functions
        functions.put("add", [params | 
            if (params.size >= 2) {
                try {
                    val a = Double.parseDouble(params.get(0))
                    val b = Double.parseDouble(params.get(1))
                    String.valueOf(a + b)
                } catch (Exception e) {
                    "0"
                }
            } else "0"
        ])
        
        functions.put("multiply", [params | 
            if (params.size >= 2) {
                try {
                    val a = Double.parseDouble(params.get(0))
                    val b = Double.parseDouble(params.get(1))
                    String.valueOf(a * b)
                } catch (Exception e) {
                    "0"
                }
            } else "0"
        ])
        
        // Date/Time functions
        functions.put("now", [params | 
            java.time.LocalDateTime.now().toString()
        ])
        
        functions.put("date", [params | 
            java.time.LocalDate.now().toString()
        ])
        
        // Utility functions
        functions.put("uuid", [params | 
            java.util.UUID.randomUUID().toString()
        ])
        
        functions.put("default", [params | 
            if (params.size >= 2) {
                if (params.get(0).empty) params.get(1) else params.get(0)
            } else if (!params.empty) params.get(0) else ""
        ])
    }
    
    /**
     * Register a custom template function
     */
    def void registerFunction(String name, (List<String>)=>String function) {
        functions.put(name, function)
    }
    
    /**
     * Set the template loader for includes
     */
    def void setTemplateLoader(TemplateLoader loader) {
        this.templateLoader = loader
    }
    
    /**
     * Validate template syntax
     */
    def ValidationResult validateTemplate(String template) {
        val result = new ValidationResult()
        
        try {
            // Check for matching IF/ENDIF
            validateMatching(template, "{{#IF", "{{/IF}}", "IF blocks", result)
            
            // Check for matching FOREACH/ENDFOREACH
            validateMatching(template, "{{#FOREACH", "{{/FOREACH}}", "FOREACH loops", result)
            
            // Check for valid variable references
            val varMatcher = VARIABLE_PATTERN.matcher(template)
            while (varMatcher.find()) {
                val varName = varMatcher.group(1)
                if (!varName.matches("[A-Za-z_][A-Za-z0-9_.]*")) {
                    result.addError('''Invalid variable name: «varName»''')
                }
            }
            
        } catch (Exception e) {
            result.addError('''Template validation failed: «e.message»''')
        }
        
        return result
    }
    
    /**
     * Validate matching open/close tags
     */
    private def void validateMatching(String template, String open, String close, 
                                      String description, ValidationResult result) {
        val openCount = template.split(Pattern.quote(open), -1).length - 1
        val closeCount = template.split(Pattern.quote(close), -1).length - 1
        
        if (openCount != closeCount) {
            result.addError('''Mismatched «description»: «openCount» open, «closeCount» close''')
        }
    }
}

/**
 * Template validation result
 */
class ValidationResult {
    val errors = new ArrayList<String>()
    val warnings = new ArrayList<String>()
    
    def boolean isValid() {
        return errors.empty
    }
    
    def void addError(String error) {
        errors.add(error)
    }
    
    def void addWarning(String warning) {
        warnings.add(warning)
    }
    
    def List<String> getErrors() {
        return new ArrayList(errors)
    }
    
    def List<String> getWarnings() {
        return new ArrayList(warnings)
    }
    
    override toString() {
        val sb = new StringBuilder()
        if (!errors.empty) {
            sb.append("Errors:\n")
            errors.forEach[sb.append("  - ").append(it).append("\n")]
        }
        if (!warnings.empty) {
            sb.append("Warnings:\n")
            warnings.forEach[sb.append("  - ").append(it).append("\n")]
        }
        return sb.toString()
    }
}

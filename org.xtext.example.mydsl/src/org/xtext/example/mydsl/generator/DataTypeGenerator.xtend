package org.xtext.example.mydsl.generator

import org.xtext.example.mydsl.myDsl.*
import org.eclipse.xtext.generator.IFileSystemAccess2
import com.google.inject.Singleton
import com.google.inject.Inject
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.HashMap
import java.util.Map
import org.eclipse.xtext.nodemodel.util.NodeModelUtils
import org.eclipse.xtext.nodemodel.ILeafNode
import org.eclipse.emf.ecore.util.EcoreUtil
import org.eclipse.emf.ecore.EObject

/**
 * C++ code generator for DataType DSL using external templates
 */
@Singleton
class DataTypeGenerator {

	@Inject TemplateLoader templateLoader

	static val String OUTPUT_PATH = "generated/"

	/**
	 * Generate C++ files for the model
	 */
	def void generate(Model model, IFileSystemAccess2 fsa) {
		// Initialize template loader
		if (templateLoader === null) {
			templateLoader = new TemplateLoader()
		}
		templateLoader.setTemplateBasePath("templates/")

		try {
			// Generate types header file
			generateTypesHeader(model, fsa)
	
			// Generate individual headers for each type
			for (type : model.types) {
				try {
					generateTypeHeader(type, model, fsa)
				} catch (Exception e) {
					System.err.println("Warning: Failed to generate header for type: " + getTypeName(type))
					e.printStackTrace()
				}
			}
	
			// Generate headers for types in packages
			for (pkg : model.packages) {
				for (type : pkg.types) {
					try {
						generateTypeHeader(type, model, fsa, pkg)
					} catch (Exception e) {
						System.err.println("Warning: Failed to generate header for type in package " + pkg.name + ": " + getTypeName(type))
						e.printStackTrace()
					}
				}
			}
	
			// Generate CMakeLists.txt
			generateCMakeFile(model, fsa)
		} catch (Exception e) {
			System.err.println("Error during C++ generation: " + e.message)
			e.printStackTrace()
		}
	}

	/**
	 * Generate main types header file using template
	 */
	def void generateTypesHeader(Model model, IFileSystemAccess2 fsa) {
		val fileName = '''«OUTPUT_PATH»include/Types.h'''

		// Build includes list
		val includes = new StringBuilder()
		for (type : model.types) {
			includes.append('''#include "«getTypeName(type)».h"''').append("\n")
		}
		for (pkg : model.packages) {
			for (type : pkg.types) {
				includes.append('''#include "«pkg.name»/«getTypeName(type)».h"''').append("\n")
			}
		}

		val variables = new HashMap<String, String>()
		variables.put("TIMESTAMP", LocalDateTime.now.format(DateTimeFormatter.ISO_LOCAL_DATE_TIME))
		variables.put("TYPE_INCLUDES", includes.toString())

		val content = templateLoader.processTemplate("cpp/types_header.template", variables)
		fsa.generateFile(fileName, content)
	}

	/**
	 * Generate header for a specific type using templates
	 */
	def void generateTypeHeader(FType type, Model model, IFileSystemAccess2 fsa) {
		generateTypeHeader(type, model, fsa, null)
	}

	def void generateTypeHeader(FType type, Model model, IFileSystemAccess2 fsa, Package pkg) {
		try {
			val typeName = getTypeName(type)
			val path = if (pkg !== null) '''«pkg.name»/''' else ""
			val fileName = '''«OUTPUT_PATH»include/«path»«typeName».h'''

			val guardName = '''«IF pkg !== null»«pkg.name.toUpperCase.replace(".", "_")»_«ENDIF»«typeName.toUpperCase»_H'''

			// Build includes
			val includesVars = new HashMap<String, String>()
			includesVars.put("CUSTOM_INCLUDES", generateCustomIncludes(type, model))
			val includes = templateLoader.processTemplate("cpp/includes.template", includesVars)

			// Build namespace
			val namespaceBegin = if (pkg !== null) '''namespace «pkg.name.replace(".", "::")» {''' else ""
			val namespaceEnd = if (pkg !== null) '''} // namespace «pkg.name.replace(".", "::")»''' else ""

			// Generate type content
			val typeContent = generateTypeContent(type, model)

			// Process main header template
			val variables = new HashMap<String, String>()
			variables.put("FILE_NAME", typeName + ".h")
			variables.put("DESCRIPTION", "Definition of " + typeName)
			variables.put("TIMESTAMP", LocalDateTime.now.format(DateTimeFormatter.ISO_LOCAL_DATE_TIME))
			variables.put("GUARD_NAME", guardName)
			variables.put("INCLUDES", includes)
			variables.put("NAMESPACE_BEGIN", namespaceBegin)
			variables.put("NAMESPACE_END", namespaceEnd)
			variables.put("FORWARD_DECLARATIONS", "")
			variables.put("CONTENT", typeContent)

			val content = templateLoader.processTemplate("cpp/header.template", variables)
			if (content !== null && !content.empty) {
				fsa.generateFile(fileName, content)
			} else {
				System.err.println("Warning: Empty content for header " + fileName)
			}
		} catch (Exception e) {
			System.err.println("Error generating header for type " + getTypeName(type) + ": " + e.message)
			e.printStackTrace()
		}
	}

	/**
	 * Generate custom includes for a type
	 */
	def String generateCustomIncludes(FType type, Model model) {
		val includes = new StringBuilder()

		// Add includes for referenced types
		if (type instanceof FStructType) {
			if (type.base !== null) {
				includes.append('''// Base class include''').append("\n")
				includes.append('''#include "«type.base.name».h"''').append("\n")
			}
		}

		return includes.toString()
	}

	/**
	 * Generate content for a type using templates
	 */
	def String generateTypeContent(FType type, Model model) {
		switch (type) {
			FStructType: generateStructWithTemplate(type, model)
			FEnumerationType: generateEnumWithTemplate(type)
			FArrayType: generateArrayWithTemplate(type, model)
			FTypeDef: generateTypeDefWithTemplate(type, model)
			default: ""
		}
	}

	/**
	 * Generate struct using template
	 */
	def String generateStructWithTemplate(FStructType struct, Model model) {
		// Generate fields
		val fields = new StringBuilder()
		for (field : struct.elements) {
			try {
				val fieldStr = generateFieldWithTemplate(field, model)
				fields.append(fieldStr).append("\n")
			} catch (Exception e) {
				System.err.println("Warning: Failed to generate field " + field.name + ": " + e.message)
				// Generate a placeholder field
				fields.append("    // ERROR: Failed to generate field ").append(field.name).append("\n")
				fields.append("    uint32_t ").append(field.name ?: "unknown")
				if (field.array) {
					fields.append("[").append(field.size).append("]")
				}
				fields.append(";\n")
			}
		}

		val variables = new HashMap<String, String>()
		variables.put("COMMENT", generateComment(struct.comment))
		variables.put("STRUCT_NAME", struct.name)
		variables.put("BASE_CLASS", if(struct.base !== null) " : public " + struct.base.name else "")
		variables.put("FIELDS", fields.toString())

		return templateLoader.processTemplate("cpp/struct.template", variables)
	}

	/**
	 * Generate field using template
	 */
	def String generateFieldWithTemplate(FField field, Model model) {
		// Add null safety check
		val fieldName = if (field.name !== null) field.name else "field"
		
		// Get the type, handling potential null/unresolved references
		var fieldType = "uint32_t" // Better default than void
		if (field.type !== null) {
			try {
				fieldType = mapTypeRef(field.type, model)
				
				// Double-check we didn't get void or an unmapped type
				if (fieldType == "void" || fieldType.empty) {
					// Try to extract type name directly from the field's type node
					val node = NodeModelUtils.findActualNodeFor(field.type)
					if (node !== null) {
						val leaves = node.leafNodes
						if (leaves !== null && !leaves.empty) {
							val typeName = leaves.head.text.trim
							if (!typeName.empty) {
								// Special handling for String type
								if (typeName.equals("String")) {
									fieldType = "std::string"
								} else {
									fieldType = mapBasicTypeByName(typeName, field.type)
								}
							}
						}
					}
					// If still void, use a default
					if (fieldType == "void" || fieldType.empty) {
						fieldType = "uint32_t"
					}
				} else if (fieldType.equals("String")) {
					// If we got "String" unmapped, map it to std::string
					fieldType = "std::string"
				}
			} catch (Exception e) {
				System.err.println("Warning: Failed to map type for field " + fieldName + ": " + e.message)
				fieldType = "uint32_t"
			}
		}
		
		val variables = new HashMap<String, String>()
		variables.put("FIELD_COMMENT", if(field.comment !== null) generateComment(field.comment) else "")
		variables.put("FIELD_TYPE", fieldType)
		variables.put("ARRAY_DECL", if (field.array) '''[«field.size»]''' else "")
		variables.put("FIELD_NAME", fieldName)
		variables.put("INITIALIZER", generateFieldInitializer(field))

		return templateLoader.processTemplate("cpp/field.template", variables)
	}

	/**
	 * Generate field initializer
	 */
	def String generateFieldInitializer(FField field) {
		if (field.type !== null && field.type.value !== null) {
			return " = " + expressionToString(field.type.value)
		}
		return ""
	}

	/**
	 * Generate enum using template
	 */
	def String generateEnumWithTemplate(FEnumerationType enumType) {
		// Generate enumerators
		val enumerators = new StringBuilder()
		var first = true
		for (enumerator : enumType.enumerators) {
			if (!first) {
				enumerators.append(",\n")
			}
			enumerators.append("    ")
			if (enumerator.comment !== null) {
				enumerators.append(generateComment(enumerator.comment)).append("\n    ")
			}
			enumerators.append(enumerator.name)
			if (enumerator.value !== null) {
				enumerators.append(" = ").append(expressionToString(enumerator.value))
			}
			first = false
		}

		val variables = new HashMap<String, String>()
		variables.put("COMMENT", generateComment(enumType.comment))
		variables.put("ENUM_NAME", enumType.name)
		variables.put("BASE_TYPE", if(enumType.base !== null) " : " + enumType.base.name else " : int32_t")
		variables.put("ENUMERATORS", enumerators.toString())

		return templateLoader.processTemplate("cpp/enum.template", variables)
	}

	/**
	 * Generate array using template
	 */
	def String generateArrayWithTemplate(FArrayType array, Model model) {
		val variables = new HashMap<String, String>()
		variables.put("COMMENT", generateComment(array.comment))
		variables.put("ARRAY_NAME", array.name)
		variables.put("ELEMENT_TYPE", mapTypeRef(array.elementType, model))

		return templateLoader.processTemplate("cpp/array.template", variables)
	}

	/**
	 * Generate typedef using template
	 */
	def String generateTypeDefWithTemplate(FTypeDef typedef, Model model) {
		var actualType = "uint32_t" // Default
		
		// Get the actual type with proper mapping
		if (typedef.actualType !== null) {
			actualType = mapTypeRef(typedef.actualType, model)
			
			// Special handling for String type
			if (actualType.equals("String") || actualType.equals("void")) {
				// Try to extract type name directly
				val node = NodeModelUtils.findActualNodeFor(typedef.actualType)
				if (node !== null) {
					val leaves = node.leafNodes
					if (leaves !== null && !leaves.empty) {
						val typeName = leaves.head.text.trim
						if (typeName.equals("String")) {
							actualType = "std::string"
						} else if (!typeName.empty) {
							actualType = mapBasicTypeByName(typeName, typedef.actualType)
						}
					}
				}
			}
		}
		
		val variables = new HashMap<String, String>()
		variables.put("COMMENT", generateComment(typedef.comment))
		variables.put("TYPEDEF_NAME", typedef.name)
		variables.put("ACTUAL_TYPE", actualType)

		return templateLoader.processTemplate("cpp/typedef.template", variables)
	}

	/**
	 * Generate comment block
	 */
	def String generateComment(FAnnotationBlock comment) {
		if (comment === null || comment.elements.empty) {
			return ""
		}

		val sb = new StringBuilder()
		sb.append("/**\n")
		for (annotation : comment.elements) {
			sb.append(" * ").append(annotation.rawText).append("\n")
		}
		sb.append(" */")
		return sb.toString()
	}

	/**
	 * Map FTypeRef to C++ type string
	 */
	def String mapTypeRef(FTypeRef typeRef, Model model) {
		if (typeRef === null) {
			return "void"
		}
		
		// First, try to get the predefined reference
		val refType = typeRef.predefined
		
		if (refType !== null) {
			// Check if it's a basic type
			if (refType instanceof FBasicTypeId) {
				return mapBasicType(refType, typeRef)
			}
	
			// Check if it's a defined type
			if (refType instanceof FType) {
				return getTypeName(refType)
			}
		}
		
		// If the reference is null or unresolved, extract the type name from the AST
		// This is needed because cross-references to types in PrimitiveDataTypes aren't being resolved
		var extractedTypeName = null as String
		try {
			val node = NodeModelUtils.findActualNodeFor(typeRef)
			if (node !== null) {
				// Try to get the text directly from the node
				val text = NodeModelUtils.getTokenText(node)
				if (text !== null && !text.empty) {
					extractedTypeName = text.trim
					// Remove any modifiers like {len 36}
					if (extractedTypeName.contains("{")) {
						extractedTypeName = extractedTypeName.substring(0, extractedTypeName.indexOf("{")).trim
					}
				}
				
				// If that didn't work, try leaf nodes
				if (extractedTypeName === null || extractedTypeName.empty) {
					// Extract type name from first non-structural leaf node
					extractedTypeName = extractTypeNameFromLeafNodes(node.leafNodes)
				}
			}
		} catch (Exception e) {
			// Silent fail - use default
		}
		
		// Map the extracted type name
		if (extractedTypeName !== null && !extractedTypeName.empty) {
			// Special handling for String type (capital S)
			if (extractedTypeName.equals("String")) {
				return "std::string"
			}
			// Map the type name
			return mapBasicTypeByName(extractedTypeName, typeRef)
		}

		// Last resort: return a default type instead of void to avoid breaking generation
		return "uint32_t" // Better default than void for fields
	}
	
	/**
	 * Helper method to extract type name from leaf nodes
	 */
	def private String extractTypeNameFromLeafNodes(Iterable<ILeafNode> leafNodes) {
		for (leaf : leafNodes) {
			val leafText = leaf.text.trim
			if (!leafText.empty && !leafText.equals("{") && !leafText.equals("}") && 
				!leafText.equals("len") && !leafText.equals("=")) {
				// Found the type name, return it
				return leafText
			}
		}
		return null
	}
	
	/**
	 * Get the unresolved type name from a FTypeRef
	 */
	def String getUnresolvedTypeName(FTypeRef typeRef) {
		// Use the node model to get the actual text
		try {
			val node = NodeModelUtils.findActualNodeFor(typeRef)
			if (node !== null) {
				// Get the text of the first ID token which should be the type name
				for (leaf : node.leafNodes) {
					val grammarElement = leaf.grammarElement
					if (grammarElement !== null) {
						val text = leaf.text.trim
						// Skip structural tokens
						if (!text.empty && !text.equals("{") && !text.equals("}") && 
							!text.equals("=") && !text.equals("len") && !text.equals("unit") &&
							!text.equals("compuMethod") && !text.equals("init")) {
							// This should be the type name
							return text
						}
					}
				}
			}
		} catch (Exception e) {
			// Silent fail
		}
		return null
	}
	
	/**
	 * Get type name from reference
	 */
	def String getTypeNameFromRef(Object refType) {
		// Use reflection to get the name if available
		try {
			val nameMethod = refType.class.getMethod("getName")
			if (nameMethod !== null) {
				val name = nameMethod.invoke(refType)
				if (name instanceof String) {
					return name
				}
			}
		} catch (Exception e) {
			// Silent fail
		}
		return null
	}
	
	/**
	 * Map basic type by name when reference resolution fails
	 */
	def String mapBasicTypeByName(String typeName, FTypeRef typeRef) {
		if (typeName === null || typeName.empty) {
			return "uint32_t"
		}
		
		// Don't convert to lowercase - check both exact and lowercase matches
		// Map based on name
		switch (typeName) {
			// Check exact matches first
			case "String": return "std::string"
			case "uint8": return "uint8_t"
			case "uint16": return "uint16_t"  
			case "uint32": return "uint32_t"
			case "uint64": return "uint64_t"
			case "int8": return "int8_t"
			case "int16": return "int16_t"
			case "int32": return "int32_t"
			case "int64": return "int64_t"
			case "float32": return "float"
			case "float64": return "double"
			// Then check common variations
			case "bool": return "bool"
			case "boolean": return "bool"
			case "int": return "int32_t"
			case "uint": return "uint32_t"
			case "long": return "int64_t"
			case "ulong": return "uint64_t"
			case "float": return "float"
			case "double": return "double"
			case "string": return "std::string"
			case "byte": return "uint8_t"
			case "char": return "char"
			case "wchar": return "wchar_t"
		}
		
		// Handle bit length if specified
		if (typeRef !== null && typeRef.bitLen > 0) {
			if(typeRef.bitLen <= 8) return "uint8_t"
			if(typeRef.bitLen <= 16) return "uint16_t"
			if(typeRef.bitLen <= 32) return "uint32_t"
			if(typeRef.bitLen <= 64) return "uint64_t"
		}
		
		// If it's a user type (starts with capital), return as-is
		if (typeName.length > 0 && Character.isUpperCase(typeName.charAt(0))) {
			return typeName
		}
		
		// Try lowercase mapping as fallback
		val nameLower = typeName.toLowerCase
		switch (nameLower) {
			case "bool": return "bool"
			case "boolean": return "bool"
			case "int8": return "int8_t"
			case "uint8": return "uint8_t"
			case "int16": return "int16_t"
			case "uint16": return "uint16_t"
			case "int32": return "int32_t"
			case "int": return "int32_t"
			case "uint32": return "uint32_t"
			case "uint": return "uint32_t"
			case "int64": return "int64_t"
			case "long": return "int64_t"
			case "uint64": return "uint64_t"
			case "ulong": return "uint64_t"
			case "float": return "float"
			case "float32": return "float"
			case "double": return "double"
			case "float64": return "double"
			case "string": return "std::string"
			case "byte": return "uint8_t"
			case "char": return "char"
			case "wchar": return "wchar_t"
		}
		
		return "uint32_t"
	}

	/**
	 * Map basic type to C++ type
	 */
	def String mapBasicType(FBasicTypeId basicType, FTypeRef typeRef) {
		val name = basicType.name
		val nameLower = name.toLowerCase

		// Map based on name and properties
		switch (nameLower) {
			case "bool": return "bool"
			case "boolean": return "bool"
			case "int8": return "int8_t"
			case "uint8": return "uint8_t"
			case "int16": return "int16_t"
			case "uint16": return "uint16_t"
			case "int32": return "int32_t"
			case "int": return "int32_t"
			case "uint32": return "uint32_t"
			case "uint": return "uint32_t"
			case "int64": return "int64_t"
			case "long": return "int64_t"
			case "uint64": return "uint64_t"
			case "ulong": return "uint64_t"
			case "float": return "float"
			case "float32": return "float"
			case "double": return "double"
			case "float64": return "double"
			case "string": return "std::string"  // Handle both "string" and "String"
			case "byte": return "uint8_t"
			case "char": return "char"
			case "wchar": return "wchar_t"
		}

		// Check category
		if (basicType.category == Category.STRING) {
			return "std::string"
		}

		// Check if it has a specific bit length
		if (typeRef !== null && typeRef.bitLen > 0) {
			if(typeRef.bitLen <= 8) return "uint8_t"
			if(typeRef.bitLen <= 16) return "uint16_t"
			if(typeRef.bitLen <= 32) return "uint32_t"
			if(typeRef.bitLen <= 64) return "uint64_t"
		}

		// If the original name is "String" with capital S, return std::string
		if (name.equals("String")) {
			return "std::string"
		}

		// Default - return the basic type name
		return basicType.name
	}

	/**
	 * Get type name from FType
	 */
	def String getTypeName(FType type) {
		switch (type) {
			FStructType: type.name
			FEnumerationType: type.name
			FArrayType: type.name
			FTypeDef: type.name
			default: "unknown"
		}
	}

	/**
	 * Convert expression to string
	 */
	def String expressionToString(Expression expr) {
		switch (expr) {
			LiteralExpression: literalToString(expr.value)
			IdentifierExpression: expr.id
			default: ""
		}
	}

	def String literalToString(Literal literal) {
		switch (literal) {
			StringLiteral: '''"«literal.value»"'''
			IntLiteral:
				String.valueOf(literal.value)
			FloatLiteral:
				literal.value + "f"
			BooleanLiteral:
				literal.value
			default:
				""
		}
	}

	/**
	 * Generate CMakeLists.txt using template
	 */
	def void generateCMakeFile(Model model, IFileSystemAccess2 fsa) {
		val fileName = '''«OUTPUT_PATH»CMakeLists.txt'''

		val variables = new HashMap<String, String>()
		variables.put("PROJECT_NAME", "DataTypes")
		variables.put("VERSION", "1.0.0")

		val content = templateLoader.processTemplate("cmake/CMakeLists.template", variables)
		fsa.generateFile(fileName, content)
	}
}

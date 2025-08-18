package org.xtext.example.mydsl.generator

import org.xtext.example.mydsl.myDsl.*
import org.eclipse.xtext.generator.IFileSystemAccess2
import com.google.inject.Singleton
import com.google.inject.Inject
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.HashMap
import java.util.Map

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
		templateLoader.setTemplateBasePath("/templates/")

		// Generate types header file
		generateTypesHeader(model, fsa)

		// Generate individual headers for each type
		for (type : model.types) {
			generateTypeHeader(type, model, fsa)
		}

		// Generate headers for types in packages
		for (pkg : model.packages) {
			for (type : pkg.types) {
				generateTypeHeader(type, model, fsa, pkg)
			}
		}

		// Generate CMakeLists.txt
		generateCMakeFile(model, fsa)
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

		val content = templateLoader.processTemplate("/templates/cpp/types_header.template", variables)
		fsa.generateFile(fileName, content)
	}

	/**
	 * Generate header for a specific type using templates
	 */
	def void generateTypeHeader(FType type, Model model, IFileSystemAccess2 fsa) {
		generateTypeHeader(type, model, fsa, null)
	}

	def void generateTypeHeader(FType type, Model model, IFileSystemAccess2 fsa, Package pkg) {
		val typeName = getTypeName(type)
		val path = if (pkg !== null) '''«pkg.name»/''' else ""
		val fileName = '''«OUTPUT_PATH»include/«path»«typeName».h'''

		val guardName = '''«IF pkg !== null»«pkg.name.toUpperCase.replace(".", "_")»_«ENDIF»«typeName.toUpperCase»_H'''

		// Build includes
		val includesVars = new HashMap<String, String>()
		includesVars.put("CUSTOM_INCLUDES", generateCustomIncludes(type, model))
		val includes = templateLoader.processTemplate("/templates/cpp/includes.template", includesVars)

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

		val content = templateLoader.processTemplate("/templates/cpp/header.template", variables)
		fsa.generateFile(fileName, content)
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
			fields.append(generateFieldWithTemplate(field, model)).append("\n")
		}

		val variables = new HashMap<String, String>()
		variables.put("COMMENT", generateComment(struct.comment))
		variables.put("STRUCT_NAME", struct.name)
		variables.put("BASE_CLASS", if(struct.base !== null) " : public " + struct.base.name else "")
		variables.put("FIELDS", fields.toString())

		return templateLoader.processTemplate("/templates/cpp/struct.template", variables)
	}

	/**
	 * Generate field using template
	 */
	def String generateFieldWithTemplate(FField field, Model model) {
		val variables = new HashMap<String, String>()
		variables.put("FIELD_COMMENT", if(field.comment !== null) generateComment(field.comment) else "")
		variables.put("FIELD_TYPE", mapTypeRef(field.type, model))
		variables.put("ARRAY_DECL", if (field.array) '''[«field.size»]''' else "")
		variables.put("FIELD_NAME", field.name)
		variables.put("INITIALIZER", generateFieldInitializer(field))

		return templateLoader.processTemplate("/templates/cpp/field.template", variables)
	}

	/**
	 * Generate field initializer
	 */
	def String generateFieldInitializer(FField field) {
		if (field.type.value !== null) {
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

		return templateLoader.processTemplate("/templates/cpp/enum.template", variables)
	}

	/**
	 * Generate array using template
	 */
	def String generateArrayWithTemplate(FArrayType array, Model model) {
		val variables = new HashMap<String, String>()
		variables.put("COMMENT", generateComment(array.comment))
		variables.put("ARRAY_NAME", array.name)
		variables.put("ELEMENT_TYPE", mapTypeRef(array.elementType, model))

		return templateLoader.processTemplate("/templates/cpp/array.template", variables)
	}

	/**
	 * Generate typedef using template
	 */
	def String generateTypeDefWithTemplate(FTypeDef typedef, Model model) {
		val variables = new HashMap<String, String>()
		variables.put("COMMENT", generateComment(typedef.comment))
		variables.put("TYPEDEF_NAME", typedef.name)
		variables.put("ACTUAL_TYPE", mapTypeRef(typedef.actualType, model))

		return templateLoader.processTemplate("/templates/cpp/typedef.template", variables)
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
		val refType = typeRef.predefined

		// Check if it's a basic type
		if (refType instanceof FBasicTypeId) {
			return mapBasicType(refType, typeRef)
		}

		// Check if it's a defined type
		if (refType instanceof FType) {
			return getTypeName(refType)
		}

		// Default fallback
		return "void"
	}

	/**
	 * Map basic type to C++ type
	 */
	def String mapBasicType(FBasicTypeId basicType, FTypeRef typeRef) {
		val name = basicType.name.toLowerCase

		// Map based on name and properties
		switch (name) {
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
		if (typeRef.bitLen > 0) {
			if(typeRef.bitLen <= 8) return "uint8_t"
			if(typeRef.bitLen <= 16) return "uint16_t"
			if(typeRef.bitLen <= 32) return "uint32_t"
			if(typeRef.bitLen <= 64) return "uint64_t"
		}

		// Default
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

		val content = templateLoader.processTemplate("/templates/cmake/CMakeLists.template", variables)
		fsa.generateFile(fileName, content)
	}
}

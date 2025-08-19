package org.xtext.example.mydsl.generator

import org.xtext.example.mydsl.myDsl.*
import java.util.Set
import java.util.HashSet
import java.util.Map
import java.util.HashMap
import com.google.inject.Singleton
import com.google.inject.Inject
import org.eclipse.xtext.generator.IFileSystemAccess2
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import com.google.protobuf.DescriptorProtos
import com.google.protobuf.DescriptorProtos.FileDescriptorSet
import com.google.protobuf.DescriptorProtos.FileDescriptorProto
import com.google.protobuf.DescriptorProtos.FileOptions
import com.google.protobuf.DescriptorProtos.DescriptorProto
import com.google.protobuf.DescriptorProtos.FieldDescriptorProto
import com.google.protobuf.DescriptorProtos.EnumDescriptorProto
import com.google.protobuf.DescriptorProtos.EnumValueDescriptorProto
import org.eclipse.xtext.generator.JavaIoFileSystemAccess
import org.eclipse.xtext.generator.InMemoryFileSystemAccess
import java.nio.file.Files
import java.nio.file.Paths
import java.nio.file.StandardOpenOption
import org.eclipse.xtext.nodemodel.util.NodeModelUtils
import org.eclipse.xtext.nodemodel.ILeafNode
import org.eclipse.emf.ecore.util.EcoreUtil
import java.io.File
import java.io.FileOutputStream
import org.eclipse.xtext.generator.IFileSystemAccess

/**
 * Protobuf generator for DataType DSL models using templates
 */
@Singleton
class ProtobufGenerator {
    
    @Inject TemplateLoader templateLoader
    
    Map<String, Integer> fieldNumberCounter
    Set<String> imports
    
    // Static map to store binary data for test access
    static val Map<String, byte[]> binaryDataCache = new HashMap<String, byte[]>()
    
    /**
     * Generate Protobuf files for the model
     */
    def void generate(Model model, IFileSystemAccess2 fsa, boolean generateBinary) {
        // Initialize
        fieldNumberCounter = new HashMap()
        imports = new HashSet()
        
        if (templateLoader === null) {
            templateLoader = new TemplateLoader()
        }
        templateLoader.setTemplateBasePath("/templates/")
        
        try {
            // Generate main .proto file with consistent path as DataTypeGenerator
            val protoFileName = '''generated/proto/datatypes.proto'''
            val protoContent = generateProtoFileWithTemplate(model)
            if (protoContent !== null && !protoContent.empty) {
                fsa.generateFile(protoFileName, protoContent)
            } else {
                System.err.println("Warning: Proto content is empty for main file")
            }
            
            // Generate .proto files for each package
            for (pkg : model.packages) {
                try {
                    val pkgProtoFileName = '''generated/proto/«pkg.name.replace(".", "_")».proto'''
                    val pkgContent = generatePackageProtoFileWithTemplate(pkg, model)
                    if (pkgContent !== null && !pkgContent.empty) {
                        fsa.generateFile(pkgProtoFileName, pkgContent)
                    }
                } catch (Exception e) {
                    System.err.println("Warning: Failed to generate proto for package " + pkg.name)
                    e.printStackTrace()
                }
            }
            
            // Generate binary descriptor set if requested
            if (generateBinary) {
                try {
                    val descFileName = '''generated/proto/datatypes.desc'''
                    val descriptorBytes = generateDescriptorSet(model)
                    
                    if (descriptorBytes !== null && descriptorBytes.length > 0) {
                        // Write binary file directly to filesystem
                        writeBinaryDescriptor(fsa, descFileName, descriptorBytes)
                        
                        // Generate info file
                        val infoFileName = '''generated/proto/datatypes.desc.info'''
                        fsa.generateFile(infoFileName, generateDescriptorInfo(model, descriptorBytes))
                    }
                } catch (Exception e) {
                    System.err.println("Warning: Failed to generate binary descriptor: " + e.message)
                    e.printStackTrace()
                }
            }
        } catch (Exception e) {
            System.err.println("Error during Protobuf generation: " + e.message)
            e.printStackTrace()
        }
    }
    
    /**
     * Write binary descriptor file directly to filesystem
     * This avoids text encoding issues with IFileSystemAccess2
     */
    def void writeBinaryDescriptor(IFileSystemAccess2 fsa, String fileName, byte[] data) {
        var success = false
        
        try {
            // Store in cache for later retrieval
            binaryDataCache.put(fileName, data)
            
            // Determine the output directory based on FSA type
            var outputDir = "generated"
            
            // Method 1: For JavaIoFileSystemAccess, get the configured output directory
            if (fsa instanceof JavaIoFileSystemAccess) {
                val javaFsa = fsa as JavaIoFileSystemAccess
                val outputConfig = javaFsa.outputConfigurations?.get(IFileSystemAccess.DEFAULT_OUTPUT)
                if (outputConfig !== null && outputConfig.outputDirectory !== null) {
                    outputDir = outputConfig.outputDirectory
                }
            }
            
            // Method 2: For InMemoryFileSystemAccess (testing), write directly to filesystem
            // We write to a known location that tests can access
            if (fsa instanceof InMemoryFileSystemAccess) {
                // For in-memory FSA, we still write to actual filesystem
                // but to a predictable location
                outputDir = "generated"
                
                // Also store a marker in the InMemoryFileSystemAccess to indicate
                // that a binary file was generated
                val memFsa = fsa as InMemoryFileSystemAccess
                // Store a text marker file indicating the binary file location
                val markerContent = '''
                    Binary file generated: «fileName»
                    Size: «data.length» bytes
                    Location: «outputDir»/«fileName»
                '''
                memFsa.generateFile(fileName + ".marker", markerContent)
            }
            
            // Write the actual binary file to the filesystem
            val file = new File(outputDir, fileName)
            file.parentFile.mkdirs()
            
            val fos = new FileOutputStream(file)
            try {
                fos.write(data)
                fos.flush()
                success = true
                System.out.println("Binary descriptor written to: " + file.absolutePath)
            } finally {
                fos.close()
            }
            
            // If we couldn't write to the expected location, try alternative locations
            if (!success) {
                val alternativePaths = #[
                    "src-gen",
                    "target/generated-sources",
                    System.getProperty("user.dir") + "/generated"
                ]
                
                for (altPath : alternativePaths) {
                    val altFile = new File(altPath, fileName)
                    if (altFile.parentFile.exists() || altFile.parentFile.mkdirs()) {
                        try {
                            val altFos = new FileOutputStream(altFile)
                            try {
                                altFos.write(data)
                                altFos.flush()
                                success = true
                                System.out.println("Binary descriptor written to: " + altFile.absolutePath)
                            } finally {
                                altFos.close()
                            }
                            if (success) {
                                return
                            }
                        } catch (Exception e) {
                            // Try next path
                        }
                    }
                }
            }
            
        } catch (Exception e) {
            System.err.println("Error writing binary descriptor: " + e.message)
            e.printStackTrace()
            
            // Fallback: Generate Base64 encoded version
            generateBase64Fallback(fsa, fileName, data)
        }
    }
    
    /**
     * Get binary data from cache (for testing purposes)
     */
    def static byte[] getBinaryData(String fileName) {
        return binaryDataCache.get(fileName)
    }
    
    /**
     * Clear binary data cache
     */
    def static void clearBinaryCache() {
        binaryDataCache.clear()
    }
    
    /**
     * Generate Base64 encoded fallback file
     */
    def void generateBase64Fallback(IFileSystemAccess2 fsa, String fileName, byte[] data) {
        try {
            val base64FileName = fileName + ".base64"
            val base64Content = java.util.Base64.encoder.encodeToString(data)
            val fileContent = generateBase64FileContent(base64Content, fileName)
            fsa.generateFile(base64FileName, fileContent)
            System.out.println("Base64 fallback written to: " + base64FileName)
        } catch (Exception e) {
            System.err.println("Failed to generate Base64 fallback: " + e.message)
        }
    }
    
    /**
     * Generate Base64 file content with instructions
     */
    def CharSequence generateBase64FileContent(String base64Content, String originalFileName) '''
        # Base64 Encoded Binary Descriptor
        # Original file: «originalFileName»
        # Generated: «LocalDateTime.now.format(DateTimeFormatter.ISO_LOCAL_DATE_TIME)»
        
        # To decode this file to binary:
        # Linux/Mac:
        #   base64 -d «originalFileName».base64 > «originalFileName»
        # Windows (PowerShell):
        #   [System.IO.File]::WriteAllBytes("«originalFileName»", [System.Convert]::FromBase64String((Get-Content "«originalFileName».base64" | Select-String -Pattern "^[A-Za-z0-9+/=]+$")))
        
        # Python:
        #   import base64
        #   with open("«originalFileName».base64", "r") as f:
        #       data = base64.b64decode(f.read().split("\n")[-1])
        #   with open("«originalFileName»", "wb") as f:
        #       f.write(data)
        
        «base64Content»
    '''
    
    /**
     * Generate main .proto file using template
     */
    def String generateProtoFileWithTemplate(Model model) {
        // Build package declaration
        val packageDecl = "package datatypes;"
        
        // Build options
        val options = new StringBuilder()
        options.append("option java_package = \"com.generated.datatypes\";\n")
        options.append("option java_outer_classname = \"DataTypesProto\";\n")
        options.append("option java_multiple_files = true;\n")
        options.append("option optimize_for = SPEED;")
        
        // Build imports
        val imports = new StringBuilder()
        if (!model.packages.empty) {
            imports.append("// Import package proto files\n")
            for (pkg : model.packages) {
                imports.append('''import "«pkg.name.replace(".", "_")».proto";''').append("\n")
            }
        }
        
        // Build content
        val content = new StringBuilder()
        for (type : model.types) {
            content.append(generateProtoType(type)).append("\n\n")
        }
        
        // Process template
        val variables = new HashMap<String, String>()
        variables.put("SOURCE_FILE", "DataTypes Model")
        variables.put("TIMESTAMP", LocalDateTime.now.format(DateTimeFormatter.ISO_LOCAL_DATE_TIME))
        variables.put("PACKAGE", packageDecl)
        variables.put("OPTIONS", options.toString())
        variables.put("IMPORTS", imports.toString())
        variables.put("CONTENT", content.toString())
        
        return templateLoader.processTemplate("/templates/proto/file.template", variables)
    }
    
    /**
     * Generate package-specific .proto file using template
     */
    def String generatePackageProtoFileWithTemplate(Package pkg, Model model) {
        // Build package declaration
        val packageDecl = '''package «pkg.name.replace(".", "_")»;'''
        
        // Build options
        val options = new StringBuilder()
        options.append('''option java_package = "com.generated.«pkg.name»";''').append("\n")
        options.append('''option java_outer_classname = "«pkg.name.split("\\.").last.toFirstUpper»Proto";''').append("\n")
        options.append("option java_multiple_files = true;")
        
        // Build content
        val content = new StringBuilder()
        for (type : pkg.types) {
            content.append(generateProtoType(type)).append("\n\n")
        }
        
        // Process template
        val variables = new HashMap<String, String>()
        variables.put("SOURCE_FILE", "Package: " + pkg.name)
        variables.put("TIMESTAMP", LocalDateTime.now.format(DateTimeFormatter.ISO_LOCAL_DATE_TIME))
        variables.put("PACKAGE", packageDecl)
        variables.put("OPTIONS", options.toString())
        variables.put("IMPORTS", "")
        variables.put("CONTENT", content.toString())
        
        return templateLoader.processTemplate("/templates/proto/file.template", variables)
    }
    
    /**
     * Generate proto definition for a type
     */
    def String generateProtoType(FType type) {
        switch (type) {
            FStructType: generateProtoMessageWithTemplate(type)
            FEnumerationType: generateProtoEnumWithTemplate(type)
            FArrayType: '''// Array type «type.name» will be represented as repeated field'''
            FTypeDef: '''// Typedef «type.name» is an alias and will use the actual type'''
            default: ""
        }
    }
    
    /**
     * Generate proto message using template
     */
    def String generateProtoMessageWithTemplate(FStructType struct) {
        var fieldNumber = 1
        val fields = new StringBuilder()
        
        // Handle inheritance
        if (struct.base !== null) {
            fields.append("    // Inherited from ").append(struct.base.name).append("\n")
            fields.append("    ").append(struct.base.name).append(" base = ").append(fieldNumber++).append(";\n")
        }
        
        // Generate fields
        for (field : struct.elements) {
            fields.append(generateProtoFieldWithTemplate(field, fieldNumber++))
        }
        
        // Process template
        val variables = new HashMap<String, String>()
        variables.put("COMMENT", if (struct.comment !== null) generateProtoComment(struct.comment) else "")
        variables.put("MESSAGE_NAME", struct.name)
        variables.put("FIELDS", fields.toString())
        
        return templateLoader.processTemplate("/templates/proto/message.template", variables)
    }
    
    /**
     * Generate proto field using template
     */
    def String generateProtoFieldWithTemplate(FField field, int fieldNumber) {
        // Add null safety check
        val fieldName = if (field.name !== null) field.name else "field_" + fieldNumber
        
        // Get the type, handling potential null/unresolved references
        var fieldType = "int32" // Better default than bytes
        if (field.type !== null) {
            try {
                fieldType = mapToProtoType(field.type)
                // Double-check we didn't get bytes as a fallback
                if (fieldType == "bytes") {
                    // Try to extract type name directly from the field's type node
                    val node = NodeModelUtils.findActualNodeFor(field.type)
                    if (node !== null) {
                        val leaves = node.leafNodes
                        if (leaves !== null && !leaves.empty) {
                            val typeName = leaves.head.text.trim
                            if (!typeName.empty) {
                                val mappedType = mapBasicToProtoByName(typeName, field.type)
                                if (mappedType != "bytes") {
                                    fieldType = mappedType
                                }
                            }
                        }
                    }
                }
            } catch (Exception e) {
                System.err.println("Warning: Failed to map proto type for field " + fieldName + ": " + e.message)
                fieldType = "int32"
            }
        }
        
        val variables = new HashMap<String, String>()
        variables.put("FIELD_COMMENT", if (field.comment !== null) generateProtoComment(field.comment) else "")
        variables.put("REPEATED", if (field.array) "repeated " else "")
        variables.put("FIELD_TYPE", fieldType)
        variables.put("FIELD_NAME", toSnakeCase(fieldName))
        variables.put("FIELD_NUMBER", String.valueOf(fieldNumber))
        
        return templateLoader.processTemplate("/templates/proto/field.template", variables)
    }
    
    /**
     * Generate proto enum using template
     */
    def String generateProtoEnumWithTemplate(FEnumerationType enumType) {
        val enumerators = new StringBuilder()
        
        // Check if we have a zero value
        val hasZero = enumType.enumerators.exists[e | 
            e.value !== null && expressionToInt(e.value) == 0
        ]
        
        // Add UNSPECIFIED if no zero value
        if (!hasZero) {
            enumerators.append("    ").append(enumType.name.toUpperCase).append("_UNSPECIFIED = 0;\n")
        }
        
        // Add enumerators
        for (enumerator : enumType.enumerators) {
            enumerators.append("    ").append(enumerator.name)
            if (enumerator.value !== null) {
                enumerators.append(" = ").append(expressionToInt(enumerator.value))
            } else {
                val index = enumType.enumerators.indexOf(enumerator)
                enumerators.append(" = ").append(index + (if(hasZero) 0 else 1))
            }
            enumerators.append(";\n")
        }
        
        // Process template
        val variables = new HashMap<String, String>()
        variables.put("COMMENT", if (enumType.comment !== null) generateProtoComment(enumType.comment) else "")
        variables.put("ENUM_NAME", enumType.name)
        variables.put("ENUMERATORS", enumerators.toString())
        
        return templateLoader.processTemplate("/templates/proto/enum.template", variables)
    }
    
    /**
     * Generate proto comment
     */
    def String generateProtoComment(FAnnotationBlock comment) {
        if (comment === null || comment.elements.empty) {
            return ""
        }
        
        val sb = new StringBuilder()
        sb.append("// ")
        for (annotation : comment.elements) {
            sb.append(annotation.rawText).append(" ")
        }
        return sb.toString().trim()
    }
    
    /**
     * Map FTypeRef to Protobuf type
     */
    def String mapToProtoType(FTypeRef typeRef) {
        if (typeRef === null) {
            return "int32" // Better default than bytes
        }
        
        val refType = typeRef.predefined
        
        if (refType !== null) {
            if (refType instanceof FBasicTypeId) {
                return mapBasicToProto(refType, typeRef)
            }
            
            if (refType instanceof FType) {
                return getTypeName(refType)
            }
        }
        
        // If the reference is null or unresolved, extract the type name from the AST
        try {
            val node = NodeModelUtils.findActualNodeFor(typeRef)
            if (node !== null) {
                // Get the first leaf node which should contain the type name
                val leaves = node.leafNodes
                if (leaves !== null && !leaves.empty) {
                    val firstLeaf = leaves.head
                    if (firstLeaf !== null && firstLeaf.text !== null) {
                        val typeName = firstLeaf.text.trim
                        if (!typeName.empty && !typeName.equals("{")) {
                            // Map the type name directly
                            return mapBasicToProtoByName(typeName, typeRef)
                        }
                    }
                }
            }
        } catch (Exception e) {
            System.err.println("Warning: Failed to extract type name from FTypeRef: " + e.message)
        }
        
        return "int32" // Better default than bytes
    }
    
    /**
     * Get the unresolved type name from a FTypeRef
     */
    def String getUnresolvedTypeName(FTypeRef typeRef) {
        try {
            // Try to get it from the node model
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
    def String mapBasicToProtoByName(String typeName, FTypeRef typeRef) {
        val name = typeName.toLowerCase
        
        switch (name) {
            case "bool": return "bool"
            case "boolean": return "bool"
            case "int8": return "int32"
            case "int16": return "int32"
            case "int32": return "int32"
            case "int": return "int32"
            case "uint8": return "uint32"
            case "uint16": return "uint32"
            case "uint32": return "uint32"
            case "uint": return "uint32"
            case "int64": return "int64"
            case "long": return "int64"
            case "uint64": return "uint64"
            case "ulong": return "uint64"
            case "float": return "float"
            case "float32": return "float"
            case "double": return "double"
            case "float64": return "double"
            case "string": return "string"
            case "byte": return "bytes"
            case "timestamp": return "bytes"  // timestamp as bytes
            default: {
                // Check bit length
                if (typeRef !== null && typeRef.bitLen > 0) {
                    if (typeRef.bitLen <= 32) return "int32"
                    if (typeRef.bitLen <= 64) return "int64"
                }
                // For unknown types, use the type name as-is (might be a message type)
                return typeName
            }
        }
    }
    
    /**
     * Map basic type to proto type
     */
    def String mapBasicToProto(FBasicTypeId basicType, FTypeRef typeRef) {
        val name = basicType.name.toLowerCase
        
        switch (name) {
            case "bool": return "bool"
            case "boolean": return "bool"
            case "int8": return "int32"
            case "int16": return "int32"
            case "int32": return "int32"
            case "int": return "int32"
            case "uint8": return "uint32"
            case "uint16": return "uint32"
            case "uint32": return "uint32"
            case "uint": return "uint32"
            case "int64": return "int64"
            case "long": return "int64"
            case "uint64": return "uint64"
            case "ulong": return "uint64"
            case "float": return "float"
            case "float32": return "float"
            case "double": return "double"
            case "float64": return "double"
            case "string": return "string"  // Handle both "string" and "String"
            case "byte": return "bytes"
            case "timestamp": return "bytes"  // timestamp as bytes
            default: {
                // Check category
                if (basicType.category == Category.STRING) {
                    return "string"
                }
                
                // Check bit length
                if (typeRef !== null && typeRef.bitLen > 0) {
                    if (typeRef.bitLen <= 32) return "int32"
                    if (typeRef.bitLen <= 64) return "int64"
                }
                
                return "bytes"
            }
        }
    }
    
    /**
     * Get type name
     */
    def String getTypeName(FType type) {
        switch (type) {
            FStructType: type.name
            FEnumerationType: type.name
            FArrayType: type.name
            FTypeDef: type.name
            default: "Unknown"
        }
    }
    
    /**
     * Convert expression to integer
     */
    def int expressionToInt(Expression expr) {
        switch (expr) {
            LiteralExpression: {
                val literal = expr.value
                if (literal instanceof IntLiteral) {
                    return literal.value
                }
                return 0
            }
            default: return 0
        }
    }
    
    /**
     * Convert to snake_case
     */
    def String toSnakeCase(String camelCase) {
        if (camelCase === null || camelCase.empty) {
            return ""
        }
        return camelCase.replaceAll("([a-z])([A-Z])", "$1_$2").toLowerCase
    }
    
    /**
     * Generate binary descriptor set
     */
    def byte[] generateDescriptorSet(Model model) {
        val fileBuilder = FileDescriptorProto.newBuilder()
        
        // Set file properties
        fileBuilder.setName("datatypes.proto")
        fileBuilder.setSyntax("proto3")
        fileBuilder.setPackage("datatypes")
        
        // Set options
        val optionsBuilder = FileOptions.newBuilder()
        optionsBuilder.setJavaPackage("com.generated.datatypes")
        optionsBuilder.setJavaOuterClassname("DataTypesProto")
        optionsBuilder.setJavaMultipleFiles(true)
        optionsBuilder.setOptimizeFor(FileOptions.OptimizeMode.SPEED)
        fileBuilder.setOptions(optionsBuilder.build())
        
        // Add types
        for (type : model.types) {
            addTypeToDescriptor(type, fileBuilder)
        }
        
        // Build the FileDescriptorSet
        val setBuilder = FileDescriptorSet.newBuilder()
        setBuilder.addFile(fileBuilder.build())
        
        // Add package descriptors
        for (pkg : model.packages) {
            val pkgFileBuilder = FileDescriptorProto.newBuilder()
            pkgFileBuilder.setName(pkg.name.replace(".", "_") + ".proto")
            pkgFileBuilder.setSyntax("proto3")
            pkgFileBuilder.setPackage(pkg.name.replace(".", "_"))
            
            for (type : pkg.types) {
                addTypeToDescriptor(type, pkgFileBuilder)
            }
            
            setBuilder.addFile(pkgFileBuilder.build())
        }
        
        return setBuilder.build().toByteArray()
    }
    
    /**
     * Add type to descriptor builder
     */
    def void addTypeToDescriptor(FType type, FileDescriptorProto.Builder fileBuilder) {
        switch (type) {
            FStructType: fileBuilder.addMessageType(buildMessageDescriptor(type))
            FEnumerationType: fileBuilder.addEnumType(buildEnumDescriptor(type))
        }
    }
    
    /**
     * Build message descriptor for struct
     */
    def DescriptorProto buildMessageDescriptor(FStructType struct) {
        val builder = DescriptorProto.newBuilder()
        builder.setName(struct.name)
        
        var fieldNumber = 1
        
        // Handle inheritance
        if (struct.base !== null) {
            builder.addField(FieldDescriptorProto.newBuilder()
                .setName("base")
                .setNumber(fieldNumber++)
                .setType(FieldDescriptorProto.Type.TYPE_MESSAGE)
                .setTypeName(struct.base.name)
                .setLabel(FieldDescriptorProto.Label.LABEL_OPTIONAL)
                .build())
        }
        
        // Add fields
        for (field : struct.elements) {
            val fieldBuilder = FieldDescriptorProto.newBuilder()
            val fieldName = if (field.name !== null) field.name else "field_" + fieldNumber
            fieldBuilder.setName(toSnakeCase(fieldName))
            fieldBuilder.setNumber(fieldNumber++)
            
            if (field.array) {
                fieldBuilder.setLabel(FieldDescriptorProto.Label.LABEL_REPEATED)
            } else {
                fieldBuilder.setLabel(FieldDescriptorProto.Label.LABEL_OPTIONAL)
            }
            
            // Set type based on field type
            setFieldType(fieldBuilder, field.type)
            
            builder.addField(fieldBuilder.build())
        }
        
        return builder.build()
    }
    
    /**
     * Set field type in descriptor
     */
    def void setFieldType(FieldDescriptorProto.Builder fieldBuilder, FTypeRef typeRef) {
        if (typeRef === null) {
            fieldBuilder.setType(FieldDescriptorProto.Type.TYPE_INT32)
            return
        }
        
        val refType = typeRef.predefined
        
        if (refType !== null) {
            if (refType instanceof FBasicTypeId) {
                val protoType = mapBasicToProtoType(refType, typeRef)
                fieldBuilder.setType(protoType)
            } else if (refType instanceof FType) {
                fieldBuilder.setType(FieldDescriptorProto.Type.TYPE_MESSAGE)
                fieldBuilder.setTypeName(getTypeName(refType))
            } else {
                // Try to resolve by name for basic types
                val typeName = getTypeNameFromRef(refType)
                if (typeName !== null) {
                    val protoType = mapBasicToProtoTypeByName(typeName, typeRef)
                    fieldBuilder.setType(protoType)
                } else {
                    fieldBuilder.setType(FieldDescriptorProto.Type.TYPE_INT32)
                }
            }
        } else {
            // If the reference is null or unresolved, extract the type name from the AST
            try {
                val node = NodeModelUtils.findActualNodeFor(typeRef)
                if (node !== null) {
                    val leaves = node.leafNodes
                    if (leaves !== null && !leaves.empty) {
                        val firstLeaf = leaves.head
                        if (firstLeaf !== null && firstLeaf.text !== null) {
                            val typeName = firstLeaf.text.trim
                            if (!typeName.empty && !typeName.equals("{")) {
                                val protoType = mapBasicToProtoTypeByName(typeName, typeRef)
                                fieldBuilder.setType(protoType)
                                return
                            }
                        }
                    }
                }
            } catch (Exception e) {
                System.err.println("Warning: Failed to set field type: " + e.message)
            }
            fieldBuilder.setType(FieldDescriptorProto.Type.TYPE_INT32)
        }
    }
    
    /**
     * Map basic type to proto descriptor type by name
     */
    def FieldDescriptorProto.Type mapBasicToProtoTypeByName(String typeName, FTypeRef typeRef) {
        val name = typeName.toLowerCase
        
        switch (name) {
            case "bool": return FieldDescriptorProto.Type.TYPE_BOOL
            case "boolean": return FieldDescriptorProto.Type.TYPE_BOOL
            case "int8": return FieldDescriptorProto.Type.TYPE_INT32
            case "int16": return FieldDescriptorProto.Type.TYPE_INT32
            case "int32": return FieldDescriptorProto.Type.TYPE_INT32
            case "int": return FieldDescriptorProto.Type.TYPE_INT32
            case "uint8": return FieldDescriptorProto.Type.TYPE_UINT32
            case "uint16": return FieldDescriptorProto.Type.TYPE_UINT32
            case "uint32": return FieldDescriptorProto.Type.TYPE_UINT32
            case "uint": return FieldDescriptorProto.Type.TYPE_UINT32
            case "int64": return FieldDescriptorProto.Type.TYPE_INT64
            case "long": return FieldDescriptorProto.Type.TYPE_INT64
            case "uint64": return FieldDescriptorProto.Type.TYPE_UINT64
            case "ulong": return FieldDescriptorProto.Type.TYPE_UINT64
            case "float": return FieldDescriptorProto.Type.TYPE_FLOAT
            case "float32": return FieldDescriptorProto.Type.TYPE_FLOAT
            case "double": return FieldDescriptorProto.Type.TYPE_DOUBLE
            case "float64": return FieldDescriptorProto.Type.TYPE_DOUBLE
            case "string": return FieldDescriptorProto.Type.TYPE_STRING
            case "byte": return FieldDescriptorProto.Type.TYPE_BYTES
            case "timestamp": return FieldDescriptorProto.Type.TYPE_BYTES
            default: return FieldDescriptorProto.Type.TYPE_MESSAGE  // Assume it's a message type
        }
    }
    
    /**
     * Map basic type to proto descriptor type
     */
    def FieldDescriptorProto.Type mapBasicToProtoType(FBasicTypeId basicType, FTypeRef typeRef) {
        val name = basicType.name.toLowerCase
        
        switch (name) {
            case "bool": return FieldDescriptorProto.Type.TYPE_BOOL
            case "boolean": return FieldDescriptorProto.Type.TYPE_BOOL
            case "int8": return FieldDescriptorProto.Type.TYPE_INT32
            case "int16": return FieldDescriptorProto.Type.TYPE_INT32
            case "int32": return FieldDescriptorProto.Type.TYPE_INT32
            case "int": return FieldDescriptorProto.Type.TYPE_INT32
            case "uint8": return FieldDescriptorProto.Type.TYPE_UINT32
            case "uint16": return FieldDescriptorProto.Type.TYPE_UINT32
            case "uint32": return FieldDescriptorProto.Type.TYPE_UINT32
            case "uint": return FieldDescriptorProto.Type.TYPE_UINT32
            case "int64": return FieldDescriptorProto.Type.TYPE_INT64
            case "long": return FieldDescriptorProto.Type.TYPE_INT64
            case "uint64": return FieldDescriptorProto.Type.TYPE_UINT64
            case "ulong": return FieldDescriptorProto.Type.TYPE_UINT64
            case "float": return FieldDescriptorProto.Type.TYPE_FLOAT
            case "float32": return FieldDescriptorProto.Type.TYPE_FLOAT
            case "double": return FieldDescriptorProto.Type.TYPE_DOUBLE
            case "float64": return FieldDescriptorProto.Type.TYPE_DOUBLE
            case "string": return FieldDescriptorProto.Type.TYPE_STRING  // Handle both "string" and "String"
            case "byte": return FieldDescriptorProto.Type.TYPE_BYTES
            case "timestamp": return FieldDescriptorProto.Type.TYPE_BYTES
            default: {
                if (basicType.category == Category.STRING) {
                    return FieldDescriptorProto.Type.TYPE_STRING
                }
                return FieldDescriptorProto.Type.TYPE_BYTES
            }
        }
    }
    
    /**
     * Build enum descriptor
     */
    def EnumDescriptorProto buildEnumDescriptor(FEnumerationType enumType) {
        val builder = EnumDescriptorProto.newBuilder()
        builder.setName(enumType.name)
        
        // Check if we have a zero value
        val hasZero = enumType.enumerators.exists[e | 
            e.value !== null && expressionToInt(e.value) == 0
        ]
        
        // Add UNSPECIFIED if no zero value
        if (!hasZero) {
            builder.addValue(EnumValueDescriptorProto.newBuilder()
                .setName(enumType.name.toUpperCase + "_UNSPECIFIED")
                .setNumber(0)
                .build())
        }
        
        // Add enumerators
        for (enumerator : enumType.enumerators) {
            val value = if (enumerator.value !== null) {
                expressionToInt(enumerator.value)
            } else {
                enumType.enumerators.indexOf(enumerator) + (if(hasZero) 0 else 1)
            }
            
            builder.addValue(EnumValueDescriptorProto.newBuilder()
                .setName(enumerator.name)
                .setNumber(value)
                .build())
        }
        
        return builder.build()
    }
    
    /**
     * Generate descriptor info
     */
    def CharSequence generateDescriptorInfo(Model model, byte[] descriptorBytes) '''
        # Protobuf Descriptor Information
        # Generated by DataType DSL Generator
        
        ## Binary Descriptor File: datatypes.desc
        - Size: «descriptorBytes.length» bytes
        - Format: Protocol Buffers FileDescriptorSet
        - Encoding: Binary
        
        ## Contents:
        - Packages: «model.packages.size»
        - Top-level types: «model.types.size»
        - Total structs: «model.types.filter(FStructType).size + model.packages.flatMap[types].filter(FStructType).size»
        - Total enums: «model.types.filter(FEnumerationType).size + model.packages.flatMap[types].filter(FEnumerationType).size»
        
        ## Usage:
        To inspect the contents:
        ```bash
        protoc --decode_raw < datatypes.desc
        ```
        
        To decode with the schema:
        ```bash
        protoc --decode=google.protobuf.FileDescriptorSet /usr/include/google/protobuf/descriptor.proto < datatypes.desc
        ```
    '''
}

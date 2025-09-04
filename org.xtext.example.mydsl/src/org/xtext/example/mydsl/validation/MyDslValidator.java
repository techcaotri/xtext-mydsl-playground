package org.xtext.example.mydsl.validation;

import org.eclipse.xtext.validation.Check;
import org.eclipse.emf.ecore.EObject;
import org.eclipse.emf.ecore.EStructuralFeature;
import org.xtext.example.mydsl.myDsl.*;
import java.util.HashSet;
import java.util.Set;
import java.util.List;
import java.util.ArrayList;

/**
 * Custom validation rules for DataType DSL
 * Updated for latest grammar with FStructType, FEnumerationType, etc.
 */
public class MyDslValidator extends AbstractMyDslValidator {
    
    // Issue codes
    public static final String DUPLICATE_TYPE_NAME = "duplicateTypeName";
    public static final String DUPLICATE_FIELD_NAME = "duplicateFieldName";
    public static final String DUPLICATE_ENUM_VALUE = "duplicateEnumValue";
    public static final String INVALID_ENUM_VALUE = "invalidEnumValue";
    public static final String INVALID_FIELD_NAME = "invalidFieldName";
    public static final String CIRCULAR_INHERITANCE = "circularInheritance";
    public static final String INVALID_ARRAY_SIZE = "invalidArraySize";
    public static final String MISSING_ENUM_ZERO = "missingEnumZero";
    public static final String INVALID_TYPE_NAME = "invalidTypeName";
    public static final String UNDEFINED_TYPE = "undefinedType";
    public static final String INVALID_BIT_LENGTH = "invalidBitLength";
    
    /**
     * Check for duplicate type names within the same scope
     */
    @Check
    public void checkDuplicateTypeNames(Model model) {
        Set<String> globalTypeNames = new HashSet<>();
        
        // Check top-level types
        for (FType type : model.getTypes()) {
            String name = getTypeName(type);
            if (name != null && !globalTypeNames.add(name)) {
                error("Duplicate type name: " + name, 
                      type, 
                      getTypeNameFeature(type), 
                      DUPLICATE_TYPE_NAME);
            }
        }
        
        // Check types within packages (use fully qualified name to avoid ambiguity)
        for (org.xtext.example.mydsl.myDsl.Package pkg : model.getPackages()) {
            Set<String> packageTypeNames = new HashSet<>();
            for (FType type : pkg.getTypes()) {
                String name = getTypeName(type);
                if (name != null && !packageTypeNames.add(name)) {
                    error("Duplicate type name in package " + pkg.getName() + ": " + name,
                          type,
                          getTypeNameFeature(type),
                          DUPLICATE_TYPE_NAME);
                }
            }
        }
    }
    
    /**
     * Check for duplicate primitive type names
     */
    @Check
    public void checkDuplicatePrimitiveTypes(PrimitiveDataTypes primitives) {
        Set<String> typeNames = new HashSet<>();
        for (FBasicTypeId basicType : primitives.getDataType()) {
            if (!typeNames.add(basicType.getName())) {
                error("Duplicate primitive type name: " + basicType.getName(),
                      basicType,
                      basicType.eClass().getEStructuralFeature("name"),
                      DUPLICATE_TYPE_NAME);
            }
        }
    }
    
    /**
     * Check that struct field names are unique (including inherited fields)
     */
    @Check
    public void checkUniqueFieldNames(FStructType struct) {
        Set<String> fieldNames = new HashSet<>();
        
        // Collect inherited field names
        if (struct.getBase() != null) {
            collectFieldNames(struct.getBase(), fieldNames);
        }
        
        // Check current struct's fields
        for (FField field : struct.getElements()) {
            if (!fieldNames.add(field.getName())) {
                error("Duplicate field name: " + field.getName(),
                      field,
                      field.eClass().getEStructuralFeature("name"),
                      DUPLICATE_FIELD_NAME);
            }
        }
    }
    
    /**
     * Check for circular inheritance in structs
     */
    @Check
    public void checkCircularInheritance(FStructType struct) {
        if (struct.getBase() != null) {
            Set<FStructType> visited = new HashSet<>();
            visited.add(struct);
            
            FStructType current = struct.getBase();
            while (current != null) {
                if (!visited.add(current)) {
                    error("Circular inheritance detected",
                          struct,
                          struct.eClass().getEStructuralFeature("base"),
                          CIRCULAR_INHERITANCE);
                    break;
                }
                current = current.getBase();
            }
        }
    }
    
    /**
     * Check that enum values are unique within an enumeration
     */
    @Check
    public void checkUniqueEnumValues(FEnumerationType enumType) {
        Set<Integer> values = new HashSet<>();
        Set<String> names = new HashSet<>();
        
        for (FEnumerator enumerator : enumType.getEnumerators()) {
            // Check name uniqueness
            if (!names.add(enumerator.getName())) {
                error("Duplicate enumerator name: " + enumerator.getName(),
                      enumerator,
                      enumerator.eClass().getEStructuralFeature("name"),
                      DUPLICATE_TYPE_NAME);
            }
            
            // Check value uniqueness if specified
            if (enumerator.getValue() != null) {
                int value = evaluateExpression(enumerator.getValue());
                if (!values.add(value)) {
                    warning("Duplicate enum value: " + value,
                            enumerator,
                            enumerator.eClass().getEStructuralFeature("value"),
                            DUPLICATE_ENUM_VALUE);
                }
            }
        }
    }
    
    /**
     * Check that enums have a zero value (required for Protobuf)
     */
    @Check
    public void checkEnumHasZeroValue(FEnumerationType enumType) {
        boolean hasZero = false;
        
        for (FEnumerator enumerator : enumType.getEnumerators()) {
            if (enumerator.getValue() != null) {
                int value = evaluateExpression(enumerator.getValue());
                if (value == 0) {
                    hasZero = true;
                    break;
                }
            } else if (enumType.getEnumerators().indexOf(enumerator) == 0) {
                // First enumerator without explicit value defaults to 0
                hasZero = true;
                break;
            }
        }
        
        if (!hasZero) {
            warning("Enumeration should have a value with 0 for Protobuf compatibility",
                    enumType,
                    enumType.eClass().getEStructuralFeature("name"),
                    MISSING_ENUM_ZERO);
        }
    }
    
    /**
     * Check that array sizes are positive
     */
    @Check
    public void checkArraySize(FField field) {
        if (field.isArray() && field.getSize() <= 0) {
            error("Array size must be positive",
                  field,
                  field.eClass().getEStructuralFeature("size"),
                  INVALID_ARRAY_SIZE);
        }
        
        if (field.isArray() && field.getSize() > 10000) {
            warning("Large array size: " + field.getSize() + ". Consider using dynamic arrays.",
                    field,
                    field.eClass().getEStructuralFeature("size"),
                    INVALID_ARRAY_SIZE);
        }
    }
    
    /**
     * Check that field names follow naming conventions
     */
    @Check
    public void checkFieldNamingConvention(FField field) {
        String name = field.getName();
        if (name != null) {
            if (!name.matches("[a-z][a-zA-Z0-9_]*")) {
                warning("Field name should start with lowercase letter: " + name,
                        field,
                        field.eClass().getEStructuralFeature("name"),
                        INVALID_FIELD_NAME);
            }
            
            if (name.length() > 100) {
                warning("Field name is too long: " + name,
                        field,
                        field.eClass().getEStructuralFeature("name"),
                        INVALID_FIELD_NAME);
            }
        }
    }
    
    /**
     * Check that type names follow naming conventions
     */
    @Check
    public void checkStructNamingConvention(FStructType struct) {
        checkTypeNaming(struct.getName(), struct, struct.eClass().getEStructuralFeature("name"));
    }
    
    @Check
    public void checkEnumNamingConvention(FEnumerationType enumType) {
        checkTypeNaming(enumType.getName(), enumType, enumType.eClass().getEStructuralFeature("name"));
    }
    
    @Check
    public void checkArrayNamingConvention(FArrayType array) {
        checkTypeNaming(array.getName(), array, array.eClass().getEStructuralFeature("name"));
    }
    
    @Check
    public void checkTypedefNamingConvention(FTypeDef typedef) {
        checkTypeNaming(typedef.getName(), typedef, typedef.eClass().getEStructuralFeature("name"));
    }
    
    private void checkTypeNaming(String name, EObject source, EStructuralFeature feature) {
        if (name != null) {
            if (!name.matches("[A-Z][a-zA-Z0-9_]*")) {
                warning("Type name should start with uppercase letter: " + name,
                        source,
                        feature,
                        INVALID_TYPE_NAME);
            }
            
            if (name.length() > 100) {
                warning("Type name is too long: " + name,
                        source,
                        feature,
                        INVALID_TYPE_NAME);
            }
        }
    }
    
    /**
     * Check that enumerator names follow naming conventions (UPPER_CASE)
     */
    @Check
    public void checkEnumeratorNaming(FEnumerator enumerator) {
        String name = enumerator.getName();
        if (name != null && !name.matches("[A-Z][A-Z0-9_]*")) {
            warning("Enumerator name should be in UPPER_CASE: " + name,
                    enumerator,
                    enumerator.eClass().getEStructuralFeature("name"));
        }
    }
    
    /**
     * Check that enum values are in valid range
     */
    @Check
    public void checkEnumValueRange(FEnumerator enumerator) {
        if (enumerator.getValue() != null) {
            int value = evaluateExpression(enumerator.getValue());
            if (value < 0) {
                warning("Enum value should be non-negative for better Protobuf compatibility: " + value,
                        enumerator,
                        enumerator.eClass().getEStructuralFeature("value"),
                        INVALID_ENUM_VALUE);
            }
            if (value > 65535) {
                warning("Enum value is very large: " + value + ". Consider using smaller values.",
                        enumerator,
                        enumerator.eClass().getEStructuralFeature("value"),
                        INVALID_ENUM_VALUE);
            }
        }
    }
    
    /**
     * Check that bit length in FTypeRef is valid
     */
    @Check
    public void checkBitLength(FTypeRef typeRef) {
        if (typeRef.getBitLen() > 0) {
            if (typeRef.getBitLen() > 64) {
                error("Bit length cannot exceed 64",
                      typeRef,
                      typeRef.eClass().getEStructuralFeature("bitLen"),
                      INVALID_BIT_LENGTH);
            }
            
            // Check that bit length is used only with appropriate types
            if (typeRef.getPredefined() instanceof FStructType ||
                typeRef.getPredefined() instanceof FEnumerationType) {
                warning("Bit length specification is typically used with primitive types",
                        typeRef,
                        typeRef.eClass().getEStructuralFeature("bitLen"),
                        INVALID_BIT_LENGTH);
            }
        }
    }
    
    /**
     * Check package naming conventions
     */
    @Check
    public void checkPackageNaming(org.xtext.example.mydsl.myDsl.Package pkg) {
        String name = pkg.getName();
        if (name != null) {
            if (!name.matches("[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)*")) {
                warning("Package name should be lowercase with dots: " + name,
                        pkg,
                        pkg.eClass().getEStructuralFeature("name"));
            }
        }
    }
    
    /**
     * Check that array element type is defined
     */
    @Check
    public void checkArrayElementType(FArrayType array) {
        if (array.getElementType() == null) {
            error("Array must specify element type",
                  array,
                  array.eClass().getEStructuralFeature("elementType"),
                  UNDEFINED_TYPE);
        }
    }
    
    /**
     * Check that typedef actual type is defined
     */
    @Check
    public void checkTypedefActualType(FTypeDef typedef) {
        if (typedef.getActualType() == null) {
            error("Typedef must specify actual type",
                  typedef,
                  typedef.eClass().getEStructuralFeature("actualType"),
                  UNDEFINED_TYPE);
        }
    }
    
    /**
     * Validate FBasicTypeId properties
     */
    @Check
    public void checkBasicTypeProperties(FBasicTypeId basicType) {
        // Check length validity
        if (basicType.getLen() > 0) {
            if (basicType.getLen() > 1024) {
                warning("Very large type length: " + basicType.getLen() + " bits",
                        basicType,
                        basicType.eClass().getEStructuralFeature("len"));
            }
            
            // Check that length matches category
            if (basicType.getCategory() == Category.STRING && basicType.getLen() > 0) {
                info("Length specification for string type represents maximum length",
                     basicType,
                     basicType.eClass().getEStructuralFeature("len"));
            }
        }
        
        // Check encoding validity
        if (basicType.getEncoding() == Encoding.IEEE754) {
            if (basicType.getLen() != 32 && basicType.getLen() != 64) {
                warning("IEEE754 encoding typically used with 32 or 64 bit lengths",
                        basicType,
                        basicType.eClass().getEStructuralFeature("encoding"));
            }
        }
    }
    
    /**
     * Helper method to get type name
     */
    private String getTypeName(FType type) {
        if (type instanceof FStructType) {
            return ((FStructType) type).getName();
        } else if (type instanceof FEnumerationType) {
            return ((FEnumerationType) type).getName();
        } else if (type instanceof FArrayType) {
            return ((FArrayType) type).getName();
        } else if (type instanceof FTypeDef) {
            return ((FTypeDef) type).getName();
        }
        return null;
    }
    
    /**
     * Helper method to get type name feature
     */
    private EStructuralFeature getTypeNameFeature(FType type) {
        if (type instanceof FStructType) {
            return type.eClass().getEStructuralFeature("name");
        } else if (type instanceof FEnumerationType) {
            return type.eClass().getEStructuralFeature("name");
        } else if (type instanceof FArrayType) {
            return type.eClass().getEStructuralFeature("name");
        } else if (type instanceof FTypeDef) {
            return type.eClass().getEStructuralFeature("name");
        }
        return null;
    }
    
    /**
     * Helper method to collect field names from a struct and its base
     */
    private void collectFieldNames(FStructType struct, Set<String> fieldNames) {
        if (struct.getBase() != null) {
            collectFieldNames(struct.getBase(), fieldNames);
        }
        for (FField field : struct.getElements()) {
            fieldNames.add(field.getName());
        }
    }
    
    /**
     * Helper method to evaluate simple expressions
     */
    private int evaluateExpression(Expression expr) {
        if (expr instanceof LiteralExpression) {
            Literal literal = ((LiteralExpression) expr).getValue();
            if (literal instanceof IntLiteral) {
                return ((IntLiteral) literal).getValue();
            }
        } else if (expr instanceof IdentifierExpression) {
            // For identifier expressions, return 0 as default
            // In a more complete implementation, we would resolve the identifier
            return 0;
        }
        return 0;
    }
}

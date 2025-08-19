package org.xtext.example.mydsl.scoping;

import org.eclipse.emf.ecore.EObject;
import org.eclipse.emf.ecore.EReference;
import org.eclipse.xtext.naming.QualifiedName;
import org.eclipse.xtext.scoping.IScope;
import org.eclipse.xtext.scoping.Scopes;
import org.eclipse.xtext.scoping.impl.AbstractDeclarativeScopeProvider;
import org.eclipse.xtext.scoping.impl.SimpleScope;
import org.eclipse.xtext.resource.IEObjectDescription;
import org.eclipse.xtext.resource.EObjectDescription;
import org.xtext.example.mydsl.myDsl.*;
import org.xtext.example.mydsl.myDsl.Package;
import java.util.ArrayList;
import java.util.List;

/**
 * This class contains custom scoping description.
 * 
 * See https://www.eclipse.org/Xtext/documentation/303_runtime_concepts.html#scoping
 * on how and when to use it.
 */
public class MyDslScopeProvider extends AbstractMyDslScopeProvider {
    
    /**
     * Provide scope for FTypeRef.predefined references
     * This makes all FBasicTypeId instances and FType instances available globally
     */
    @Override
    public IScope getScope(EObject context, EReference reference) {
        // Check if we're dealing with FTypeRef.predefined
        if (context instanceof FTypeRef && reference.getName().equals("predefined")) {
            return scope_FTypeRef_predefined((FTypeRef) context, reference);
        }
        
        // Check for FStructType.base
        if (context instanceof FStructType && reference.getName().equals("base")) {
            return scope_FStructType_base((FStructType) context, reference);
        }
        
        // Check for FEnumerationType.base
        if (context instanceof FEnumerationType && reference.getName().equals("base")) {
            return scope_FEnumerationType_base((FEnumerationType) context, reference);
        }
        
        // Check for FArrayType.elementType  
        if (context instanceof FArrayType && reference.getName().equals("elementType")) {
            return scope_FArrayType_elementType((FArrayType) context, reference);
        }
        
        // Check for FTypeDef.actualType
        if (context instanceof FTypeDef && reference.getName().equals("actualType")) {
            return scope_FTypeDef_actualType((FTypeDef) context, reference);
        }
        
        // Default to parent implementation
        return super.getScope(context, reference);
    }
    
    /**
     * Provide scope for FTypeRef.predefined references
     */
    protected IScope scope_FTypeRef_predefined(FTypeRef context, EReference ref) {
        // Get the root model
        Model model = getContainerOfType(context, Model.class);
        if (model == null) {
            return IScope.NULLSCOPE;
        }
        
        List<IEObjectDescription> descriptions = new ArrayList<>();
        
        // Add all FBasicTypeId instances from PrimitiveDataTypes definitions
        for (PrimitiveDataTypes primitives : model.getPrimitiveDefinitions()) {
            if (primitives.getDataType() != null) {
                for (FBasicTypeId basicType : primitives.getDataType()) {
                    String name = basicType.getName();
                    if (name != null && !name.isEmpty()) {
                        QualifiedName qn = QualifiedName.create(name);
                        descriptions.add(EObjectDescription.create(qn, basicType));
                    }
                }
            }
        }
        
        // Add all top-level FType instances
        if (model.getTypes() != null) {
            for (FType type : model.getTypes()) {
                String name = getTypeName(type);
                if (name != null && !name.isEmpty()) {
                    QualifiedName qn = QualifiedName.create(name);
                    descriptions.add(EObjectDescription.create(qn, type));
                }
            }
        }
        
        // Add all FType instances from packages with both simple and qualified names
        for (Package pkg : model.getPackages()) {
            if (pkg.getName() != null && !pkg.getName().isEmpty() && pkg.getTypes() != null) {
                for (FType type : pkg.getTypes()) {
                    String typeName = getTypeName(type);
                    if (typeName != null && !typeName.isEmpty()) {
                        // Add with simple name
                        QualifiedName simpleName = QualifiedName.create(typeName);
                        descriptions.add(EObjectDescription.create(simpleName, type));
                        
                        // Add with fully qualified name (package.type)
                        String[] pkgParts = pkg.getName().split("\\.");
                        List<String> segments = new ArrayList<>();
                        for (String part : pkgParts) {
                            if (part != null && !part.isEmpty()) {
                                segments.add(part);
                            }
                        }
                        if (!segments.isEmpty()) {
                            segments.add(typeName);
                            QualifiedName fqn = QualifiedName.create(segments);
                            descriptions.add(EObjectDescription.create(fqn, type));
                        }
                    }
                }
            }
        }
        
        // Create and return the scope
        return new SimpleScope(descriptions);
    }
    
    /**
     * Provide scope for FStructType.base references
     */
    protected IScope scope_FStructType_base(FStructType context, EReference ref) {
        Model model = getContainerOfType(context, Model.class);
        if (model == null) {
            return IScope.NULLSCOPE;
        }
        
        List<FStructType> structs = new ArrayList<>();
        
        // Collect all FStructType instances except the current one
        for (FType type : model.getTypes()) {
            if (type instanceof FStructType && type != context) {
                structs.add((FStructType) type);
            }
        }
        
        // Also collect from packages
        for (Package pkg : model.getPackages()) {
            if (pkg.getTypes() != null) {
                for (FType type : pkg.getTypes()) {
                    if (type instanceof FStructType && type != context) {
                        structs.add((FStructType) type);
                    }
                }
            }
        }
        
        return Scopes.scopeFor(structs);
    }
    
    /**
     * Provide scope for FEnumerationType.base references
     */
    protected IScope scope_FEnumerationType_base(FEnumerationType context, EReference ref) {
        Model model = getContainerOfType(context, Model.class);
        if (model == null) {
            return IScope.NULLSCOPE;
        }
        
        List<FEnumerationType> enums = new ArrayList<>();
        
        // Collect all FEnumerationType instances except the current one
        for (FType type : model.getTypes()) {
            if (type instanceof FEnumerationType && type != context) {
                enums.add((FEnumerationType) type);
            }
        }
        
        // Also collect from packages
        for (Package pkg : model.getPackages()) {
            if (pkg.getTypes() != null) {
                for (FType type : pkg.getTypes()) {
                    if (type instanceof FEnumerationType && type != context) {
                        enums.add((FEnumerationType) type);
                    }
                }
            }
        }
        
        return Scopes.scopeFor(enums);
    }
    
    /**
     * Provide scope for FArrayType.elementType references
     */
    protected IScope scope_FArrayType_elementType(FArrayType context, EReference ref) {
        // Use the same logic as FTypeRef.predefined
        return scope_FTypeRef_predefined(null, ref);
    }
    
    /**
     * Provide scope for FTypeDef.actualType references
     */
    protected IScope scope_FTypeDef_actualType(FTypeDef context, EReference ref) {
        // Use the same logic as FTypeRef.predefined
        return scope_FTypeRef_predefined(null, ref);
    }
    
    /**
     * Get type name from FType
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
     * Helper method to get container of specific type
     */
    @SuppressWarnings("unchecked")
    private static <T extends EObject> T getContainerOfType(EObject obj, Class<T> type) {
        if (obj == null) {
            return null;
        }
        if (type.isInstance(obj)) {
            return (T) obj;
        }
        return getContainerOfType(obj.eContainer(), type);
    }
}

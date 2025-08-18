package org.xtext.example.mydsl.test;

import org.eclipse.emf.common.util.URI;
import org.eclipse.emf.ecore.resource.Resource;
import org.eclipse.emf.ecore.resource.impl.ResourceSetImpl;
import org.eclipse.xtext.generator.GeneratorContext;
import org.eclipse.xtext.generator.IFileSystemAccess2;
import org.eclipse.xtext.generator.IGeneratorContext;
import org.eclipse.xtext.generator.InMemoryFileSystemAccess;
import org.eclipse.xtext.generator.JavaIoFileSystemAccess;
import org.eclipse.xtext.generator.OutputConfiguration;
import org.eclipse.xtext.resource.IResourceServiceProvider;
import org.xtext.example.mydsl.MyDslStandaloneSetup;
import org.xtext.example.mydsl.myDsl.*;
import com.google.inject.Injector;

import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.lang.reflect.Field;
import java.util.HashMap;
import java.util.Map;

/**
 * Test runner for DataType DSL Generator
 * Updated for latest MyDsl.xtext grammar with FStructType, FEnumerationType, etc.
 */
public class DataTypeGeneratorTest {
    
    public static void main(String[] args) {
        if (args.length == 0) {
            System.out.println("Usage: DataTypeGeneratorTest <input.mydsl>");
            System.out.println("Example: DataTypeGeneratorTest sample.mydsl");
            System.exit(1);
        }
        
        String inputFile = args[0];
        System.out.println("=== DataType DSL Generator Test ===");
        System.out.println("Input: " + inputFile);
        System.out.println();
        
        try {
            // Initialize Xtext
            System.out.println("Initializing Xtext for DataType DSL...");
            MyDslStandaloneSetup setup = new MyDslStandaloneSetup();
            Injector injector = setup.createInjectorAndDoEMFRegistration();
            
            // Load the model
            System.out.println("Loading model from: " + inputFile);
            ResourceSetImpl resourceSet = injector.getInstance(ResourceSetImpl.class);
            
            File file = new File(inputFile);
            if (!file.exists()) {
                System.err.println("ERROR: File not found: " + file.getAbsolutePath());
                System.exit(1);
            }
            
            URI fileURI = URI.createFileURI(file.getAbsolutePath());
            Resource resource = resourceSet.getResource(fileURI, true);
            
            // Check for errors
            if (!resource.getErrors().isEmpty()) {
                System.err.println("ERROR: Model contains errors:");
                resource.getErrors().forEach(error -> 
                    System.err.println("  Line " + error.getLine() + ": " + error.getMessage())
                );
                System.exit(1);
            }
            
            // Check model content
            if (resource.getContents().isEmpty()) {
                System.err.println("ERROR: Model is empty");
                System.exit(1);
            }
            
            Model model = (Model) resource.getContents().get(0);
            
            // Print model statistics
            printModelStatistics(model);
            
            // Generate code
            System.out.println("\n=== Generating Code ===");
            
            // Try different file system access methods
            boolean success = false;
            
            // Method 1: Try with JavaIoFileSystemAccess
            try {
                System.out.println("Attempting generation with JavaIoFileSystemAccess...");
                success = generateWithJavaIo(resource, injector);
            } catch (Exception e) {
                System.out.println("JavaIoFileSystemAccess failed: " + e.getMessage());
            }
            
            // Method 2: Use InMemoryFileSystemAccess as fallback
            if (!success) {
                System.out.println("\nFalling back to InMemoryFileSystemAccess...");
                generateWithInMemory(resource, injector);
            }
            
            System.out.println("\n=== Generation Complete ===");
            
            File outputDir = new File("generated");
            System.out.println("Output directory: " + outputDir.getAbsolutePath());
            
            // Show generated structure
            if (outputDir.exists() && outputDir.isDirectory()) {
                System.out.println("\nGenerated structure:");
                showDirectoryTree(outputDir, "");
            }
            
        } catch (Exception e) {
            System.err.println("ERROR: " + e.getMessage());
            e.printStackTrace();
            System.exit(1);
        }
    }
    
    /**
     * Print model statistics for the DataType DSL
     */
    private static void printModelStatistics(Model model) {
        System.out.println("\n=== Model Statistics ===");
        
        // Count primitive definitions
        int primitiveCount = 0;
        for (PrimitiveDataTypes pdt : model.getPrimitiveDefinitions()) {
            primitiveCount += pdt.getDataType().size();
        }
        System.out.println("Primitive Type Definitions: " + primitiveCount);
        
        // Packages
        System.out.println("Packages: " + model.getPackages().size());
        
        // Top-level types
        System.out.println("Top-level Types: " + model.getTypes().size());
        
        // Count by type
        int structCount = 0;
        int enumCount = 0;
        int arrayCount = 0;
        int typedefCount = 0;
        
        for (FType type : model.getTypes()) {
            if (type instanceof FStructType) structCount++;
            else if (type instanceof FEnumerationType) enumCount++;
            else if (type instanceof FArrayType) arrayCount++;
            else if (type instanceof FTypeDef) typedefCount++;
        }
        
        System.out.println("  - Structs: " + structCount);
        System.out.println("  - Enums: " + enumCount);
        System.out.println("  - Arrays: " + arrayCount);
        System.out.println("  - Typedefs: " + typedefCount);
        
        // Package details
        if (!model.getPackages().isEmpty()) {
            System.out.println("\nPackages:");
            for (var pkg : model.getPackages()) {
                int pkgStructs = 0;
                int pkgEnums = 0;
                int pkgArrays = 0;
                int pkgTypedefs = 0;
                
                for (FType type : pkg.getTypes()) {
                    if (type instanceof FStructType) pkgStructs++;
                    else if (type instanceof FEnumerationType) pkgEnums++;
                    else if (type instanceof FArrayType) pkgArrays++;
                    else if (type instanceof FTypeDef) pkgTypedefs++;
                }
                
                System.out.println("  - " + pkg.getName() + ":");
                System.out.println("      Structs: " + pkgStructs);
                System.out.println("      Enums: " + pkgEnums);
                System.out.println("      Arrays: " + pkgArrays);
                System.out.println("      Typedefs: " + pkgTypedefs);
            }
        }
        
        // Print some details about structs
        System.out.println("\nStruct Details:");
        for (FType type : model.getTypes()) {
            if (type instanceof FStructType) {
                FStructType struct = (FStructType) type;
                System.out.println("  - " + struct.getName() + 
                                 " (fields: " + struct.getElements().size() +
                                 (struct.getBase() != null ? ", extends: " + struct.getBase().getName() : "") + ")");
            }
        }
    }
    
    /**
     * Generate with JavaIoFileSystemAccess
     */
    private static boolean generateWithJavaIo(Resource resource, Injector injector) {
        try {
            // Get the registry from injector
            IResourceServiceProvider.Registry registry = 
                injector.getInstance(IResourceServiceProvider.Registry.class);
            
            // Create JavaIoFileSystemAccess
            JavaIoFileSystemAccess fsa = new JavaIoFileSystemAccess();
            
            // Set the registry using reflection
            try {
                Field registryField = JavaIoFileSystemAccess.class.getDeclaredField("registry");
                registryField.setAccessible(true);
                registryField.set(fsa, registry);
                System.out.println("  Registry successfully set");
            } catch (Exception e) {
                System.out.println("  ERROR: Failed to set registry - " + e.getMessage());
                return false;
            }
            
            // Set output configurations
            OutputConfiguration defaultOutput = new OutputConfiguration("DEFAULT_OUTPUT");
            defaultOutput.setDescription("Default output");
            defaultOutput.setOutputDirectory("./generated");
            defaultOutput.setOverrideExistingResources(true);
            defaultOutput.setCreateOutputDirectory(true);
            defaultOutput.setUseOutputPerSourceFolder(false);
            
            Map<String, OutputConfiguration> outputConfigs = new HashMap<>();
            outputConfigs.put("DEFAULT_OUTPUT", defaultOutput);
            fsa.setOutputConfigurations(outputConfigs);
            
            // Set the output path
            fsa.setOutputPath("generated/");
            
            // Get generator
            Object generator = injector.getInstance(
                org.xtext.example.mydsl.generator.MyDslGenerator.class
            );
            
            // Generate
            IGeneratorContext context = new GeneratorContext();
            generator.getClass().getMethod("doGenerate", Resource.class, IFileSystemAccess2.class, IGeneratorContext.class)
                .invoke(generator, resource, fsa, context);
            
            System.out.println("  Success!");
            return true;
            
        } catch (Exception e) {
            System.err.println("  Failed: " + e.getClass().getSimpleName() + " - " + e.getMessage());
            return false;
        }
    }
    
    /**
     * Generate with InMemoryFileSystemAccess
     */
    private static void generateWithInMemory(Resource resource, Injector injector) throws Exception {
        // Create InMemoryFileSystemAccess
        InMemoryFileSystemAccess fsa = new InMemoryFileSystemAccess();
        IGeneratorContext context = new GeneratorContext();
        
        // Get generator
        var generator = injector.getInstance(
            org.xtext.example.mydsl.generator.MyDslGenerator.class
        );
        
        // Configure generator
        generator.setGenerationOptions(true, true, true); // C++, Protobuf, Binary descriptor
        
        // Generate
        System.out.println("Generating code...");
        generator.doGenerate(resource, fsa, context);
        
        // Write files to disk
        writeFiles(fsa);
    }
    
    /**
     * Write files from InMemoryFileSystemAccess to disk
     */
    private static void writeFiles(InMemoryFileSystemAccess fsa) throws IOException {
        File outputDir = new File("generated");
        if (!outputDir.exists()) {
            outputDir.mkdirs();
        }
        
        Map<String, Object> allFiles = fsa.getAllFiles();
        
        if (allFiles.isEmpty()) {
            // Try getTextFiles() as fallback
            Map<String, CharSequence> textFiles = fsa.getTextFiles();
            if (!textFiles.isEmpty()) {
                for (Map.Entry<String, CharSequence> entry : textFiles.entrySet()) {
                    writeFile(outputDir, entry.getKey(), entry.getValue().toString());
                }
            } else {
                System.out.println("No files generated");
            }
        } else {
            System.out.println("\nWriting " + allFiles.size() + " file(s):");
            
            for (Map.Entry<String, Object> entry : allFiles.entrySet()) {
                String path = entry.getKey();
                Object contentObj = entry.getValue();
                
                if (contentObj instanceof CharSequence) {
                    writeFile(outputDir, path, contentObj.toString());
                } else if (contentObj instanceof byte[]) {
                    // Handle binary files
                    writeBinaryFile(outputDir, path, (byte[]) contentObj);
                } else {
                    writeFile(outputDir, path, String.valueOf(contentObj));
                }
            }
        }
    }
    
    /**
     * Write text file
     */
    private static void writeFile(File outputDir, String path, String content) throws IOException {
        // Clean path
        if (path.startsWith("DEFAULT_OUTPUT")) {
            path = path.substring("DEFAULT_OUTPUT".length());
        }
        
        File outFile = new File(outputDir, path);
        
        // Create parent directories
        File parentDir = outFile.getParentFile();
        if (!parentDir.exists()) {
            parentDir.mkdirs();
        }
        
        // Write file
        try (FileWriter writer = new FileWriter(outFile)) {
            writer.write(content);
            System.out.println("  ✓ " + path);
        }
    }
    
    /**
     * Write binary file
     */
    private static void writeBinaryFile(File outputDir, String path, byte[] data) throws IOException {
        // Clean path
        if (path.startsWith("DEFAULT_OUTPUT")) {
            path = path.substring("DEFAULT_OUTPUT".length());
        }
        
        File outFile = new File(outputDir, path);
        
        // Create parent directories
        File parentDir = outFile.getParentFile();
        if (!parentDir.exists()) {
            parentDir.mkdirs();
        }
        
        // Write binary file
        java.nio.file.Files.write(outFile.toPath(), data);
        System.out.println("  ✓ " + path + " (binary)");
    }
    
    /**
     * Show directory tree
     */
    private static void showDirectoryTree(File dir, String indent) {
        File[] files = dir.listFiles();
        if (files == null) return;
        
        // Sort files
        java.util.Arrays.sort(files, (a, b) -> {
            if (a.isDirectory() && !b.isDirectory()) return -1;
            if (!a.isDirectory() && b.isDirectory()) return 1;
            return a.getName().compareTo(b.getName());
        });
        
        for (int i = 0; i < files.length; i++) {
            File file = files[i];
            boolean isLast = (i == files.length - 1);
            
            String prefix = indent + (isLast ? "└── " : "├── ");
            String childIndent = indent + (isLast ? "    " : "│   ");
            
            if (file.isDirectory()) {
                System.out.println(prefix + file.getName() + "/");
                showDirectoryTree(file, childIndent);
            } else {
                long size = file.length();
                String sizeStr;
                if (size < 1024) {
                    sizeStr = size + " B";
                } else if (size < 1024 * 1024) {
                    sizeStr = (size / 1024) + " KB";
                } else {
                    sizeStr = (size / (1024 * 1024)) + " MB";
                }
                System.out.println(prefix + file.getName() + " (" + sizeStr + ")");
            }
        }
    }
}

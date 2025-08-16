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
import org.xtext.example.mydsl.myDsl.Model;
import com.google.inject.Injector;

import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.lang.reflect.Field;
import java.util.HashMap;
import java.util.Map;

/**
 * Simple generator runner that handles initialization issues
 */
public class SimpleGeneratorRunner {
    
    public static void main(String[] args) {
        if (args.length == 0) {
            System.out.println("Usage: SimpleGeneratorRunner <input.mydsl>");
            System.out.println("Example: SimpleGeneratorRunner test.mydsl");
            System.exit(1);
        }
        
        String inputFile = args[0];
        System.out.println("=== Simple Generator Runner ===");
        System.out.println("Input: " + inputFile);
        System.out.println();
        
        try {
            // Initialize Xtext
            System.out.println("Initializing Xtext...");
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
            System.out.println("Model name: " + model.getName());
            System.out.println("Entities: " + model.getEntities().size());
            System.out.println("Enums: " + model.getEnums().size());
            
            // Option 1: Try with properly initialized JavaIoFileSystemAccess
            boolean success = false;
            try {
                System.out.println("\nAttempting generation with JavaIoFileSystemAccess...");
                success = generateWithJavaIo(resource, injector);
            } catch (Exception e) {
                System.out.println("JavaIoFileSystemAccess failed: " + e.getMessage());
            }
            
            // Option 2: If that fails, use InMemory approach
            if (!success) {
                System.out.println("\nFalling back to InMemoryFileSystemAccess...");
                generateWithInMemory(resource, injector);
            }
            
            System.out.println("\n=== Generation Complete ===");
            
        } catch (Exception e) {
            System.err.println("ERROR: " + e.getMessage());
            e.printStackTrace();
            System.exit(1);
        }
    }
    
    private static boolean generateWithJavaIo(Resource resource, Injector injector) {
        try {
            // Create JavaIoFileSystemAccess with proper initialization
            JavaIoFileSystemAccess fsa = new JavaIoFileSystemAccess();
            
            // Set output path
            fsa.setOutputPath("generated/");
            
            // Initialize registry using reflection if needed
            try {
                IResourceServiceProvider.Registry registry = 
                    injector.getInstance(IResourceServiceProvider.Registry.class);
                
                // Use reflection to set the registry field
                Field registryField = JavaIoFileSystemAccess.class.getDeclaredField("registry");
                registryField.setAccessible(true);
                registryField.set(fsa, registry);
            } catch (Exception e) {
                System.out.println("Warning: Could not set registry - " + e.getMessage());
            }
            
            // Set output configurations
            OutputConfiguration defaultOutput = new OutputConfiguration("DEFAULT_OUTPUT");
            defaultOutput.setDescription("Default output");
            defaultOutput.setOutputDirectory("./generated");
            defaultOutput.setOverrideExistingResources(true);
            defaultOutput.setCreateOutputDirectory(true);
            
            Map<String, OutputConfiguration> outputConfigs = new HashMap<>();
            outputConfigs.put("DEFAULT_OUTPUT", defaultOutput);
            fsa.setOutputConfigurations(outputConfigs);
            
            // Get generator directly from injector
            Object generator = null;
            
            // Try to get HybridGeneratorExample first
            try {
                Class<?> hybridClass = Class.forName("org.xtext.example.mydsl.generator.HybridGeneratorExample");
                generator = injector.getInstance(hybridClass);
            } catch (Exception e) {
                // Fall back to MyDslGenerator
                try {
                    Class<?> generatorClass = Class.forName("org.xtext.example.mydsl.generator.MyDslGenerator");
                    generator = injector.getInstance(generatorClass);
                } catch (Exception e2) {
                    System.err.println("Could not find generator class");
                    return false;
                }
            }
            
            // Call doGenerate using reflection
            IGeneratorContext context = new GeneratorContext();
            generator.getClass().getMethod("doGenerate", Resource.class, IFileSystemAccess2.class, IGeneratorContext.class)
                .invoke(generator, resource, fsa, context);
            
            System.out.println("Generation with JavaIoFileSystemAccess successful!");
            return true;
            
        } catch (Exception e) {
            System.err.println("JavaIo generation failed: " + e.getMessage());
            return false;
        }
    }
    
    private static void generateWithInMemory(Resource resource, Injector injector) throws Exception {
        // Create InMemoryFileSystemAccess
        InMemoryFileSystemAccess fsa = new InMemoryFileSystemAccess();
        IGeneratorContext context = new GeneratorContext();
        
        // Get generator - try different approaches
        Object generator = null;
        
        try {
            // Try HybridGeneratorExample
            Class<?> hybridClass = Class.forName("org.xtext.example.mydsl.generator.HybridGeneratorExample");
            generator = injector.getInstance(hybridClass);
            System.out.println("Using HybridGeneratorExample");
        } catch (Exception e) {
            // Try MyDslGenerator
            try {
                Class<?> generatorClass = Class.forName("org.xtext.example.mydsl.generator.MyDslGenerator");
                generator = injector.getInstance(generatorClass);
                System.out.println("Using MyDslGenerator");
            } catch (Exception e2) {
                throw new RuntimeException("No generator found", e2);
            }
        }
        
        // Generate
        System.out.println("Generating code...");
        try {
            generator.getClass().getMethod("doGenerate", Resource.class, IFileSystemAccess2.class, IGeneratorContext.class)
                .invoke(generator, resource, fsa, context);
        } catch (Exception e) {
            // Try with IFileSystemAccess (older interface)
            try {
                generator.getClass().getMethod("doGenerate", Resource.class, 
                    Class.forName("org.eclipse.xtext.generator.IFileSystemAccess"), IGeneratorContext.class)
                    .invoke(generator, resource, fsa, context);
            } catch (Exception e2) {
                throw new RuntimeException("Could not invoke generator", e2);
            }
        }
        
        // Write files to disk
        writeFiles(fsa);
    }
    
    private static void writeFiles(InMemoryFileSystemAccess fsa) throws IOException {
        File outputDir = new File("generated");
        if (!outputDir.exists()) {
            outputDir.mkdirs();
        }
        
        // Get all files - handle different return types
        Map<String, Object> allFiles = fsa.getAllFiles();
        
        if (allFiles.isEmpty()) {
            // Try getTextFiles() as fallback
            Map<String, CharSequence> textFiles = fsa.getTextFiles();
            if (!textFiles.isEmpty()) {
                allFiles = new HashMap<>();
                for (Map.Entry<String, CharSequence> entry : textFiles.entrySet()) {
                    allFiles.put(entry.getKey(), entry.getValue());
                }
            }
        }
        
        if (allFiles.isEmpty()) {
            System.out.println("No files generated");
            return;
        }
        
        System.out.println("\nWriting " + allFiles.size() + " file(s):");
        
        for (Map.Entry<String, Object> entry : allFiles.entrySet()) {
            String path = entry.getKey();
            Object contentObj = entry.getValue();
            
            // Convert content to string
            String content;
            if (contentObj instanceof CharSequence) {
                content = contentObj.toString();
            } else if (contentObj instanceof byte[]) {
                content = new String((byte[]) contentObj);
            } else {
                content = String.valueOf(contentObj);
            }
            
            // Clean path - remove DEFAULT_OUTPUT prefix if present
            if (path.startsWith("DEFAULT_OUTPUT")) {
                path = path.substring("DEFAULT_OUTPUT".length());
            }
            
            // Create file
            File outFile = new File(outputDir, path);
            
            // Create parent directories if needed
            File parentDir = outFile.getParentFile();
            if (!parentDir.exists()) {
                parentDir.mkdirs();
            }
            
            // Write file
            try (FileWriter writer = new FileWriter(outFile)) {
                writer.write(content);
                System.out.println("  ✓ " + path);
            } catch (IOException e) {
                System.err.println("  ✗ " + path + " - Error: " + e.getMessage());
            }
        }
        
        System.out.println("\nFiles written to: " + outputDir.getAbsolutePath());
        
        // Show directory structure
        System.out.println("\nGenerated structure:");
        showDirectoryTree(outputDir, "");
    }
    
    private static void showDirectoryTree(File dir, String indent) {
        File[] files = dir.listFiles();
        if (files == null) return;
        
        // Sort files: directories first, then files alphabetically
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

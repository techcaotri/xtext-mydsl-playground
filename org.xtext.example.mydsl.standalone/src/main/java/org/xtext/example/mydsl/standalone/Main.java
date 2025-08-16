package org.xtext.example.mydsl.standalone;

import com.google.inject.Injector;
import org.apache.commons.cli.*;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.eclipse.emf.common.util.URI;
import org.eclipse.emf.ecore.resource.Resource;
import org.eclipse.xtext.diagnostics.Severity;
import org.eclipse.xtext.generator.GeneratorContext;
import org.eclipse.xtext.generator.JavaIoFileSystemAccess;
import org.eclipse.xtext.generator.OutputConfiguration;
import org.eclipse.xtext.parser.IEncodingProvider;
import org.eclipse.xtext.resource.IResourceServiceProvider;
import org.eclipse.xtext.resource.XtextResource;
import org.eclipse.xtext.resource.XtextResourceSet;
import org.eclipse.xtext.util.CancelIndicator;
import org.eclipse.xtext.validation.CheckMode;
import org.eclipse.xtext.validation.IResourceValidator;
import org.eclipse.xtext.validation.Issue;
import org.xtext.example.mydsl.MyDslStandaloneSetup;
import org.xtext.example.mydsl.generator.MyDslGenerator;
import org.xtext.example.mydsl.myDsl.Model;

import java.io.File;
import java.io.IOException;
import java.lang.reflect.Field;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Main entry point for the standalone MyDsl generator
 * Uses the unified generator from the main project
 * 
 * @author MyDsl Standalone Generator
 */
public class Main {
    private static final Logger logger = LogManager.getLogger(Main.class);
    private static final String VERSION = "2.0.0-SNAPSHOT";
    
    private Injector injector;
    private XtextResourceSet resourceSet;
    private IResourceValidator validator;
    private MyDslGenerator generator;
    private IResourceServiceProvider.Registry serviceProviderRegistry;
    private IEncodingProvider encodingProvider;
    
    public static void main(String[] args) {
        Main main = new Main();
        System.exit(main.run(args));
    }
    
    public int run(String[] args) {
        Options options = createOptions();
        CommandLineParser parser = new DefaultParser();
        
        try {
            CommandLine cmd = parser.parse(options, args);
            
            // Handle help
            if (cmd.hasOption("h")) {
                printHelp(options);
                return 0;
            }
            
            // Handle version
            if (cmd.hasOption("v")) {
                System.out.println("MyDsl Standalone Generator v" + VERSION);
                return 0;
            }
            
            // Get input file
            List<String> argList = cmd.getArgList();
            if (argList.isEmpty()) {
                System.err.println("Error: No input file specified");
                printHelp(options);
                return 1;
            }
            
            String inputFile = argList.get(0);
            File file = new File(inputFile);
            if (!file.exists()) {
                System.err.println("Error: Input file not found: " + file.getAbsolutePath());
                return 1;
            }
            
            if (!file.getName().endsWith(".mydsl")) {
                System.err.println("Error: Input file must have .mydsl extension");
                return 1;
            }
            
            // Get output directory
            String outputDir = cmd.getOptionValue("o", "generated");
            Path outputPath = Paths.get(outputDir);
            
            // Initialize Xtext
            initialize();
            
            // Load and validate the model
            logger.info("Loading model from: {}", file.getAbsolutePath());
            Resource resource = loadModel(file);
            
            if (resource == null) {
                System.err.println("Error: Failed to load model");
                return 1;
            }
            
            // Validate
            if (!cmd.hasOption("s")) {
                List<Issue> issues = validateModel(resource);
                if (hasErrors(issues)) {
                    printValidationIssues(issues);
                    return 1;
                }
                if (!issues.isEmpty()) {
                    printValidationIssues(issues);
                }
            }
            
            // Get the model
            if (resource.getContents().isEmpty()) {
                System.err.println("Error: Model is empty");
                return 1;
            }
            
            Model model = (Model) resource.getContents().get(0);
            logger.info("Model name: {}", model.getName());
            
            // Configure generation options
            boolean generateCpp = !cmd.hasOption("n");
            boolean generateProtobuf = cmd.hasOption("m");
            boolean generateBinaryDesc = cmd.hasOption("b");
            
            // Configure the generator
            generator.setGenerationOptions(generateCpp, generateProtobuf, generateBinaryDesc);
            
            // Generate code
            logger.info("Generating to: {}", outputPath.toAbsolutePath());
            generateCode(resource, outputPath, cmd.hasOption("f"));
            
            // Print success messages
            if (generateCpp) {
                System.out.println("✔ C++ code generated successfully");
            }
            if (generateProtobuf) {
                System.out.println("✔ Protobuf files generated successfully");
                if (generateBinaryDesc) {
                    System.out.println("  Note: Run the generated scripts in proto/ to create .desc files");
                }
            }
            
            // Print summary
            if (cmd.hasOption("d")) {
                printSummary(model, outputPath);
            }
            
            return 0;
            
        } catch (ParseException e) {
            System.err.println("Error parsing command line: " + e.getMessage());
            printHelp(options);
            return 1;
        } catch (Exception e) {
            System.err.println("Error: " + e.getMessage());
            if (logger.isDebugEnabled()) {
                e.printStackTrace();
            }
            return 1;
        }
    }
    
    private Options createOptions() {
        Options options = new Options();
        
        options.addOption("h", "help", false, "Show help message");
        options.addOption("v", "version", false, "Show version information");
        options.addOption("o", "output", true, "Output directory (default: generated)");
        options.addOption("m", "protobuf", false, "Generate Protobuf .proto files");
        options.addOption("b", "binary", false, "Generate scripts for binary .desc descriptor set files");
        options.addOption("f", "force", false, "Force overwrite existing files");
        options.addOption("s", "skip-validation", false, "Skip model validation");
        options.addOption("n", "no-cpp", false, "Skip C++ generation (useful with -m for proto-only)");
        options.addOption("d", "debug", false, "Enable debug output and summary");
        
        return options;
    }
    
    private void printHelp(Options options) {
        HelpFormatter formatter = new HelpFormatter();
        formatter.printHelp(
            "java -jar org.xtext.example.mydsl.standalone-" + VERSION + "-jar-with-dependencies.jar [options] <input.mydsl>",
            "\nMyDsl Standalone Generator - Generate C++ code and Protobuf from MyDsl files\n\n",
            options,
            "\nExamples:\n" +
            "  Generate C++ code only:\n" +
            "    java -jar mydsl-standalone.jar model.mydsl\n\n" +
            "  Generate C++ and Protobuf:\n" +
            "    java -jar mydsl-standalone.jar -m model.mydsl\n\n" +
            "  Generate only Protobuf with descriptor scripts:\n" +
            "    java -jar mydsl-standalone.jar -n -m -b model.mydsl\n\n" +
            "  Specify output directory:\n" +
            "    java -jar mydsl-standalone.jar -o output -m model.mydsl\n"
        );
    }
    
    private void initialize() {
        logger.info("Initializing Xtext...");
        MyDslStandaloneSetup setup = new MyDslStandaloneSetup();
        injector = setup.createInjectorAndDoEMFRegistration();
        resourceSet = injector.getInstance(XtextResourceSet.class);
        validator = injector.getInstance(IResourceValidator.class);
        generator = injector.getInstance(MyDslGenerator.class);
        serviceProviderRegistry = injector.getInstance(IResourceServiceProvider.Registry.class);
        
        // Get the encoding provider
        encodingProvider = injector.getInstance(IEncodingProvider.class);
        if (encodingProvider == null) {
            // Create a default encoding provider if none exists
            encodingProvider = new IEncodingProvider() {
                @Override
                public String getEncoding(URI uri) {
                    return StandardCharsets.UTF_8.name();
                }
            };
        }
    }
    
    private Resource loadModel(File file) {
        try {
            URI uri = URI.createFileURI(file.getAbsolutePath());
            Resource resource = resourceSet.getResource(uri, true);
            
            // Check for parse errors
            if (!resource.getErrors().isEmpty()) {
                System.err.println("Parse errors found:");
                for (Resource.Diagnostic error : resource.getErrors()) {
                    System.err.println("  Line " + error.getLine() + ": " + error.getMessage());
                }
                return null;
            }
            
            return resource;
        } catch (Exception e) {
            logger.error("Failed to load model", e);
            return null;
        }
    }
    
    private List<Issue> validateModel(Resource resource) {
        if (resource instanceof XtextResource) {
            try {
                return validator.validate(resource, CheckMode.ALL, CancelIndicator.NullImpl);
            } catch (Exception e) {
                // Log the error but continue - validation errors are not critical
                logger.warn("Validation warning: {}", e.getMessage());
                return List.of();
            }
        }
        return List.of();
    }
    
    private boolean hasErrors(List<Issue> issues) {
        return issues.stream().anyMatch(issue -> issue.getSeverity() == Severity.ERROR);
    }
    
    private void printValidationIssues(List<Issue> issues) {
        for (Issue issue : issues) {
            String level = issue.getSeverity() == Severity.ERROR ? "ERROR" : 
                          issue.getSeverity() == Severity.WARNING ? "WARNING" : "INFO";
            System.err.printf("[%s] Line %d: %s%n", level, issue.getLineNumber(), issue.getMessage());
        }
    }
    
    private void generateCode(Resource resource, Path outputPath, boolean force) throws IOException {
        // Create output directory
        Files.createDirectories(outputPath);
        
        // Configure file system access
        JavaIoFileSystemAccess fsa = new JavaIoFileSystemAccess();
        fsa.setOutputPath(outputPath.toString());
        
        // Fix the registry and encoding provider using reflection
        try {
            // Set the registry
            Field registryField = JavaIoFileSystemAccess.class.getDeclaredField("registry");
            registryField.setAccessible(true);
            registryField.set(fsa, serviceProviderRegistry);
            
            // Set the encoding provider
            Field encodingField = JavaIoFileSystemAccess.class.getDeclaredField("encodingProvider");
            encodingField.setAccessible(true);
            encodingField.set(fsa, encodingProvider);
            
            logger.debug("Fixed JavaIoFileSystemAccess initialization");
        } catch (Exception e) {
            logger.warn("Could not fully initialize JavaIoFileSystemAccess: {}", e.getMessage());
            // Continue anyway - it might still work
        }
        
        OutputConfiguration defaultOutput = new OutputConfiguration("DEFAULT_OUTPUT");
        defaultOutput.setDescription("Output");
        defaultOutput.setOutputDirectory(outputPath.toString());
        defaultOutput.setOverrideExistingResources(force);
        defaultOutput.setCreateOutputDirectory(true);
        
        Map<String, OutputConfiguration> outputConfigs = new HashMap<>();
        outputConfigs.put("DEFAULT_OUTPUT", defaultOutput);
        fsa.setOutputConfigurations(outputConfigs);
        
        // Generate
        GeneratorContext context = new GeneratorContext();
        generator.doGenerate(resource, fsa, context);
    }
    
    private void printSummary(Model model, Path outputPath) {
        System.out.println("\n========== Generation Summary ==========");
        System.out.println("Model: " + model.getName());
        System.out.println("Entities: " + model.getEntities().size());
        System.out.println("Enums: " + model.getEnums().size());
        System.out.println("Output: " + outputPath.toAbsolutePath());
        
        // List generated files
        System.out.println("\nGenerated files:");
        try {
            if (Files.exists(outputPath)) {
                Files.walk(outputPath)
                    .filter(Files::isRegularFile)
                    .forEach(file -> {
                        Path relative = outputPath.relativize(file);
                        System.out.println("  - " + relative);
                    });
            }
        } catch (IOException e) {
            logger.error("Error listing files", e);
        }
        
        System.out.println("========================================");
    }
}

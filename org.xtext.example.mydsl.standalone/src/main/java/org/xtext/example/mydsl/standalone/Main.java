package org.xtext.example.mydsl.standalone;

import com.google.inject.Injector;
import org.apache.commons.cli.*;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.eclipse.emf.common.util.URI;
import org.eclipse.emf.ecore.resource.Resource;
import org.eclipse.emf.ecore.resource.ResourceSet;
import org.eclipse.xtext.diagnostics.Severity;
import org.eclipse.xtext.generator.GeneratorContext;
import org.eclipse.xtext.generator.IGenerator2;
import org.eclipse.xtext.generator.IFileSystemAccess;
import org.eclipse.xtext.generator.InMemoryFileSystemAccess;
import org.eclipse.xtext.generator.JavaIoFileSystemAccess;
import org.eclipse.xtext.generator.OutputConfiguration;
import org.eclipse.xtext.resource.XtextResource;
import org.eclipse.xtext.resource.XtextResourceSet;
import org.eclipse.xtext.util.CancelIndicator;
import org.eclipse.xtext.validation.CheckMode;
import org.eclipse.xtext.validation.IResourceValidator;
import org.eclipse.xtext.validation.Issue;
import org.xtext.example.mydsl.MyDslStandaloneSetup;
import org.xtext.example.mydsl.generator.MyDslGenerator;
import org.xtext.example.mydsl.myDsl.Model;
import org.xtext.example.mydsl.standalone.generator.ProtobufGenerator;
import org.xtext.example.mydsl.standalone.generator.StandaloneFileSystemAccess;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Main entry point for the standalone MyDsl generator
 * 
 * @author MyDsl Standalone Generator
 */
public class Main {
    private static final Logger logger = LogManager.getLogger(Main.class);
    private static final String VERSION = "1.0.0-SNAPSHOT";
    
    private Injector injector;
    private XtextResourceSet resourceSet;
    private IResourceValidator validator;
    private MyDslGenerator generator;
    private ProtobufGenerator protobufGenerator;
    
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
            
            // Get protobuf output directory
            String protoOutputDir = cmd.getOptionValue("p", outputDir + "/proto");
            
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
            
            // Generate C++ code
            if (!cmd.hasOption("n")) {
                logger.info("Generating C++ code to: {}", outputPath.toAbsolutePath());
                generateCppCode(resource, outputPath, cmd.hasOption("f"));
                System.out.println("✓ C++ code generated successfully");
            }
            
            // Generate Protobuf if requested
            if (cmd.hasOption("m")) {
                logger.info("Generating Protobuf files to: {}", protoOutputDir);
                generateProtobuf(model, Paths.get(protoOutputDir), cmd.hasOption("b"));
                System.out.println("✓ Protobuf files generated successfully");
            }
            
            // Print summary
            if (cmd.hasOption("d")) {
                printSummary(model, outputPath, cmd.hasOption("m") ? Paths.get(protoOutputDir) : null);
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
        options.addOption("o", "output", true, "Output directory for generated C++ code (default: generated)");
        options.addOption("m", "protobuf", false, "Generate Protobuf .proto and .desc files");
        options.addOption("p", "proto-output", true, "Output directory for Protobuf files (default: generated/proto)");
        options.addOption("b", "binary", false, "Generate binary .desc descriptor set file");
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
            "  Generate C++ code:\n" +
            "    java -jar mydsl-standalone.jar model.mydsl\n\n" +
            "  Generate C++ and Protobuf:\n" +
            "    java -jar mydsl-standalone.jar -m model.mydsl\n\n" +
            "  Generate only Protobuf with binary descriptor:\n" +
            "    java -jar mydsl-standalone.jar -n -m -b model.mydsl\n\n" +
            "  Specify output directories:\n" +
            "    java -jar mydsl-standalone.jar -o src/generated -p proto/generated -m model.mydsl\n"
        );
    }
    
    private void initialize() {
        logger.info("Initializing Xtext...");
        MyDslStandaloneSetup setup = new MyDslStandaloneSetup();
        injector = setup.createInjectorAndDoEMFRegistration();
        resourceSet = injector.getInstance(XtextResourceSet.class);
        validator = injector.getInstance(IResourceValidator.class);
        generator = injector.getInstance(MyDslGenerator.class);
        protobufGenerator = new ProtobufGenerator();
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
            return validator.validate(resource, CheckMode.ALL, CancelIndicator.NullImpl);
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
    
    private void generateCppCode(Resource resource, Path outputPath, boolean force) throws IOException {
        // Create output directory
        Files.createDirectories(outputPath);
        
        // Configure file system access
        StandaloneFileSystemAccess fsa = new StandaloneFileSystemAccess();
        fsa.setOutputPath(outputPath.toString());
        
        OutputConfiguration defaultOutput = new OutputConfiguration(IFileSystemAccess.DEFAULT_OUTPUT);
        defaultOutput.setDescription("C++ output");
        defaultOutput.setOutputDirectory(outputPath.toString());
        defaultOutput.setOverrideExistingResources(force);
        defaultOutput.setCreateOutputDirectory(true);
        
        Map<String, OutputConfiguration> outputConfigs = new HashMap<>();
        outputConfigs.put(IFileSystemAccess.DEFAULT_OUTPUT, defaultOutput);
        fsa.setOutputConfigurations(outputConfigs);
        
        // Generate
        GeneratorContext context = new GeneratorContext();
        generator.doGenerate(resource, fsa, context);
        
        // Write files
        fsa.writeAllFiles();
    }
    
    private void generateProtobuf(Model model, Path outputPath, boolean generateBinary) throws IOException {
        Files.createDirectories(outputPath);
        protobufGenerator.generate(model, outputPath, generateBinary);
    }
    
    private void printSummary(Model model, Path cppOutput, Path protoOutput) {
        System.out.println("\n========== Generation Summary ==========");
        System.out.println("Model: " + model.getName());
        System.out.println("Entities: " + model.getEntities().size());
        System.out.println("Enums: " + model.getEnums().size());
        System.out.println("C++ Output: " + cppOutput.toAbsolutePath());
        
        if (protoOutput != null) {
            System.out.println("Protobuf Output: " + protoOutput.toAbsolutePath());
        }
        
        // List generated files
        System.out.println("\nGenerated files:");
        try {
            Files.walk(cppOutput)
                .filter(Files::isRegularFile)
                .forEach(file -> System.out.println("  - " + cppOutput.relativize(file)));
                
            if (protoOutput != null && Files.exists(protoOutput)) {
                Files.walk(protoOutput)
                    .filter(Files::isRegularFile)
                    .forEach(file -> System.out.println("  - " + protoOutput.relativize(file)));
            }
        } catch (IOException e) {
            logger.error("Error listing files", e);
        }
        
        System.out.println("========================================");
    }
}

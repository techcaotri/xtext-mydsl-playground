package org.xtext.example.mydsl.standalone.generator;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.eclipse.emf.common.util.URI;
import org.eclipse.xtext.generator.AbstractFileSystemAccess2;
import org.eclipse.xtext.generator.IFileSystemAccess;
import org.eclipse.xtext.generator.OutputConfiguration;

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.HashMap;
import java.util.Map;

/**
 * Standalone file system access implementation that doesn't require registry
 * 
 * @author MyDsl Standalone Generator
 */
public class StandaloneFileSystemAccess extends AbstractFileSystemAccess2 {
    private static final Logger logger = LogManager.getLogger(StandaloneFileSystemAccess.class);
    
    private String outputPath = "generated";
    private Map<String, CharSequence> generatedFiles = new HashMap<>();
    private Map<String, OutputConfiguration> outputConfigurations = new HashMap<>();
    private Object context;
    
    public StandaloneFileSystemAccess() {
        // Set default output configuration
        OutputConfiguration defaultConfig = new OutputConfiguration(IFileSystemAccess.DEFAULT_OUTPUT);
        defaultConfig.setDescription("Default output");
        defaultConfig.setOutputDirectory(outputPath);
        defaultConfig.setOverrideExistingResources(true);
        defaultConfig.setCreateOutputDirectory(true);
        outputConfigurations.put(IFileSystemAccess.DEFAULT_OUTPUT, defaultConfig);
    }
    
    @Override
    public void generateFile(String fileName, CharSequence contents) {
        generateFile(fileName, IFileSystemAccess.DEFAULT_OUTPUT, contents);
    }
    
    @Override
    public void generateFile(String fileName, String outputConfigurationName, CharSequence contents) {
        logger.debug("Generating file: {} in configuration: {}", fileName, outputConfigurationName);
        
        // Store in memory first
        String key = outputConfigurationName + "/" + fileName;
        generatedFiles.put(key, contents);
    }
    
    @Override
    public void generateFile(String fileName, InputStream content) throws RuntimeException {
        generateFile(fileName, IFileSystemAccess.DEFAULT_OUTPUT, content);
    }
    
    @Override
    public void generateFile(String fileName, String outputConfigurationName, InputStream content) throws RuntimeException {
        try {
            // Read the input stream into a string
            ByteArrayOutputStream result = new ByteArrayOutputStream();
            byte[] buffer = new byte[1024];
            int length;
            while ((length = content.read(buffer)) != -1) {
                result.write(buffer, 0, length);
            }
            String contents = result.toString(StandardCharsets.UTF_8.name());
            generateFile(fileName, outputConfigurationName, contents);
        } catch (IOException e) {
            throw new RuntimeException("Failed to generate file from InputStream: " + fileName, e);
        }
    }
    
    @Override
    public void deleteFile(String fileName) {
        deleteFile(fileName, IFileSystemAccess.DEFAULT_OUTPUT);
    }
    
    @Override
    public void deleteFile(String fileName, String outputConfigurationName) {
        String key = outputConfigurationName + "/" + fileName;
        generatedFiles.remove(key);
        
        // Also delete physical file if exists
        OutputConfiguration config = outputConfigurations.get(outputConfigurationName);
        if (config != null) {
            Path filePath = Paths.get(config.getOutputDirectory(), fileName);
            try {
                Files.deleteIfExists(filePath);
                logger.debug("Deleted file: {}", filePath);
            } catch (IOException e) {
                logger.error("Failed to delete file: {}", filePath, e);
            }
        }
    }
    
    /**
     * Write all generated files to disk
     */
    public void writeAllFiles() throws IOException {
        for (Map.Entry<String, CharSequence> entry : generatedFiles.entrySet()) {
            String key = entry.getKey();
            CharSequence content = entry.getValue();
            
            // Parse configuration name and file name
            int slashIndex = key.indexOf('/');
            String configName = key.substring(0, slashIndex);
            String fileName = key.substring(slashIndex + 1);
            
            OutputConfiguration config = outputConfigurations.get(configName);
            if (config == null) {
                config = outputConfigurations.get(IFileSystemAccess.DEFAULT_OUTPUT);
            }
            
            writeFile(config, fileName, content);
        }
    }
    
    private void writeFile(OutputConfiguration config, String fileName, CharSequence content) throws IOException {
        Path outputDir = Paths.get(config.getOutputDirectory());
        Path filePath = outputDir.resolve(fileName);
        
        // Create directories if needed
        Files.createDirectories(filePath.getParent());
        
        // Check if should override
        if (Files.exists(filePath) && !config.isOverrideExistingResources()) {
            logger.warn("File already exists and override is disabled: {}", filePath);
            return;
        }
        
        // Write file
        Files.writeString(filePath, content.toString(), StandardCharsets.UTF_8);
        logger.info("Written file: {}", filePath);
    }
    
    public void setOutputPath(String outputPath) {
        this.outputPath = outputPath;
        
        // Update default configuration
        OutputConfiguration defaultConfig = outputConfigurations.get(IFileSystemAccess.DEFAULT_OUTPUT);
        if (defaultConfig != null) {
            defaultConfig.setOutputDirectory(outputPath);
        }
    }
    
    public void setOutputConfigurations(Map<String, OutputConfiguration> configurations) {
        this.outputConfigurations = configurations;
    }
    
    public Map<String, CharSequence> getGeneratedFiles() {
        return new HashMap<>(generatedFiles);
    }
    
    public void clearGeneratedFiles() {
        generatedFiles.clear();
    }
    
    /**
     * Get the number of files generated
     */
    public int getFileCount() {
        return generatedFiles.size();
    }
    
    /**
     * Check if any files were generated
     */
    public boolean hasGeneratedFiles() {
        return !generatedFiles.isEmpty();
    }
    
    @Override
    public URI getURI(String fileName, String outputConfigurationName) {
        OutputConfiguration config = outputConfigurations.get(outputConfigurationName);
        if (config == null) {
            config = outputConfigurations.get(IFileSystemAccess.DEFAULT_OUTPUT);
        }
        
        if (config != null) {
            Path outputDir = Paths.get(config.getOutputDirectory());
            Path filePath = outputDir.resolve(fileName);
            return URI.createFileURI(filePath.toAbsolutePath().toString());
        }
        
        return URI.createFileURI(fileName);
    }
    
    @Override
    public URI getURI(String fileName) {
        return getURI(fileName, IFileSystemAccess.DEFAULT_OUTPUT);
    }
    
    @Override
    public InputStream readBinaryFile(String fileName) throws RuntimeException {
        return readBinaryFile(fileName, IFileSystemAccess.DEFAULT_OUTPUT);
    }
    
    @Override
    public InputStream readBinaryFile(String fileName, String outputConfigurationName) throws RuntimeException {
        try {
            Path filePath = getPath(fileName, outputConfigurationName);
            return Files.newInputStream(filePath);
        } catch (IOException e) {
            throw new RuntimeException("Failed to read binary file: " + fileName, e);
        }
    }
    
    @Override
    public CharSequence readTextFile(String fileName) throws RuntimeException {
        return readTextFile(fileName, IFileSystemAccess.DEFAULT_OUTPUT);
    }
    
    @Override
    public CharSequence readTextFile(String fileName, String outputConfigurationName) throws RuntimeException {
        try {
            Path filePath = getPath(fileName, outputConfigurationName);
            return Files.readString(filePath, StandardCharsets.UTF_8);
        } catch (IOException e) {
            throw new RuntimeException("Failed to read text file: " + fileName, e);
        }
    }
    
    @Override
    public boolean isFile(String fileName) throws RuntimeException {
        return isFile(fileName, IFileSystemAccess.DEFAULT_OUTPUT);
    }
    
    @Override
    public boolean isFile(String fileName, String outputConfigurationName) throws RuntimeException {
        Path filePath = getPath(fileName, outputConfigurationName);
        return Files.isRegularFile(filePath);
    }
    
    private Path getPath(String fileName, String outputConfigurationName) {
        OutputConfiguration config = outputConfigurations.get(outputConfigurationName);
        if (config == null) {
            config = outputConfigurations.get(IFileSystemAccess.DEFAULT_OUTPUT);
        }
        
        if (config != null) {
            Path outputDir = Paths.get(config.getOutputDirectory());
            return outputDir.resolve(fileName);
        }
        
        return Paths.get(fileName);
    }
    
    @Override
    public void setContext(Object context) {
        this.context = context;
    }
    
    public Object getContext() {
        return this.context;
    }
    
    protected String getEncoding(URI fileURI) {
        return StandardCharsets.UTF_8.name();
    }
    
    /**
     * Get output configurations
     */
    public Map<String, OutputConfiguration> getOutputConfigurations() {
        return outputConfigurations;
    }
}

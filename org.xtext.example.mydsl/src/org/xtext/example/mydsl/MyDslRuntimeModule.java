package org.xtext.example.mydsl;

import org.eclipse.xtext.generator.IGenerator2;
import org.xtext.example.mydsl.generator.MyDslGenerator;

/**
 * Use this class to register components to be used at runtime
 */
public class MyDslRuntimeModule extends AbstractMyDslRuntimeModule {
    
    @Override
    public Class<? extends IGenerator2> bindIGenerator2() {
        return MyDslGenerator.class;
    }
}

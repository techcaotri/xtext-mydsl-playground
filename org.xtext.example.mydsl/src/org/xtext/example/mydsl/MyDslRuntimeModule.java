package org.xtext.example.mydsl;

import org.eclipse.xtext.generator.IGenerator2;
import org.xtext.example.mydsl.generator.MyDslGenerator;
import org.xtext.example.mydsl.generator.ProtobufGenerator;
import com.google.inject.Binder;

/**
 * Use this class to register components to be used at runtime
 */
public class MyDslRuntimeModule extends AbstractMyDslRuntimeModule {
    
    @Override
    public Class<? extends IGenerator2> bindIGenerator2() {
        return MyDslGenerator.class;
    }
    
    @Override
    public void configure(Binder binder) {
        super.configure(binder);
        // Bind the ProtobufGenerator as a singleton
        binder.bind(org.xtext.example.mydsl.generator.ProtobufGenerator.class)
              .asEagerSingleton();
    }
}
